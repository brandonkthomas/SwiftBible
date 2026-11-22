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

    /// Highest verse number in this passage, or nil when there are no verses
    var lastVerseNumber: Int? {
        paragraphs.flatMap(\.runs)
            .compactMap(\.verseRange)
            .map { max($0.endVerse ?? $0.startVerse, $0.startVerse) }
            .max()
    }

    /// Index of the first paragraph whose runs include the given verse
    func paragraphIndex(containing verse: Int) -> Int? {
        paragraphs.firstIndex { paragraph in
            paragraph.runs.contains { run in
                guard let verseRange = run.verseRange else {
                    return false
                }
                return verseRange.startVerse <= verse
                    && verse <= max(verseRange.endVerse ?? verseRange.startVerse, verseRange.startVerse)
            }
        }
    }

    /// Retrieve all runs from this RenderedPassage for a given RenderedVerseRange
    /// Number of distinct verses in this passage; a "16-17" range counts as 2
    func runs(for verseRange: RenderedVerseRange) -> [RenderedPassageRun] {
        // iterate all paragraphs' runs in order; keep only verse range matches + append to list
        return paragraphs.flatMap(\.runs).filter { $0.verseRange?.overlaps(verseRange: verseRange) == true }
    }
}
