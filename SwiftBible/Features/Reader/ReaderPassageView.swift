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

    var renderedPassage: RenderedPassage

    @State private var selectedFootnoteID: Footnote.ID?

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
    }

    // MARK: Functions

    /// Convert a single RenderedParagraph into an AttributedString
    ///
    /// TODO: change to use RenderedPassage so we can retrieve footnote content...?
    private func paragraphText(_ paragraph: RenderedParagraph) -> AttributedString {
        var result = AttributedString()

        for run in paragraph.runs {
            switch run {
            case .text(let text, verseRange: _):
                let attributedText = AttributedString(text)
                result.append(attributedText + " ")

            case .verseLabel(displayText: let displayText, verseRange: _):
                var attributedLabel = AttributedString(displayText)
                attributedLabel.baselineOffset = 6
                attributedLabel.font = .system(.caption2, design: .serif)
                attributedLabel.foregroundColor = .secondary
                result.append(attributedLabel + " ")

            case .footnoteMarker(_, verseRange: _):
                var attributedMarker = AttributedString("\(Image(systemName: "document"))")
                attributedMarker.baselineOffset = 6
                attributedMarker.font = .system(.caption2, design: .serif)
                attributedMarker.foregroundColor = .accentColor
//                attributedMarker.setAttributes(markerID: markerID)
                result.append(" " + attributedMarker + " ")
            }
        }

        return result
    }
}
