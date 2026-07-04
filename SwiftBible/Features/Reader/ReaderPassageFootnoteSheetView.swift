//
//  ReaderPassageFootnoteSheetView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 7/4/26.
//

import SwiftUI

struct ReaderPassageFootnoteSheetView: View {

    // MARK: Properties

    let verseRange: RenderedVerseRange
    let passage: RenderedPassage

    // MARK: Properties (Computed)

    private var footnotesForVerse: [Footnote] {
        passage.footnotes.filter { $0.verseRange == verseRange }
    }

    private var selectedVerse: String {
//        passage.paragraphs { $0.verseRange == verseRange }
        return "Verse content."
    }

    private func footnoteLabel(for footnote: Footnote) -> AttributedString {
        var attributedLabel = AttributedString("\(footnote.id) ")
        attributedLabel.baselineOffset = 6
        attributedLabel.font = .system(.caption2, design: .serif)
        attributedLabel.foregroundColor = .secondary
        return attributedLabel
    }

    // MARK: Views

    /// Footnote sheet view: show selected verse range + all applicable footnotes
    var body: some View {
        // TODO: align left horizontally
        ScrollView {
            VStack {
                Text(selectedVerse)
                Divider()
                ForEach(footnotesForVerse) { footnote in
                    // append verse label immediately

                    Group {
                        Text(footnoteLabel(for: footnote))
                        Text(footnote.text)
                    }
                }
            }
        }
        .lineHeight(AttributedString.LineHeight.exact(points: 30))
        .font(.system(.body, design: .serif))
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // inset on L/R edges; spacing between paragraphs
        .padding(EdgeInsets(top: 24, leading: 24, bottom: 2, trailing: 24))
    }
}

#Preview {
    let range = RenderedVerseRange(startVerse: 1,
                                   endVerse: 2)

    ReaderPassageFootnoteSheetView(verseRange: range,
                                   passage: RenderedPassage(paragraphs: [],
                                                            footnotes: [Footnote(id: 1,
                                                                                 verseRange: range,
                                                                                 text: "hello")]))
}
