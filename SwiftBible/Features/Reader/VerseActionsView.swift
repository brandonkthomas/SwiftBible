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

//    /// Read appEnvironment.libraryRepository environment value from current view environment
//    ///
//    /// Don't need "\." here because this is a type-based lookup for an observable instance
//    /// placed into the environment: .environment(readerStore))
//    @Environment(\.libraryRepository) private var libraryRepository: any LibraryRepository

    // MARK: Properties (Private, State)

    @State private var isHighlightPopoverPresented: Bool = false
    @State private var showEraser: Bool = false

    private var selectedLabel: String {
        guard let selectedVerses = readerStore.selectedVerses else {
            return ""
        }
        let count = selectedVerses.count
        return "\(count) Verse\(count == 1 ? "" : "s")" //... Selected
    }

    // MARK: Views

    /// Tab bar accessory for Reader view
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

            // only show label + spacer when expanded
            // this will smoothly transition when bar is collapsed/expanded in real time
            if placement == .expanded || placement == nil {
                // Label
                Text(selectedLabel)
                    .transition(.blurReplace)

                // Empty space
                Spacer()
                    .transition(.blurReplace)
            }

            // Highlight
            highlightAction()

            // Bookmark
            Button(action: {
                // TODO: open bookmark sheet
            }) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 20)))
            }

            // Tag
            Button(action: {
                // TODO: open tags sheet
            }) {
                Image(systemName: "tag.fill")
                    .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 20)))
            }

            // Share
            ShareLink(item: "",
                      preview: SharePreview("", image: "AppIcon")) { // TODO: get raw text from readerStore.selectedVerses
                Label("", systemImage: "square.and.arrow.up.fill")
                    .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 20)))
            }
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
        })
    }

    /// Produces a selectable circle button for a given highlight color
    private func highlightColorButton(for color: VerseAnnotationHighlightColor) -> some View {
        Button(action: {
            withAnimation(.snappy(duration: 0.35)) {
                if showEraser {
                    readerStore.deleteHighlights()
                } else {
                    readerStore.saveHighlight(color)
                }
            }
        }) {
            let size = UIFontMetrics(forTextStyle: .body).scaledValue(for: 30)
            Text("")
                .frame(width: size, height: size)
                .foregroundColor(Color.black)
                .background(color.uiColor)
                .clipShape(Circle())
        }
        // blend in w/ surrounding elements
        .glassEffect()
    }
}

#Preview("ContentView: Ready") {
    let repository = FakeBibleRepository()
    let readerStore = ReaderStore(repository: repository,
                                  libraryRepository: InMemoryLibraryRepository())

    ContentView()
        .environment(readerStore)
}
