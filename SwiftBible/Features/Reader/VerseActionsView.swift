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
                // TODO: animation no longer works since we changed highlight engine; see ReaderPassageView
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
                // TODO: hide when tab bar collapsed (to preserve space)
                Text(selectedLabel)
                    .transition(.blurReplace)

                // Empty space
                Spacer()
                    .transition(.blurReplace)
            }

            // Highlight
            Button(action: {
                // TODO: open highlight color picker popover
            }) {
                Image(systemName: "pencil.line") // highlighter doesnt have fill style :(
                    .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 26)))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.primary, .yellow)
            }

            // Bookmark
            Button(action: {
                // TODO: open bookmark sheet
            }) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 20)))
            }

            // Tag
            Button(action: {
                // TODO: open tag sheet
            }) {
                Image(systemName: "tag.fill")
                    .font(.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 20)))
            }

            // Share
            Button(action: {
                // TODO: open share sheet w/ verse text
            }) {
                Image(systemName: "square.and.arrow.up.fill")
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
    }
}

#Preview("ContentView: Ready") {
    let repository = FakeBibleRepository()
    let readerStore = ReaderStore(repository: repository)

    ContentView()
        .environment(readerStore)
}
