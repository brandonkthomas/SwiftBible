//
//  CrosswaySearchResponseTests.swift
//  SwiftBibleTests
//

import Foundation
import Testing
@testable import SwiftBible

/// Search step 3a: GET /v3/passage/search/ response -> ScriptureSearchPage
///
/// Fixtures follow live responses (2026-11-21):
/// - results come in Bible order (not ranked), one verse each, with the verse text in `content`
/// - paging is by page number: `page` and `total_pages` (total_pages is 1 even with no results)
/// - book names differ from the app's in two places: "Psalm" (app: "Psalms") and
///   "Song of Solomon" (app: "Song of Songs")
/// - single-chapter books leave out the chapter: "Jude 3" is Jude 1:3, "2 John 1" is 2 John 1:1
@MainActor
struct CrosswaySearchResponseTests {

    private let esvID = CrosswayBibleRepository.esvTranslation.id

    /// References become one-verse ESV results with their text as the snippet; more pages -> next page
    @Test func resultsKeepTextAndPointToNextPage() throws {
        let json = """
            {
                "page": 1,
                "total_results": 61,
                "results": [
                    { "reference": "Genesis 48:15", "content": "the God who has been my shepherd all my life long to this day," },
                    { "reference": "1 Samuel 17:40", "content": "put them in his shepherd\\u2019s pouch." }
                ],
                "total_pages": 21
            }
            """

        let page = try decode(json).searchPage()

        #expect(page == ScriptureSearchPage(
            results: [
                ScriptureSearchResult(translationID: esvID, bookCode: "GEN", chapter: 48, verseRange: 15...15,
                                      snippet: "the God who has been my shepherd all my life long to this day,"),
                ScriptureSearchResult(translationID: esvID, bookCode: "1SA", chapter: 17, verseRange: 40...40,
                                      snippet: "put them in his shepherd\u{2019}s pouch.")
            ],
            nextCursor: .pageNumber(2)
        ))
    }

    /// The last page (and an empty search, which still says total_pages 1) has no cursor
    @Test func lastPageHasNoCursor() throws {
        let json = """
            { "page": 1, "total_results": 0, "results": [], "total_pages": 1 }
            """

        let page = try decode(json).searchPage()

        #expect(page == ScriptureSearchPage(results: [], nextCursor: nil))
    }

    /// ESV's book names map to the app's book codes, including the two that differ and the
    /// single-chapter form
    @Test(arguments: [
        ("Psalm 23:1", "PSA", 23, 1),
        ("Song of Solomon 2:1", "SNG", 2, 1),
        ("1 Samuel 17:40", "1SA", 17, 40),
        ("Jude 3", "JUD", 1, 3),
        ("2 John 1", "2JN", 1, 1)
    ])
    func referenceMapsToBookChapterAndVerse(reference: String, bookCode: String, chapter: Int, verse: Int) throws {
        let json = """
            {
                "page": 1,
                "total_results": 1,
                "results": [{ "reference": "\(reference)", "content": "text" }],
                "total_pages": 1
            }
            """

        let result = try #require(try decode(json).searchPage().results.first)

        #expect(result.bookCode == bookCode)
        #expect(result.chapter == chapter)
        #expect(result.verseRange == verse...verse)
    }

    /// A reference the app can't place is skipped instead of failing the whole page
    @Test func unknownReferenceIsSkipped() throws {
        let json = """
            {
                "page": 1,
                "total_results": 3,
                "results": [
                    { "reference": "Hezekiah 1:1", "content": "unknown book" },
                    { "reference": "Genesis", "content": "no numbers" },
                    { "reference": "Acts 17:5", "content": "the rabble" }
                ],
                "total_pages": 1
            }
            """

        let page = try decode(json).searchPage()

        #expect(page.results.map(\.passageKey) == [
            BiblePassageKey(translationID: esvID, bookCode: "ACT", chapter: 17)
        ])
    }

    // MARK: Helpers

    private func decode(_ json: String) throws -> CrosswaySearchResponse {
        try JSONDecoder().decode(CrosswaySearchResponse.self, from: Data(json.utf8))
    }
}
