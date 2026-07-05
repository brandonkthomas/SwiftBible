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

    private func footnoteLabel(for footnote: Footnote,
                               index: Int) -> AttributedString {
        // Same a/b/c label that Renderer places inline so list/text stay in sync
        var attributedLabel = AttributedString("\(PassageTextRenderer.footnoteSymbol(for: index)) ")
        attributedLabel.baselineOffset = 6
        attributedLabel.font = .system(.caption2, design: .serif, weight: .bold)
        attributedLabel.foregroundColor = .accentColor

        return attributedLabel
    }

    // MARK: Views

    /// Footnote sheet view: show selected verse range + all applicable footnotes
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(PassageTextRenderer.attributedString(for: passage.runs(for: verseRange),
                                                          mode: .inline))
                Divider()
                // Array(...) so enumerated() is a RandomAccessCollection ForEach accepts;
                // offset drives the a/b/c label, element.id is the stable identity
                ForEach(Array(footnotesForVerse.enumerated()), id: \.element.id) { index, footnote in
                    let label = footnoteLabel(for: footnote,
                                              index: index)
                    Text("\(label)\(footnote.text)")
                }
            }
            // inset on top/bottom
            .padding(EdgeInsets(top: 24, leading: 0, bottom: 24, trailing: 0))
        }
        .lineHeight(AttributedString.LineHeight.exact(points: 30))
        .font(.system(.body, design: .serif))
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // inset on L/R edges
        .padding(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
    }
}

#Preview {
    // Reuse fake repo's footnote fixture through real parser
    let passage = try! PassageHTMLParser().parse(html: FakeBibleRepository.footnotePassageHTML)

    ReaderPassageFootnoteSheetView(verseRange: RenderedVerseRange(startVerse: 2),
                                   passage: passage)
}
