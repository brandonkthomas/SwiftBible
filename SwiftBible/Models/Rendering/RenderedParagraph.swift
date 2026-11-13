//
//  RenderedParagraph.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 7/2/26.
//

import Foundation

nonisolated struct RenderedParagraph: Equatable {

    // MARK: Properties

    var style: RenderedParagraphStyle = .paragraph
    var runs: [RenderedPassageRun]
}

/// Style to present the rendered paragraph in (para, line quote, indented quote)
nonisolated enum RenderedParagraphStyle: Equatable {
    case paragraph
    case quoteLine
    case indentedLine
}

// MARK: Init (Plain Verses)

extension RenderedParagraph {

    /// Build a paragraph from plain verse strings, numbered from `startingVerse`
    ///
    /// Each verse becomes a verse label run followed by a text run
    init(verses: [String], startingVerse: Int = 1) {
        self.init(runs: verses.enumerated().flatMap { offset, verse -> [RenderedPassageRun] in
            let verseRange = RenderedVerseRange(startVerse: startingVerse + offset)
            return [.verseLabel(displayText: verseRange.displayText, verseRange: verseRange),
                    .text(verse, verseRange: verseRange)]
        })
    }
}
