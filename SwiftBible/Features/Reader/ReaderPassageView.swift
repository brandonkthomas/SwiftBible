//
//  ReaderPassageView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import SwiftUI

/// Main scrollview for text; only called once we've validated all other states
struct ReaderPassageView: View {

    // MARK: Properties

    /// Entire pre-rendered passage that we need to display
    /// Contains all paragraphs (text/labels/footnote markers) & actual footnote content
    var renderedPassage: RenderedPassage

    // MARK: Properties (Private)

    /// Is the tab bar accessory currently collapsed or expanded?
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    /// Read appEnvironment.readerStore environment value from current view environment
    ///
    /// Don't need "\." here because this is a type-based lookup for an observable instance
    /// placed into the environment: .environment(readerStore))
    @Environment(ReaderStore.self) private var readerStore: ReaderStore

    /// When set, ReaderPassageFootnoteSheetView will open
    @State private var selectedVerseRangeForFootnote: RenderedVerseRange?

    // MARK: Views

    /// Reader view
    var body: some View {
        ScrollView {
            // LazyVStack only renders components when they're visible BUT it makes scrollbar jumpy
            VStack {
                Group {
                    let paragraphs = renderedPassage.paragraphs

                    // all integer indexes (0-based); stop before paragraphs.count
                    ForEach(0..<paragraphs.count, id: \.self) { paragraphIndex in
                        let paragraph = paragraphs[paragraphIndex]
                        PassageTextRenderer.text(for: paragraph.runs,
                                                 mode: .collapsed)
                            .textRenderer(VerseHighlightRenderer(selectedVerses: readerStore.selectedVerses))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineHeight(AttributedString.LineHeight.exact(points: 30))
                // inset on L/R edges; spacing between paragraphs
                .padding(EdgeInsets(top: 2, leading: 24, bottom: 2, trailing: 24))
            }
            .scrollTargetLayout()
            // prevent tab bar from covering up bottom few lines
            .padding(EdgeInsets(top: 24, leading: 0, bottom: 75, trailing: 0))
        }
        // Bind footnote tap to set selectedVerse
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "swiftbible" else {
                return .systemAction // we dont want to handle anything else
            }

            // Footnote branch
            if url.host == "footnote" {
                // validation
                guard let components = URLComponents(string: url.absoluteString),
                      let queryItems = components.queryItems,
                      let startVerse = Int(queryItems.first(where: { $0.name == "sv" })?.value ?? "") else {
                    return .discarded
                }
                let endVerse = Int(queryItems.first(where: { $0.name == "ev" })?.value ?? "")

                // setting this will open ReaderPassageFootnoteSheetView using the .sheet
                // modifier below
                selectedVerseRangeForFootnote = RenderedVerseRange(startVerse: startVerse,
                                                                   endVerse: endVerse)

                return .handled // we dealt with it; don't open a browser

            // Verse branch
            } else if url.host == "verse" {
                // validation
                guard let components = URLComponents(string: url.absoluteString),
                      let queryItems = components.queryItems,
                      let startVerse = Int(queryItems.first(where: { $0.name == "sv" })?.value ?? "") else {
                    return .discarded
                }
                // start verse / end verse ...
                // tapped verse's upper bound can be defined as "ev ?? sv"
                let endVerse = Int(queryItems.first(where: { $0.name == "ev" })?.value ?? "")

                // applies to all views observing this property;
                // so verse highlights, tabBarAccessory, etc
                withAnimation(.snappy(duration: 0.35)) {
                    readerStore.handleVerseSelection(startVerse: startVerse,
                                                     endVerse: endVerse)
                }

                return .handled // we dealt with it; don't open a browser

            // All other items: we don't need to handle; exit
            } else {
                return .discarded
            }
        })
        // Open ReaderPassageFootnoteSheetView when our OpenURLAction handler sets selectedVerse
        .sheet(item: $selectedVerseRangeForFootnote) { verse in
            ReaderPassageFootnoteSheetView(verseRange: verse,
                                           passage: renderedPassage)
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.scrolls)
        }
    }
}

// MARK: Xcode Canvas Previews

#Preview {
    let repository = FakeBibleRepository()
    let readerStore = ReaderStore(repository: repository)
    let passage = try! PassageHTMLParser().parse(html: FakeBibleRepository.footnotePassageHTML)

    ReaderPassageView(renderedPassage: passage)
        .environment(readerStore)
}
