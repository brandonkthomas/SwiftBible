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
    /// Number of distinct verses in this passage; a "16-17" range counts as 2
    var verseCount: Int {
        var verses = Set<Int>()

        for run in paragraphs.flatMap(\.runs) {
            guard let verseRange = run.verseRange else {
                continue
            }

            let endVerse = max(verseRange.endVerse ?? verseRange.startVerse, verseRange.startVerse)
            verses.formUnion(verseRange.startVerse...endVerse)
        }

        return verses.count
    }

    func runs(for verseRange: RenderedVerseRange) -> [RenderedPassageRun] {
        // iterate all paragraphs' runs in order; keep only verse range matches + append to list
        return paragraphs.flatMap(\.runs).filter { $0.verseRange?.overlaps(verseRange: verseRange) == true }
    }
}
