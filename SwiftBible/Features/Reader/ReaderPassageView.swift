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
    }

    // MARK: Functions

    /// Convert a single RenderedParagraph into an AttributedString
    ///
    /// TODO: when footnote sheet tap is implemented, change this to use RenderedPassage so we can retrieve
    /// footnote content
    private func paragraphText(_ paragraph: RenderedParagraph) -> AttributedString {
        var result = AttributedString()

        // Output
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

            case .footnoteMarker(let footnoteID, let verseRange):
                let string = "\(verseRange.startVerse)\(verseRange.endVerse != nil ? "-\(verseRange.endVerse!)" : "")"
                var attributedMarker = AttributedString() // originally 0-based
                attributedMarker.baselineOffset = 6
                attributedMarker.font = .system(.caption2, design: .serif, weight: .thin).italic(true)
                attributedMarker.foregroundColor = .accentColor
//                attributedMarker.setAttributes(markerID: markerID)
                result.append(" " + attributedMarker + " ")
            }
        }

        return result
    }
}
