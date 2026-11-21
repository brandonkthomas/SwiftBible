//
//  ScriptureSearchProvider.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-20.
//

import Foundation

nonisolated struct ScriptureSearchPage: Equatable {
    let results: [ScriptureSearchResult]
    let nextCursor: ScriptureSearchCursor?
    var suggestions: [String] = []
    var searchedInsteadFor: String? = nil
    var intent: ScriptureSearchIntent = .unknown
}

nonisolated struct ScriptureSearchResult: Equatable, Identifiable {
    var id: String {
        "\(translationID.description)_\(bookCode)_\(chapter)_\(verseRange.lowerBound)-\(verseRange.upperBound)"
    }

    let translationID: Translation.ID
    let bookCode: String
    let chapter: Int
    let verseRange: ClosedRange<Int>
    let snippet: String?

    var passageKey: BiblePassageKey {
        .init(translationID: translationID,
              bookCode: bookCode,
              chapter: chapter)
    }
}

/// Keep in sync w/ YouVersionSearchVerseUserIntentResponse
nonisolated enum ScriptureSearchIntent: Equatable {
    case unknown
    case text
    case topical
    case reference
}

nonisolated enum ScriptureSearchCursor: Equatable {
    /// for YouVersion
    case pageToken(String)
    /// for Crossway
    case pageNumber(Int)
}

nonisolated enum ScriptureSearchError: Error, Equatable {
    case unsupportedTranslation
}
