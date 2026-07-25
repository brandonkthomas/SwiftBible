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

    /// Used for Liquid Glass effects in highlight popover
    @Namespace private var highlightColorPopoverNamespace

//    /// Read appEnvironment.libraryRepository environment value from current view environment
//    ///
//    /// Don't need "\." here because this is a type-based lookup for an observable instance
//    /// placed into the environment: .environment(readerStore))
//    @Environment(\.libraryRepository) private var libraryRepository: any LibraryRepository

    // MARK: Properties (Private, State)

    @State private var isHighlightPopoverPresented: Bool = false
    @State private var showEraser: Bool = false

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
                // TODO: open AnnotationEditorSheetView
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
        // Seed showEraser up front to prevent flash on deselect
        // Update showEraser on selection change (NOT deselect)
        // Do not update showEraser on deselect to persist prev state through the closing animation
        .onAppear {
            showEraser = readerStore.selectionContainsHighlight
        }
        .onChange(of: readerStore.selectionContainsHighlight) { _, newValue in
            if readerStore.selectedVerses != nil {
                showEraser = newValue
            }
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
            GlassEffectContainer(spacing: 15) {
                HStack(spacing: 15) {
                    // show 1 button for each public color
                    ForEach(VerseAnnotationHighlightColor.allCases, id: \.rawValue) { item in
                        highlightColorButton(for: item)
                    }
                }
                // popover padding on L/R
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                // open minimal popover view
                .presentationCompactAdaptation(.none)
            }
        })
    }

    /// Produces a selectable circle button for a given highlight color
    private func highlightColorButton(for color: VerseAnnotationHighlightColor) -> some View {
        @State var triggerHaptic: Bool = false
        let sensoryFeedback: SensoryFeedback = showEraser ? .warning : .success

        return Button(action: {
            withAnimation(.snappy(duration: 0.35)) {
                if showEraser {
                    readerStore.deleteHighlights()
                } else {
                    readerStore.save(.highlight(color))
                }
            }
            triggerHaptic.toggle()
        }) {
            let size = UIFontMetrics(forTextStyle: .body).scaledValue(for: 30)
            Text("")
                .frame(width: size, height: size)
                .foregroundColor(Color.black)
            //                .background(color.uiColor)
            //                .clipShape(Circle())
        }
        // blend in w/ surrounding elements
        .glassEffect(.regular.tint(color.uiColor).interactive(),in: .circle)
        // haptic on selection
        .sensoryFeedback(sensoryFeedback, trigger: triggerHaptic)
    }
}

#Preview("ContentView: Ready") {
    let repository = FakeBibleRepository()
    let readerStore = ReaderStore(repository: repository,
                                  libraryRepository: InMemoryLibraryRepository())

    ContentView()
        .environment(readerStore)
}
