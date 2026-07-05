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

    @State private var selectedVerse: RenderedVerseRange?

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

                        Text(PassageTextRenderer.attributedString(for: paragraph.runs,
                                                                  mode: .collapsed))
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

            guard let components = URLComponents(string: url.absoluteString),
                  let queryItems = components.queryItems,
                  let startVerse = Int(queryItems.first(where: { $0.name == "sv" })?.value ?? "") else {
                return .discarded
            }

            let endVerse = Int(queryItems.first(where: { $0.name == "ev" })?.value ?? "")

            selectedVerse = RenderedVerseRange(startVerse: startVerse,
                                               endVerse: endVerse)

            return .handled // we dealt with it; don't open a browser
        })
        // Open sheet when above openURL handler sets selectedVerse
        .sheet(item: $selectedVerse) { verse in
            ReaderPassageFootnoteSheetView(verseRange: verse,
                                           passage: renderedPassage)
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.scrolls)
        }
    }
}

// MARK: Xcode Canvas Previews

#Preview {
    let passage = try! PassageHTMLParser().parse(html: FakeBibleRepository.footnotePassageHTML)

    ReaderPassageView(renderedPassage: passage)
}
