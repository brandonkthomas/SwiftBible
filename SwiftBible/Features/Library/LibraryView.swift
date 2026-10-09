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
    ///
    /// Don't need "\." here because this is a type-based lookup for an observable instance
    /// placed into the environment: .environment(readerStore))
    @Environment(ReaderStore.self) private var readerStore: ReaderStore

    /// Read appEnvironment.libraryStore environment value from current view environment
    @Environment(LibraryStore.self) private var libraryStore: LibraryStore

    /// Read appEnvironment.catalogStore environment value from current view environment
    @Environment(BibleCatalogStore.self) private var catalogStore: BibleCatalogStore

    // MARK: Properties (Private, State)

    /// Shared selection state
    @State private var librarySelection: LibrarySelection = .init()

    /// Did changing a specific row's highlight color fail?
    @State private var didHighlightColorChangeFail: Bool = false

    /// Did deleting a specific row fail?
    @State private var didDeleteFail: Bool = false

    /// Have we selected the Delete option for all selected rows in Edit mode + need to show confirmation?
    @State private var isEditModeDeleteConfirmationVisible: Bool = false

//    @Namespace private var chipBarNamespace

    /// AnnotationEditor session:
    /// if nil, nothing selected;
    /// if non-nil, we have an existing session and need to open AnnotationEditorSheetView
    @State private var annotationEditor: AnnotationEditor?

    // MARK: Properties (Local, Private)

    /// todo: doc
    private var unloadedCatalogStoreTranslationIDs: Set<Translation.ID> {
        Set(libraryStore.annotations
            .filter { catalogStore.books(for: $0.translationID) == nil } // not in memory
            .map { $0.translationID } // only need the ID
        )
    }

    /// First annotation for each unique book code
    private var uniqueBookCodeAnnotations: [VerseAnnotation] {
        let annotationsGroupedByBookCode = Dictionary(grouping: libraryStore.annotations,
                                                      by: \.bookCode)
        return annotationsGroupedByBookCode
            .compactMap { $0.value.first }
            .sorted(by: { $0.bookCode < $1.bookCode })
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
            .toolbar {
                if librarySelection.isSelecting {
                    selectionOptionsToolbarItem
                } else {
                    filterOptionsToolbarItem
                }
            }
        }
        // Deletion failure popup
        .alert("Unable to Delete Annotation",
               isPresented: $didDeleteFail) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
        // Highlight change failure popup
        .alert("Unable to Change Highlight Color",
               isPresented: $didHighlightColorChangeFail) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please try again.")
        }
        // Load data
        .task {
            // First load all annotations
            // Passages are loaded as-needed by LibraryRowView instances below
            libraryStore.load()

            // Load book names for each annotation
            await loadMissingBookMetadata()
        }
        // Fire AnnotationEditorSheetView when $annotationEditor instance is assigned
        .sheet(
            item: $annotationEditor,
            onDismiss: {
                withAnimation {
                    libraryStore.load()
                }
            },
            content: { editor in
                AnnotationEditorSheetView(editor: editor,
                                          bibleCatalogStore: catalogStore)
                .presentationDragIndicator(.visible)
            }
        )
        // Edit mode: floating Delete button + dialog
        .safeAreaInset(edge: .bottom, alignment: .trailing) {
            if librarySelection.isSelecting {
                // .disabled only blocks taps: the explicit white foreground and the red glass
                // tint are applied regardless, so the disabled look has to be drawn by hand
                let canDelete = (librarySelection.selectedIDCount ?? 0) > 0

                Button {
                    isEditModeDeleteConfirmationVisible = true
                } label: {
                    Label("Delete", systemImage: "trash.fill")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 24))
                        .foregroundStyle(canDelete ? AnyShapeStyle(Color.white) : AnyShapeStyle(.tertiary))
                }
                .padding()  // inside the circle
                // nil tint = plain glass
                .glassEffect(.regular.interactive(canDelete).tint(canDelete ? Color(.systemRed) : nil),
                             in: .circle)
                .padding(.bottom, 5)  // outside: margin from the screen edge
                .padding(.trailing, 20)  // outside: margin from the screen edge
                .disabled(!canDelete)
                // Delete dialog for Edit mode
                .confirmationDialog("Delete \(librarySelection.selectedIDCount ?? 0 == 1 ? "Annotation" : "Annotations")",
                                    isPresented: $isEditModeDeleteConfirmationVisible) {
                    Button("Delete \(librarySelection.selectedIDCount ?? 0 == 1 ? "Annotation" : "Annotations")", role: .destructive) {
                        guard let allIDs = librarySelection.allSelectedIDs else { return }
                        let didDelete = withAnimation(.snappy(duration: 0.35)) {
                            libraryStore.delete(allIDs)
                        }
                        didDeleteFail = !didDelete
                        readerStore.refreshPassageHighlights()
                        librarySelection.endSelection()
                    }
                } message: {
                    let count = librarySelection.selectedIDCount ?? 0
                    let noun = count == 1 ? "annotation" : "annotations"
                    Text(
                        "The \(count) selected \(noun) will be permanently deleted."
                    )
                }
            }
        }
        // Visible list change: update selected items
        .onChange(of: libraryStore.filteredAnnotations) {
            librarySelection.deselectHidden(visibleIDs: Set(libraryStore.filteredAnnotations.map { $0.id }))
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
                                                                bibleCatalogStore: catalogStore,
                                                                libraryStore: libraryStore)

                    var isRowSelected: Bool? {
                        guard librarySelection.isSelecting else {
                            return nil
                        }
                        return librarySelection.isSelected(annotation.id)
                    }


                    // Build actual single annotation view
                    LibraryRowView(
                        data: libraryRowViewData,
                        isRowSelected: isRowSelected,
                        onHighlightColorChangeRequested: { color in
                            let didChange = withAnimation(.snappy(duration: 0.35)) {
                                libraryStore.changeHighlightColor(annotation.id,
                                                                  color: color)
                            }
                            if didChange {
                                readerStore.refreshPassageHighlights()
                                didHighlightColorChangeFail = false // reset state
                            } else {
                                didHighlightColorChangeFail = true
                            }
                        },
                        onDeleteRequested: {
                            let didDelete = withAnimation(.snappy(duration: 0.35)) {
                                libraryStore.delete(annotation.id)
                            }
                            if didDelete {
                                readerStore.refreshPassageHighlights()
                                didDeleteFail = false // reset state
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
                        },
                        onAnnotationEditorRequested: {
                            annotationEditor = libraryStore.annotationEditor(for: annotation)
                        },
                        onRowSelected: {
                            // Animates the row's checkmark + border and the Delete button
                            withAnimation(.smooth(duration: 0.35)) {
                                let isSelected = librarySelection.isSelected(annotation.id)
                                if isSelected {
                                    librarySelection.removeFromSelection(annotation.id)
                                } else {
                                    librarySelection.addToSelection(annotation.id)
                                }
                            }
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
        //   popover anchors to the card being deleted rather than the whole ScrollView
        .swipeActionsContainerIfAvailable()
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Views (Toolbar)

    /// Options for filtering the library (not visible in edit mode)
    @ToolbarContentBuilder
    private var filterOptionsToolbarItem: some ToolbarContent {
        @Bindable var store: LibraryStore = libraryStore

        // Filter By: Translation, Book, Highlight Color, Tag
        ToolbarItem(placement: .automatic) {
            Menu {
                Text("Filter By")

                // Translations
                Picker(selection: $store.filter.translationID) {
                    // "All" row: tag type must be String? to match the binding
                    Text("All Translations")
                        .tag(Translation.ID?.none) // aka nil

                    ForEach(Set(libraryStore.annotations.map(\.translationID)).sorted(), id: \.self) { translationID in
                        let label = catalogStore.translation(for: translationID)?.abbreviation ?? translationID.description
                        Text(label)
                            .tag(Optional(translationID)) // ID?, not ID
                    }
                } label: {
                    Label("Translation", systemImage: "text.book.closed")
                    if let translationID = libraryStore.filter.translationID {
                        let label = catalogStore.translation(for: translationID)?.abbreviation
                        ?? translationID.description
                        Text(label)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .pickerStyle(.menu)

                // Books
                Picker(selection: $store.filter.bookCode) {
                    // "All" row: tag type must be String? to match the binding
                    Text("All Books")
                        .tag(String?.none) // aka nil

                    // Group by unique book code; only take first one; sort
                    // TODO: sort according to Bible ordering (may need to hardcode as API doesnt return this...?)
                    ForEach(uniqueBookCodeAnnotations) { annotation in
                        let label = catalogStore.book(for: annotation.translationID,
                                                      bookCode: annotation.bookCode)?.displayName ?? annotation.bookCode
                        Text(label)
                            .tag(Optional(annotation.bookCode)) // String?, not String
                    }
                } label: {
                    Label("Book", systemImage: "books.vertical")
                    if let bookCode = libraryStore.filter.bookCode,
                       let translationID = uniqueBookCodeAnnotations.first(where: { $0.bookCode == bookCode })?.translationID {
                        let label = catalogStore.book(for: translationID,
                                                      bookCode: bookCode)?.displayName ?? bookCode
                        Text(label)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .pickerStyle(.menu)

                Divider()

                // Annotation Type
                Picker(selection: $store.filter.contentType) {
//                    Text("All Types")
                    Label("All", systemImage: "circle.dotted")
                        .tag(AnnotationContentType?.none) // aka nil
                    Label("Highlights", systemImage: "pencil.line")
                        .tag(Optional(AnnotationContentType.highlight))
                    Label("Tags", systemImage: "tag")
                        .tag(Optional(AnnotationContentType.tags))
                    Label("Notes", systemImage: "text.alignleft")
                        .tag(Optional(AnnotationContentType.note))
                } label: {
                    Label("Annotation Type", systemImage: "square.3.layers.3d.top.filled")
                }
                .pickerStyle(.palette)

                // Highlight Colors
                Picker(selection: $store.filter.highlightColor) {
                    // "All" row: tag type must match the binding (VerseAnnotationHighlightColor?)
//                    Text("All Colors")
                    Label("All", systemImage: "circle.dotted")
                        .tag(VerseAnnotationHighlightColor?.none)

                    ForEach(VerseAnnotationHighlightColor.allCases.filter { color in
                        store.annotations.contains { $0.highlightColor == color }
                    }, id: \.self) { highlightColor in
                        Label {
                            Text(highlightColor.rawValue.capitalized)
                        } icon: {
                            highlightSwatch(highlightColor)
                        }
                        .tag(Optional(highlightColor))
                    }
                } label: {
                    Label("Highlight Color", systemImage: "pencil.line")
                }
                .pickerStyle(.palette)
//                .disabled(libraryStore.filter.contentType == .tags || libraryStore.filter.contentType == .note)

                // Tags
                Picker(selection: $store.filter.tag) {
                    // "All" row: tag type must be String? to match the binding
                    Text("All Tags")
                        .tag(String?.none) // aka nil

                    ForEach(store.allTags.sorted(), id: \.self) { tag in
                        Text(tag)
                            .tag(Optional(tag))   // String?, not String
                    }
                } label: {
                    Label("Tag", systemImage: "tag")
                }
                .pickerStyle(.menu)
//                .disabled(libraryStore.filter.contentType == .highlight || libraryStore.filter.contentType == .note)

                // Clear All Filters
                if libraryStore.filter.isAnyFilterActive {
                    Divider()
                    Button {
                        store.filter.clearAllFilters()
                    } label: {
                        Label("Clear All Filters", systemImage: "trash") // TODO: better symbol
                    }
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
                        // TODO
                    } label: {
                        Label("Date Added", systemImage: "calendar")
                    }
                    Button {
                        // TODO
                    } label: {
                        Label("Translation", systemImage: "text.book.closed")
                    }
                    Button {
                        // TODO
                    } label: {
                        Label("Book", systemImage: "books.vertical")
                    }
                } label: {
                    Label("Group By", systemImage: "rectangle.3.group")
                }

                // Select Annotations
                Divider()

                Button {
                    withAnimation(.snappy(duration: 0.35)) {
                        librarySelection.beginSelection()
                    }
                } label: {
                    Label("Select Annotations", systemImage: "checkmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }

    /// Options for Edit mode
    @ToolbarContentBuilder
    private var selectionOptionsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                withAnimation(.snappy(duration: 0.35)) {
                    librarySelection.endSelection()
                }
            } label: {
                Label("Done", systemImage: "checkmark")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.tint(.accent).interactive(), in: .circle)
            }
            .buttonStyle(.plain)
        }
        // The toolbar applies a prominent (tinted) style only after its glass morph finishes,
        // so the tint snapped in; drawing our own tinted glass lets it fade in with the item
        .sharedBackgroundVisibility(.hidden)
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

    /// Menus render SF Symbols as templates and drop foreground styles, so bake the
    /// color into a UIImage with `.alwaysOriginal` to keep it.
    private func highlightSwatch(_ color: VerseAnnotationHighlightColor) -> Image {
        let image = UIImage(systemName: "circle.fill")?
            .withTintColor(UIColor(color.uiColor), renderingMode: .alwaysOriginal)
        return Image(uiImage: image ?? UIImage())
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
    let libraryRepository = PreviewFixtures.seededLibraryRepository()
    let libraryStore = LibraryStore(libraryRepository: libraryRepository,
                                    passageStore: passageStore)
    let catalogStore = BibleCatalogStore(repository: repository)
    let readerStore = ReaderStore(passageStore: passageStore,
                                  catalogStore: catalogStore,
                                  libraryRepository: libraryRepository)
    LibraryPreviewHost(readerStore: readerStore,
                       libraryStore: libraryStore,
                       catalogStore: catalogStore)
}

/// Preview-only host
private struct LibraryPreviewHost: View {
    let readerStore: ReaderStore
    let libraryStore: LibraryStore
    let catalogStore: BibleCatalogStore

    var body: some View {
        LibraryView()
        .environment(readerStore)
        .environment(libraryStore)
        .environment(catalogStore)
        .task {
            libraryStore.load()
        }
    }
}
