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

    @Environment(\.dismiss) var dismiss

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

    private var sheetTitle: String {
        guard let bookAndChapter = passage.referenceBookAndChapterDisplayName else {
            return footnotesForVerse.count == 1 ? "Footnote" : "Footnotes"
        }
        return "\(bookAndChapter):\(verseRange.displayText)"
    }

    // MARK: Views

    /// Footnote sheet view: show selected verse range + all applicable footnotes
    var body: some View {
        // Wrap in NavigationStack for title to render
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Verse content
                    PassageTextRenderer.text(for: passage.runs(for: verseRange),
                                                  mode: .inline)

                    Divider()

                    // stack of ordered footnotes
                    // Array(...) so enumerated() is a RandomAccessCollection ForEach accepts;
                    // offset drives the a/b/c label, element.id is the stable identity
                    ForEach(Array(footnotesForVerse.enumerated()), id: \.element.id) { index, footnote in
                        let label = footnoteLabel(for: footnote,
                                                  index: index)
                        Text("\(label)\(footnote.text)")
                            .font(.system(.footnote, design: .serif))
                    }
                }
                // inset on top/bottom
                .padding(EdgeInsets(top: 4, leading: 24, bottom: 0, trailing: 24))
                // sheet title
                .navigationTitle(sheetTitle)
                .navigationBarTitleDisplayMode(.inline)
            }
            .lineHeight(AttributedString.LineHeight.exact(points: 30))
            .font(.system(.body, design: .serif))
            .frame(maxWidth: .infinity, alignment: .topLeading)
            // toolbar for NavigationStack (for Close button)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        dismiss()
                    }) {
                        Label("Close", systemImage: "xmark")
                    }
                }
            }
        }
    }
}

#Preview {
    // Reuse fake repo's footnote fixture through real parser
    let passage = try! PassageHTMLParser().parse(html: FakeBibleRepository.footnotePassageHTML)

    ReaderPassageFootnoteSheetView(verseRange: RenderedVerseRange(startVerse: 2),
                                   passage: passage)
}
