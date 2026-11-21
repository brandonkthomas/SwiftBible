//
//  YouVersionSearchVersesResponseTests.swift
//  SwiftBibleTests
//

import Foundation
import Testing
@testable import SwiftBible

/// Search step 2: GET /v1/search-verses response -> ScriptureSearchPage
///
/// Fixtures match live responses (2026-11-20, bible_id 111): every reference was one verse
/// ("PSA.23.1"; no ranges seen), user_intent can be null, and next_page_token is null on the
/// last page. Responses never include verse text, so snippets start out nil.
@MainActor
struct YouVersionSearchVersesResponseTests {

    /// References become one-verse results in the searched translation; the token becomes the cursor
    @Test func referencesBecomeResultsAndTokenBecomesCursor() throws {
        let json = """
            {
                "verses": [{ "reference": "PSA.23.1" }, { "reference": "1JN.3.16" }],
                "user_intent": "topical",
                "did_you_mean": [],
                "search_instead_for": null,
                "next_page_token": "token-2"
            }
            """

        let page = try decode(json).searchPage(translationID: 111)

        #expect(page == ScriptureSearchPage(
            results: [
                ScriptureSearchResult(translationID: 111, bookCode: "PSA", chapter: 23, verseRange: 1...1, snippet: nil),
                ScriptureSearchResult(translationID: 111, bookCode: "1JN", chapter: 3, verseRange: 16...16, snippet: nil)
            ],
            nextCursor: .pageToken("token-2"),
            intent: .topical
        ))
    }

    /// The last page (and an empty search) has no cursor
    @Test func lastPageHasNoCursor() throws {
        let json = """
            {
                "verses": [],
                "user_intent": null,
                "did_you_mean": [],
                "search_instead_for": null,
                "next_page_token": null
            }
            """

        let page = try decode(json).searchPage(translationID: 111)

        #expect(page == ScriptureSearchPage(results: [], nextCursor: nil))
    }

    /// A reference that isn't BOOK.CHAPTER.VERSE is skipped instead of failing the whole page
    @Test func malformedReferenceIsSkipped() throws {
        let json = """
            {
                "verses": [{ "reference": "PSA.23" }, { "reference": "PSA.x.1" }, { "reference": "JHN.3.16" }],
                "user_intent": "text",
                "did_you_mean": [],
                "search_instead_for": null,
                "next_page_token": null
            }
            """

        let page = try decode(json).searchPage(translationID: 111)

        #expect(page.results.map(\.passageKey) == [
            BiblePassageKey(translationID: 111, bookCode: "JHN", chapter: 3)
        ])
    }

    // MARK: Step 2c: suggestions, corrections, intent

    /// did_you_mean becomes suggestions the UI can offer as "Did you mean ...?"
    @Test func didYouMeanBecomesSuggestions() throws {
        let json = """
            {
                "verses": [],
                "user_intent": "text",
                "did_you_mean": ["shepherd", "shepherds"],
                "search_instead_for": null,
                "next_page_token": null
            }
            """

        let page = try decode(json).searchPage(translationID: 111)

        #expect(page.suggestions == ["shepherd", "shepherds"])
        #expect(page.searchedInsteadFor == nil)
    }

    /// search_instead_for means the results are for a corrected query ("Showing results for ...")
    @Test func searchInsteadForIsCarried() throws {
        let json = """
            {
                "verses": [{ "reference": "PSA.23.1" }],
                "user_intent": "text",
                "did_you_mean": [],
                "search_instead_for": "shepherd",
                "next_page_token": null
            }
            """

        let page = try decode(json).searchPage(translationID: 111)

        #expect(page.searchedInsteadFor == "shepherd")
        #expect(page.suggestions.isEmpty)
    }

    /// Every YouVersion intent maps to the app's own type; null and new values become .unknown
    @Test(arguments: [
        ("\"reference\"", ScriptureSearchIntent.reference),
        ("\"topical\"", .topical),
        ("\"text\"", .text),
        ("null", .unknown),
        ("\"something_new\"", .unknown)
    ])
    func intentIsMapped(jsonValue: String, expected: ScriptureSearchIntent) throws {
        let json = """
            {
                "verses": [],
                "user_intent": \(jsonValue),
                "did_you_mean": [],
                "search_instead_for": null,
                "next_page_token": null
            }
            """

        let page = try decode(json).searchPage(translationID: 111)

        #expect(page.intent == expected)
    }

    // MARK: Helpers

    private func decode(_ json: String) throws -> YouVersionSearchVersesResponse {
        try JSONDecoder().decode(YouVersionSearchVersesResponse.self, from: Data(json.utf8))
    }
}
