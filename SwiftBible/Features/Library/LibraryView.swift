//
//  LibraryView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import SwiftUI
import OSLog

struct LibraryView: View {

    // MARK: Properties (Proj Env, Private)

    /// Read appEnvironment.readerStore environment value from current view environment
    ///
    /// Don't need "\." here because this is a type-based lookup for an observable instance
    /// placed into the environment: .environment(readerStore))
    @Environment(LibraryStore.self) private var libraryStore: LibraryStore

    @Environment(BibleCatalogStore.self) private var catalogStore: BibleCatalogStore

    @Environment(\.editMode) private var editMode

    // MARK: Properties (State, Private)

    @State private var isInEditMode: Bool = false

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
                        .safeAreaInset(edge: .top, spacing: 5) {
                            filterBarChipsView
                        }
                }
            }
            // Navigation view modifiers
            .navigationTitle("Saved")
            .navigationSubtitle("\(libraryStore.annotations.count) Annotation\(libraryStore.annotations.count == 1 ? "" : "s")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                filterOptionsToolbarItem
            }
        }
        .task {
            // First load all annotations
            libraryStore.load()

            // Required for all annotations to load their associated passages
            // Prereq for rendering each card's verse
//            await libraryStore.loadAllPassages()

            // Load book names for each annotation
            await loadMissingBookMetadata()
        }
    }

    /// List of annotations
    var libraryListView: some View {
        List {
            ForEach(libraryStore.filteredAnnotations) { annotation in
                // Calculate required params
                // Translation
                let translation = catalogStore.translation(for: annotation.translationID)

                // Book
                let book = catalogStore.book(for: annotation.translationID,
                                             bookCode: annotation.bookCode)

                // Verse range
                let upperBoundSameAsLowerBound = annotation.verseRange.upperBound == annotation.verseRange.lowerBound
                let endVerseCalculated = upperBoundSameAsLowerBound ? nil : annotation.verseRange.upperBound

                let verseRange = RenderedVerseRange(startVerse: annotation.verseRange.lowerBound,
                                                    endVerse: endVerseCalculated)

                // Passage label
                let passageLabel = "\(book?.displayName ?? annotation.bookCode) \(annotation.chapter):\(verseRange.displayText)"

                // RenderedPassageRuns
                let passageForAnnotation = libraryStore.passage(for: annotation)

                let renderedPassageRunsForAnnotation = passageForAnnotation?.renderedPassage.runs(for: verseRange)

                // Build actual single annotation view
                LibraryRowView(annotation: annotation,
                               renderedPassageRuns: renderedPassageRunsForAnnotation,
                               passageLabel: passageLabel,
                               translationLabel: translation?.abbreviation
                                   ?? annotation.translationID.description)
                .task {
                    // Required for annotation to load its associated passage
                    // Prereq for rendering this card's verse
                    await libraryStore.loadPassage(for: annotation)
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .swipeActions {
                Button(role: .destructive) {
                    // TODO: define onDelete behavior
                    // TODO: popover delete model confirmation; wire actual delete
                } label: {
                    Image(systemName: "trash.fill")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Views (Toolbar)

    ///
    @ToolbarContentBuilder
    private var filterOptionsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {

            } label: {
                Image(systemName: "magnifyingglass")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Menu {
                    Button {

                    } label: {
                        Label("Test", systemImage: "plus")
                    }
                    Button {

                    } label: {
                        Label("Test", systemImage: "plus")
                    }
                    Button {

                    } label: {
                        Label("Test", systemImage: "plus")
                    }
                } label: {
                    Label("Sort By", systemImage: "arrow.up.arrow.down")
                }

                Menu {
                    Button {

                    } label: {
                        Label("Test", systemImage: "plus")
                    }
                    Button {

                    } label: {
                        Label("Test", systemImage: "plus")
                    }
                    Button {

                    } label: {
                        Label("Test", systemImage: "plus")
                    }
                } label: {
                    Label("Filter By", systemImage: "line.3.horizontal.decrease")
                }

                Divider()

                // can you not change EditButton appearance/label?
                EditButton()
//                Button {
//
//                } label: {
//                    Label("Select", systemImage: "checkmark.circle")
//                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }

    // MARK: Views (Filter Bar)

    /// Filter bar chips view
    private var filterBarChipsView: some View {
        GlassEffectContainer(spacing: 8) {
            HStack {
                chipButtonView(for: .highlight,
                               text: "Highlights",
                               systemImage: "pencil.line")
                chipButtonView(for: .tags,
                               text: "Tags",
                               systemImage: "tag.fill")
                chipButtonView(for: .note,
                               text: "Notes",
                               systemImage: "text.alignleft")
            }
            .shadow(color: Color.gray.opacity(0.1), radius: 5)
        }
    }

    /// Individual builder for a single filter bar button
    private func chipButtonView(for contentType: AnnotationContentType,
                                text: String,
                                systemImage: String) -> some View {
        let isSelected = libraryStore.filter.contentType == contentType

        return Toggle(text,
                      systemImage: systemImage, // isSelected ? "xmark" : systemImage
                      isOn: Binding(
                          get: {
                              libraryStore.filter.contentType == contentType
                          },
                          set: { newValue in
                              libraryStore.filter.contentType = newValue ? contentType : nil
                          }
                      ))
        .toggleStyle(.button)
        .buttonStyle(.glass)
        .glassEffectID(text, in: chipBarNamespace)
        .animation(
            .timingCurve(0.25, 1, 0.67, 0.93, duration: 0.15),
            value: isSelected
        )
        .font(.system(size: 12, weight: .semibold))
    }

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

// MARK: Xcode Canvas Previews

#Preview {
    let repository = FakeBibleRepository()
    let passageStore = BiblePassageStore(repository: repository)
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
