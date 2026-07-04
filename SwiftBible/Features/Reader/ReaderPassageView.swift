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

//    @State private var isShowingPopover = false

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

                        Text(paragraphText(paragraph))
                            .frame(maxWidth: .infinity, alignment: .leading)
//                            .onTapGesture {
//                                isShowingPopover = true
//                            }
//                            .popover(isPresented: $isShowingPopover) {
//                                Text("Test prototype for verse selection options")
//                                    .padding()
//                                    .frame(width: 300, height: 200)
//                            }
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
        // TODO: open footnote sheet
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
        // TODO: wire ReaderPassageFootnoteSheetView w/ verse content + list of all footnotes
        .sheet(item: $selectedVerse) { verse in
            ReaderPassageFootnoteSheetView(verseRange: verse,
                                           passage: renderedPassage)
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.scrolls)
        }
    }

    // MARK: Functions

    /// Convert a single RenderedParagraph into an AttributedString
    ///
    /// TODO: when footnote sheet tap is implemented, change this to use RenderedPassage so we can retrieve
    /// footnote content
    private func paragraphText(_ paragraph: RenderedParagraph) -> AttributedString {
        var result = AttributedString()

        // Track verse progress so we can append a single footnote marker at the end
        var accumulatingVerse: RenderedVerseRange?   // verse currently being built
        var verseHasFootnote = false

        // Append footnote marker if current verse has a footnote
        func flushMarkerIfNeeded() {
            guard verseHasFootnote,
                  let verse = accumulatingVerse else { return }

            var attributedMarker = AttributedString("† ")
            attributedMarker.baselineOffset = 6
            attributedMarker.font = .system(.caption2, design: .serif, weight: .bold)
            attributedMarker.foregroundColor = .accentColor

            // NOTE: this will allow iOS long-press behavior; to replace
            var url = "swiftbible://footnote?sv=\(verse.startVerse)"

            if let endVerse = verse.endVerse {
                url.append("&ev=\(endVerse)")
            }
            attributedMarker.link = URL(string: url)

            result.append(attributedMarker)
            verseHasFootnote = false
        }

        // If prev verse just ended, append marker to end of old verse + swap to new verse
        func beginVerseIfChanged(_ verseRange: RenderedVerseRange?) {
            if verseRange != accumulatingVerse {
                flushMarkerIfNeeded()
                accumulatingVerse = verseRange
            }
        }

        // Actual output loop
        for run in paragraph.runs {
            switch run {
            case .text(let text,
                       verseRange: let currentVerseRange):
                // If prev verse just ended, swap to new verse + append marker to end of old verse
                beginVerseIfChanged(currentVerseRange)

                // append verse text
                let attributedText = AttributedString("\(text) ")

                result.append(attributedText)

            case .verseLabel(displayText: let displayText,
                             verseRange: let currentVerseRange):
                // If prev verse just ended, swap to new verse + append marker to end of old verse
                beginVerseIfChanged(currentVerseRange)

                // append verse label immediately
                var attributedLabel = AttributedString("\(displayText) ")
                attributedLabel.baselineOffset = 6
                attributedLabel.font = .system(.caption2, design: .serif)
                attributedLabel.foregroundColor = .secondary

                result.append(attributedLabel)

            case .footnoteMarker(_, _):
                // don't append right now; just set a marker that the current verse has footnote(s)
                verseHasFootnote = true

//                let string = "\(verseRange.startVerse)\(verseRange.endVerse != nil ? "-\(verseRange.endVerse!)" : "")"
//                var attributedMarker = AttributedString() // originally 0-based
//                attributedMarker.baselineOffset = 6
//                attributedMarker.font = .system(.caption2, design: .serif, weight: .thin).italic(true)
//                attributedMarker.foregroundColor = .accentColor
////                attributedMarker.setAttributes(markerID: markerID)
//                result.append(" " + attributedMarker + " ")
            }
        }

        // final call for footnotes
        flushMarkerIfNeeded()

        return result
    }
}

// MARK: Xcode Canvas Previews

#Preview {
    ReaderPassageView(
        renderedPassage: RenderedPassage(
            paragraphs: [
                RenderedParagraph(
                    runs: [
                        .verseLabel(displayText: "1", verseRange: RenderedVerseRange(startVerse: 1)),
                        .text(
                            "In the beginning God created the heavens and the earth.",
                            verseRange: RenderedVerseRange(startVerse: 1)
                        ),
                        .verseLabel(displayText: "2", verseRange: RenderedVerseRange(startVerse: 2)),
                        .text(
                            "Now the earth was formless and empty, darkness",
                            verseRange: RenderedVerseRange(startVerse: 2)
                        ),
                        .footnoteMarker(1, verseRange: RenderedVerseRange(startVerse: 2)),
                        .text(
                            " was over the surface of the deep.",
                            verseRange: RenderedVerseRange(startVerse: 2)
                        ),
                        .footnoteMarker(2, verseRange: RenderedVerseRange(startVerse: 2)),
                    ]
                ),
                RenderedParagraph(
                    runs: [
                        .verseLabel(displayText: "3", verseRange: RenderedVerseRange(startVerse: 3)),
                        .text(
                            "And God said, Let there be light, and there was light.",
                            verseRange: RenderedVerseRange(startVerse: 3)
                        )
                    ]
                )
            ],
            footnotes: []
        )
    )
}

