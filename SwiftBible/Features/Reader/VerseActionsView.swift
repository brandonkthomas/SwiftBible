//
//  VerseActionsView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 7/5/26.
//

import SwiftUI

struct VerseActionsView: View {

    // MARK: Properties (Private)

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
                readerStore.selectedVerses = nil
            }) {
                Image(systemName: "xmark.circle")
                    .imageScale(.large)
            }

            // Label
            // TODO: hide when tab bar collapsed (to preserve space)
            Text(selectedLabel)

            // Empty space
            Spacer()

            // Share
            Button(action: {
                // TODO: open share sheet w/ verse text
            }) {
                Image(systemName: "square.and.arrow.up")
                    .imageScale(.large)
            }

            // Tag
            Button(action: {
                // TODO: open tag sheet
            }) {
                Image(systemName: "tag")
                    .imageScale(.large)
            }

            // Bookmark
            Button(action: {
                // TODO: open bookmark sheet
            }) {
                Image(systemName: "text.pad.header.badge.plus")
                    .imageScale(.large)
            }

            // Highlight
            Button(action: {
                // TODO: open highlight color picker popover
            }) {
                Image(systemName: "highlighter")
                    .imageScale(.large)
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
    }
}

#Preview("ContentView: Ready") {
    let repository = FakeBibleRepository()
    let readerStore = ReaderStore(repository: repository)

    ContentView()
        .environment(readerStore)
}
