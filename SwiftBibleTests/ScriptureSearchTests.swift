//
//  ScriptureSearchTests.swift
//  SwiftBibleTests
//

import Testing
@testable import SwiftBible

/// Search step 1: shared result types, and the default for providers that can't search
@MainActor
struct ScriptureSearchTests {

    /// A provider that doesn't implement search says so up front (the UI shows "unavailable")
    @Test func repositoryWithoutSearchDoesNotSupportIt() {
        let repository = FakeBibleRepository()

        #expect(repository.supportsSearch(translationID: 1234) == false)
    }

    /// Searching one anyway throws instead of returning an empty page ("no results" would mislead)
    @Test func repositoryWithoutSearchThrowsUnsupported() async {
        let repository = FakeBibleRepository()

        await #expect(throws: ScriptureSearchError.unsupportedTranslation) {
            try await repository.searchVerses("shepherd", translationID: 1234, cursor: nil)
        }
    }

    /// A result's chapter key is what BiblePassageStore loads to show its snippet
    @Test func resultPassageKeyIsItsChapter() {
        let result = ScriptureSearchResult(translationID: 111,
                                           bookCode: "PSA",
                                           chapter: 23,
                                           verseRange: 1...3,
                                           snippet: nil)

        #expect(result.passageKey == BiblePassageKey(translationID: 111, bookCode: "PSA", chapter: 23))
    }
}
