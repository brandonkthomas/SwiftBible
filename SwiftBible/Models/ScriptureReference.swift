//
//  ScriptureReference.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/26/26.
//

/// Represents local Bible general reference location
/// (translation, book, chapter, verse)
nonisolated struct ScriptureReference: Equatable {

    // MARK: Properties

    let translationID: Int
    let bookCode: String
    let chapter: Int
    let startVerse: Int?
    let endVerse: Int?

    // MARK: Properties (Computed)

    var passageID: Passage.ID {
        return "\(bookCode).\(chapter)"
    }

    var verseRange: ClosedRange<Int>? {
        guard let startVerse else { return nil }
        if let endVerse {
            return startVerse...endVerse
        } else {
            return startVerse...startVerse
        }
    }

    // MARK: Init

    // Failable (init?): allow for validation
    init?(translationID: Int,
          bookCode: String,
          chapter: Int,
          startVerse: Int? = nil,
          endVerse: Int? = nil) {

        // chapter must be >= 1
        guard chapter >= 1 else {
            return nil
        }

        // endVerse is not allowed without startVerse
        if endVerse != nil, startVerse == nil {
            return nil
        }

        // startVerse and endVerse must be >= 1 if either exists
        if let startVerse, startVerse < 1 {
            return nil
        }
        if let endVerse, endVerse < 1 {
            return nil
        }

        // endVerse cannot be before/equal to startVerse if both exist
        if let startVerse, let endVerse, startVerse > endVerse {
            return nil
        }

        self.translationID = translationID
        self.bookCode = bookCode
        self.chapter = chapter
        self.startVerse = startVerse
        self.endVerse = endVerse
    }
}
