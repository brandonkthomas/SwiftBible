//
//  LibraryView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import SwiftUI
import OSLog

struct LibraryView: View {

    /// Called after the reader has been pointed at an annotation's passage
    var onShowInReader: () -> Void = {}

    // MARK: Properties (Proj Env, Private)

    /// Read appEnvironment.readerStore environment value from current view environment
    @Environment(ReaderStore.self) private var readerStore: ReaderStore

    /// Read appEnvironment.libraryStore environment value from current view environment
    ///
    /// Don't need "\." here because this is a type-based lookup for an observable instance
    /// placed into the environment: .environment(readerStore))
    @Environment(LibraryStore.self) private var libraryStore: LibraryStore

    @Environment(BibleCatalogStore.self) private var catalogStore: BibleCatalogStore

    @Environment(\.editMode) private var editMode

    // MARK: Properties (State, Private)

    @State private var isInEditMode: Bool = false

    @State private var didDeleteFail: Bool = false

    @Namespace private var chipBarNamespace

    // MARK: Properties (Local, Private)

    /// todo: doc
    private var unloadedCatalogStoreTranslationIDs: Set<Translation.ID> {
        Set(libraryStore.annotations
            .filter { catalogStore.books(for: $0.translationID) == nil } // not in memory
            .map { $0.translationID } // only need the ID
        )
    }

    /// OS Logging
    private static let logger = Logger(subsystem: "SwiftBible", category: "LibraryView")

    // MARK: Views

