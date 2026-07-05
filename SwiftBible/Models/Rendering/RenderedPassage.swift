//
//  RenderedPassage.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 7/2/26.
//

import Foundation

nonisolated struct RenderedPassage {
    var paragraphs: [RenderedParagraph]
    var footnotes: [Footnote]

    var referenceBookAndChapterDisplayName: String? = nil

    /// Retrieve all runs from this RenderedPassage for a given RenderedVerseRange
    func runs(for verseRange: RenderedVerseRange) -> [RenderedPassageRun] {
        // iterate all paragraphs' runs in order; keep only verse range matches + append to list
        return paragraphs.flatMap(\.runs).filter { $0.verseRange == verseRange }
    }
}
