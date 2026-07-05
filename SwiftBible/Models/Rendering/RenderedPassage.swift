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

    /// Retrieve all runs from this RenderedPassage for a given RenderedVerseRange
    func runs(for verseRange: RenderedVerseRange) -> [RenderedPassageRun] {
        var runs: [RenderedPassageRun] = []

        func appendIfMatching(_ run: RenderedPassageRun,
                              _ range: RenderedVerseRange?) {
            if verseRange == range {
                runs.append(run)
            }
        }

        // iterate all paragraphs' runs in order; keep only verse range matches + append to list
        for paragraph in paragraphs {
            for run in paragraph.runs {
                switch run {
                case .text(_, verseRange: let currentVerseRange):
                    appendIfMatching(run, currentVerseRange)
                case .footnoteMarker(_, verseRange: let currentVerseRange):
                    appendIfMatching(run, currentVerseRange)
                case .verseLabel(_, verseRange: let currentVerseRange):
                    appendIfMatching(run, currentVerseRange)
                }
            }
        }

        return runs
    }
}

nonisolated enum RenderedPassageRun: Equatable {
    case text(String, verseRange: RenderedVerseRange?)
    case verseLabel(displayText: String, verseRange: RenderedVerseRange?)
    case footnoteMarker(Footnote.ID, verseRange: RenderedVerseRange)
}

// Hashable for ReaderPassageFootnoteSheetView's verse comparison/grouping
nonisolated struct RenderedVerseRange: Identifiable, Equatable, Hashable {
    /// Computed ID (pulls from Hashable implementation)
    var id: Self { self }
    let startVerse: Int
    let endVerse: Int?

    init(startVerse: Int, endVerse: Int? = nil) {
        self.startVerse = startVerse
        self.endVerse = endVerse
    }
}