    /// Primary body
    var body: some View {
        NavigationStack {
            Group {
                if libraryStore.annotations.count == 0 {
                    ContentUnavailableView(
                        "No Annotations",
                        systemImage: "bookmark",
                        description: Text("Tap verses to annotate them.")
                    )
                } else {
                    // List of items
                    libraryListView
                        // Filter bar
//                        .safeAreaInset(edge: .top, spacing: 5) {
//                            filterBarChipsView
//                        }
                }
            }
            // Navigation view modifiers
//            .navigationTitle("Saved")
//            .navigationSubtitle("\(libraryStore.annotations.count) Annotation\(libraryStore.annotations.count == 1 ? "" : "s")")
//            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                filterOptionsToolbarItem
            }
        }
        // Deletion failure popup
        .alert("Unable to Delete Annotation",
               isPresented: $didDeleteFail) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
        .task {
            // First load all annotations
            // Passages are loaded as-needed by LibraryRowView instances below
            libraryStore.load()

            // Load book names for each annotation
            await loadMissingBookMetadata()
        }
    }

    /// List of annotations
    ///
    /// ScrollView + LazyVStack rather than List: List's underlying collection view resizes
    /// rows around their center, so expanding/collapsing a card jumped. A VStack lays out
    /// top-down, keeping each card's top edge fixed while the cards below move with it.
    /// Rows are still created lazily as they scroll into view.
    var libraryListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // VerseAnnotation is stable Identifiable; required so ForEach doesnt continually
                // delete and re-insert the same rows if IDs were to change mid-life
                ForEach(libraryStore.filteredAnnotations) { annotation in
                    // Retrieve data
                    let libraryRowViewData = LibraryRowViewData(annotation: annotation,
                                                                catalogStore: catalogStore,
                                                                libraryStore: libraryStore)

                    // Build actual single annotation view
                    LibraryRowView(
                        data: libraryRowViewData,
                        onDeleteRequested: {
                            let didDelete = withAnimation {
                                libraryStore.delete(annotation.id)
                            }
                            if didDelete {
                                readerStore.refreshPassageHighlights()
                            } else {
                                didDeleteFail = true
                            }
                        },
                        onPassageViewRequested: {
                            await readerStore.selectTranslationBookAndChapter(
                                translationID: annotation.translationID,
                                bookID: annotation.bookCode,
                                chapterID: "\(annotation.bookCode).\(annotation.chapter)"
                            )
                            onShowInReader()
                        }
                    )
                    .task {
                        // Required for annotation to load its associated passage
                        // Prereq for rendering this card's verse
                        await libraryStore.loadPassage(for: annotation)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        // Delete confirmation lives in each LibraryRowView (menu + swipe share it) so the
        // popover anchors to the card being deleted rather than the whole ScrollView
        .swipeActionsContainerIfAvailable()
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Views (Toolbar)

    ///
    @ToolbarContentBuilder
    private var filterOptionsToolbarItem: some ToolbarContent {
        // Filter By: Translation, Book, Highlight Color, Tag
        ToolbarItem(placement: .automatic) {
            Menu {
                Text("Filter By")
                // Translations
                // TODO: toggle state
                Menu {
                    ForEach(Set(libraryStore.annotations.map(\.translationID)).sorted(), id: \.self) { translationID in
                        Button {
                            libraryStore.filter.translationID = translationID
                        } label: {
                            Text("\(translationID)")
                        }
                    }
                } label: {
                    Label("Translation", systemImage: "text.book.closed")
                }
                // Books
                // TODO: toggle state
                Menu {
                    ForEach(Set(libraryStore.annotations.map(\.bookCode)).sorted(), id: \.self) { bookCode in
                        Button {
                            libraryStore.filter.bookCode = bookCode
                        } label: {
                            Text(bookCode)
                        }
                    }
                } label: {
                    Label("Book", systemImage: "books.vertical")
                }
                // Highlight Colors
                // TODO: toggle state; color icons
                Menu {
                    ForEach(VerseAnnotationHighlightColor.allCases.filter { color in
                        libraryStore.annotations.contains { $0.highlightColor == color }
                    }, id: \.self) { highlightColor in
                        Button {
                            libraryStore.filter.highlightColor = highlightColor
                        } label: {
                            let text = highlightColor.rawValue.prefix(1).capitalized
                                + highlightColor.rawValue.dropFirst()
                            Label(text, systemImage: "circle.fill")
                                .foregroundStyle(highlightColor.uiColor)
                        }
                    }
                } label: {
                    Label("Highlight Color", systemImage: "pencil.line")
                }
                // Tags
                Button {
                    // TODO
                } label: {
                    Label("Tag", systemImage: "tag")
                }
                // Notes
                Button {
                    // TODO
                } label: {
                    Label("Notes", systemImage: "text.alignleft")
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
            }
        }

        // Ellipsis: Sort By, Group By, Select Annotations
        ToolbarItem(placement: .automatic) {
            Menu {
                // Sort By
                Menu {
                    Button {
                        // TODO
                    } label: {
                        Label("Date Added", systemImage: "calendar")
                    }
                    Button {
                        // TODO
                    } label: {
                        Label("Book Order", systemImage: "calendar.day.timeline.leading")
                    }
                } label: {
                    Label("Sort By", systemImage: "arrow.up.arrow.down")
                }

                // Group By
                Menu {
                    Button {

                    } label: {
                        Label("Date Added", systemImage: "calendar")
                    }
                    Button {

                    } label: {
                        Label("Translation", systemImage: "text.book.closed")
                    }
                    Button {

                    } label: {
                        Label("Book", systemImage: "books.vertical")
                    }
                } label: {
                    Label("Group By", systemImage: "rectangle.3.group")
                }

                Divider()

                // can you not change EditButton appearance/label?
                // TODO: EditButton only drives List's built-in edit mode; since the switch to
                // LazyVStack it toggles editMode but nothing responds. Replace with custom selection.
//                EditButton()
                Button {

                } label: {
                    Label("Select Annotations", systemImage: "checkmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }

    // MARK: Views (Filter Bar)

    /// Filter bar chips view
//    private var filterBarChipsView: some View {
//        GlassEffectContainer(spacing: 8) {
//            HStack {
//                chipButtonView(for: .highlight,
//                               text: "Highlights",
//                               systemImage: "pencil.line")
//                chipButtonView(for: .tags,
//                               text: "Tags",
//                               systemImage: "tag.fill")
//                chipButtonView(for: .note,
//                               text: "Notes",
//                               systemImage: "text.alignleft")
//            }
//            .shadow(color: Color.gray.opacity(0.1), radius: 5)
//        }
//    }

    /// Individual builder for a single filter bar button
//    private func chipButtonView(for contentType: AnnotationContentType,
//                                text: String,
//                                systemImage: String) -> some View {
//        let isSelected = libraryStore.filter.contentType == contentType
//
//        return Toggle(text,
//                      systemImage: systemImage, // isSelected ? "xmark" : systemImage
//                      isOn: Binding(
//                          get: {
//                              libraryStore.filter.contentType == contentType
//                          },
//                          set: { newValue in
//                              libraryStore.filter.contentType = newValue ? contentType : nil
//                          }
//                      ))
//        .toggleStyle(.button)
//        .buttonStyle(.glass)
//        .glassEffectID(text, in: chipBarNamespace)
//        .animation(
//            .timingCurve(0.25, 1, 0.67, 0.93, duration: 0.15),
//            value: isSelected
//        )
//        .font(.system(size: 12, weight: .semibold))
//    }

    // MARK: Functions

    private func loadMissingBookMetadata() async {
        let unloadedIDs = unloadedCatalogStoreTranslationIDs
        for translationID in unloadedIDs {
            do {
                try await catalogStore.loadBooks(for: translationID)
            } catch {
                Self.logger.error("loadMissingBookMetadata(): load for ID \(translationID) failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: Swipe Actions Availability

private extension View {

    /// Enables row `.swipeActions` outside a List on iOS 27+; no-op on earlier versions
    ///
    /// The `if` depends only on the OS version, which never changes while the app runs,
    /// so view identity stays stable (unlike a conditional modifier driven by state)
    @ViewBuilder
    func swipeActionsContainerIfAvailable() -> some View {
        if #available(iOS 27, *) {
            swipeActionsContainer()
        } else {
            self
        }
    }
}

// MARK: Xcode Canvas Previews

#Preview {
    let repository = FakeBibleRepository()
    let passageStore = BiblePassageStore(repository: repository,
                                         passageCache: InMemoryPassageCache())
    let libraryStore = LibraryStore(libraryRepository: PreviewFixtures.seededLibraryRepository(),
                                    passageStore: passageStore)
    let catalogStore = BibleCatalogStore(repository: repository)
    LibraryPreviewHost(libraryStore: libraryStore,
                       catalogStore: catalogStore)
}

/// Preview-only host
private struct LibraryPreviewHost: View {
    let libraryStore: LibraryStore
    let catalogStore: BibleCatalogStore

    var body: some View {
        LibraryView()
        .environment(libraryStore)
        .environment(catalogStore)
        .task {
            libraryStore.load()
        }
    }
}
