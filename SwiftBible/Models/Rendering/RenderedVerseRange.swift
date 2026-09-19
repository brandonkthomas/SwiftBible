//
//  RenderedVerseRange.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 7/5/26.
//

import Foundation

// Hashable for ReaderPassageFootnoteSheetView's verse comparison/grouping
nonisolated struct RenderedVerseRange: Identifiable, Equatable, Hashable {

    // MARK: Properties

    /// Computed ID (pulls from Hashable implementation)
    var id: Self { self }
    
    let startVerse: Int
    let endVerse: Int?

    /// Computed verse range display string
    ///
    /// i.e. "1" or "1-2"
    var displayText: String {
        var end: String = ""
        if let endVerse = endVerse {
            end = "–\(endVerse)"
        }
        return "\(startVerse)\(end)"
    }

    // MARK: Init

    init(startVerse: Int, endVerse: Int? = nil) {
        self.startVerse = startVerse
        self.endVerse = endVerse
    }

    /// Does this instance's range overlap the inputted range?
    ///
    /// self start ≤ other end  AND  other start ≤ self end
    func overlaps(verseRange otherVerseRange: RenderedVerseRange) -> Bool {
        let otherEndVerse = otherVerseRange.endVerse ?? otherVerseRange.startVerse

        return self.startVerse <= otherEndVerse
        && otherVerseRange.startVerse <= (self.endVerse ?? self.startVerse)
    }
}
