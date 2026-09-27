//
//  VerseActionsView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 7/5/26.
//

import SwiftUI

struct VerseActionsView: View {

    // MARK: Properties (Private)

    /// Is the tab bar accessory currently collapsed or expanded?
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    /// Read appEnvironment.readerStore environment value from current view environment
    ///
    /// Don't need "\." here because this is a type-based lookup for an observable instance
    /// placed into the environment: .environment(readerStore))
    @Environment(ReaderStore.self) private var readerStore: ReaderStore

    /// Read appEnvironment.bibleCatalogStore environment value from current view environment
    ///
    /// Required for AnnotationEditorSheetView
    @Environment(BibleCatalogStore.self) private var bibleCatalogStore: BibleCatalogStore

    /// Used for Liquid Glass effects in highlight popover
    @Namespace private var highlightColorPopoverNamespace

    // MARK: Properties (Private, State)

    /// AnnotationEditor session:
    /// if nil, nothing selected;
    /// if non-nil, we have an existing session and need to open AnnotationEditorSheetView
    @State private var annotationEditor: AnnotationEditor?

    @State private var isHighlightPopoverPresented: Bool = false

    /// Eraser state as of the last live selection; only displayed while there is no selection
    /// (the deselect closing animation), so the icon doesn't flash on the way out
    @State private var lastSelectionShowedEraser: Bool = false

    /// Live store value while a selection exists; remembered value while deselecting
    ///
    /// Reading the store directly means a reused view (quick reselect during the removal
    /// transition, where .onAppear/.onChange may not fire) can't show a stale icon
    private var showEraser: Bool {
        guard readerStore.selectedVerses != nil else {
            return lastSelectionShowedEraser
        }
        return readerStore.selectionContainsHighlight
    }

    private var isExpandedPlacement: Bool {
        placement == .expanded || placement == nil
    }

    private var chapterAndVersesLabel: String {
        guard let selectedChapter = readerStore.selectedChapter,
              let selectedVerses = readerStore.selectedVerses else {
            return ""
        }
        let endText = selectedVerses.upperBound == selectedVerses.lowerBound
            ? ""
            : "-\(selectedVerses.upperBound)"

        return "\(selectedChapter.number):\(selectedVerses.lowerBound)\(endText)"
    }

    // MARK: Views

    /// Tab bar accessory for Reader view
    ///
    /// Expanded:   \[  X  1:1-3 Selected      Pen  Bookmark  Share  \]
    /// Collapsed:   \[  X  1:1-3      Pen  Bookmark  Share  \]
    var body: some View {
        HStack(spacing: 15) {
            // Deselect
            Button(action: {
                // applies to all views observing this property;
                // so verse highlights, tabBarAccessory, etc
                withAnimation(.snappy(duration: 0.35)) {
                    readerStore.selectedVerses = nil
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 20),
                                  weight: .bold))
            }

            // Label
            // this will smoothly transition when bar is collapsed/expanded in real time
            HStack(spacing: 4) {
                if isExpandedPlacement,
                   let selectedBook = readerStore.selectedBook {
                    Text(selectedBook.displayName)
                        .transition(.blurReplace)
                }

                Text(chapterAndVersesLabel)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .animation(.snappy(duration: 0.35), value: isExpandedPlacement)

            Spacer()

            // Highlight
            highlightAction()

            // Tags/Note
            Button(action: {
                // build an instance + assign it here so that the .sheet() listener fires
                annotationEditor = readerStore.makeAnnotationEditor()
            }) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 20)))
            }

            // Share
            Button(action: {
                // TODO: open share sheet
            }) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 20)))
            }
            // SHARELINK has weird trailing space
//            ShareLink(item: "",
//                      preview: SharePreview("", image: "AppIcon")) { // TODO: get raw text from readerStore.selectedVerses
//                Label("", systemImage: "square.and.arrow.up.fill")
//                    .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 20)))
//            }
        }
        // font, color
        .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 14),
                      weight: .medium,
                      design: .serif))
        .foregroundStyle(.primary)
        // frame, padding, bounding
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .contentShape(Rectangle())
        // allows transition between this and PassagePickerView on tabBarAccessory
        .transition(.blurReplace)
        // allows transition for hiding Label/Spacer based on tabbar collapsed status
        // TODO: Disabled for now as this causes extra animation overlap + stutter on the 4
        // rightmost buttons
//        .animation(.default, value: placement)
        // Remember the eraser state while a selection exists (NOT on deselect) so the
        // closing animation keeps the previous icon
        // Both values are observed: either can change without the other
        .onAppear {
            rememberEraserState()
        }
        .onChange(of: readerStore.selectedVerses) {
            // A popover belongs to one selection; never carry it into another
            isHighlightPopoverPresented = false
            rememberEraserState()
        }
        .onChange(of: readerStore.selectionContainsHighlight) {
            rememberEraserState()
        }
        // Fire AnnotationEditorSheetView when $annotationEditor instance is assigned
        .sheet(item: $annotationEditor) { editor in
            AnnotationEditorSheetView(editor: editor,
                                      bibleCatalogStore: bibleCatalogStore)
                .presentationDragIndicator(.visible)
        }
    }

    /// Highlight action item (pen/eraser; compact pen popover)
    private func highlightAction() -> some View {
        Button(action: {
            if showEraser {
                withAnimation(.snappy(duration: 0.35)) {
                    readerStore.deleteHighlights()
                }
            } else {
                isHighlightPopoverPresented = true
            }
        }) {
            // highlighter symbol doesnt have fill style :(
            let symbolName = showEraser
                ? "eraser.line.dashed.fill"
                : "pencil.line"
            let symbolSize: CGFloat = showEraser ? 22 : 26
            Image(systemName: symbolName)
                .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: symbolSize)))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.primary, .gray)
                // allow transition between image states
                .contentTransition(.symbolEffect(.replace.offUp.byLayer, options: .nonRepeating))
        }
        .popover(isPresented: $isHighlightPopoverPresented,
                 attachmentAnchor: .point(.top),
                 arrowEdge: .bottom,
                 content: {
            // Close the popover before saving/deleting: both deselect, which starts removing this
            // view; if that removal is cancelled by a quick reselect, the view (and its @State)
            // is reused, so a still-true flag would re-present the popover
            HighlightPickerView(
                onCreateRequested: { color in
                    isHighlightPopoverPresented = false
                    readerStore.save(.highlight(color))
                },
                onDeleteRequested: {
                    isHighlightPopoverPresented = false
                    readerStore.deleteHighlights()
                },
                existingHighlightColors: readerStore.selectionHighlightColors
            )
        })
    }

    // MARK: Functions (Private)

    /// Store the current eraser state for use during the deselect animation (ignored when deselected)
    private func rememberEraserState() {
        guard readerStore.selectedVerses != nil else {
            return
        }
        lastSelectionShowedEraser = readerStore.selectionContainsHighlight
    }
}

#Preview("ContentView: Ready") {
    let repository = FakeBibleRepository()
    let passageStore = BiblePassageStore(repository: repository,
                                         passageCache: InMemoryPassageCache())
    let readerStore = ReaderStore(passageStore: passageStore,
                                  catalogStore: BibleCatalogStore(repository: repository),
                                  libraryRepository: InMemoryLibraryRepository())

    ContentView()
        .environment(readerStore)
}
