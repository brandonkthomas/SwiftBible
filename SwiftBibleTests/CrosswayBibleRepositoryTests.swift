//
//  CrosswayBibleRepositoryTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-05.
//

import Foundation
import Testing
@testable import SwiftBible

@MainActor
struct CrosswayBibleRepositoryTests {

    private let esvID = CrosswayBibleRepository.esvTranslation.id
    private let unknownID = 3034

    // MARK: Passage URL

    @Test func johnBuildsPassagePathAndQuery() throws {
        let reference = try makeReference(bookCode: "JHN", chapter: 3)

        let url = try makeRepository().passageUrl(for: reference)

        #expect(url.path() == "/v3/passage/html/")
        #expect(try queryValue("q", in: url) == "John 3")
    }

    /// Headings, the "(ESV)" line, and the audio link are not requested
    @Test(arguments: [
        "include-passage-references",
        "include-headings",
        "include-short-copyright",
        "include-audio-link"
    ])
    func optionalContentIsTurnedOff(parameterName: String) throws {
        let reference = try makeReference(bookCode: "JHN", chapter: 3)

        let url = try makeRepository().passageUrl(for: reference)

        #expect(try queryValue(parameterName, in: url) == "false")
    }

    /// "1 Samuel" contains a space, so the q param must be percent-encoded in the URL
    @Test func firstSamuelBuildsEncodedQuery() throws {
        let reference = try makeReference(bookCode: "1SA", chapter: 1)

        let url = try makeRepository().passageUrl(for: reference)

        #expect(try queryValue("q", in: url) == "1 Samuel 1")
        #expect(url.absoluteString.contains("q=1%20Samuel%201"))
    }

    @Test func unknownBookCodeThrowsInvalidBook() throws {
        let reference = try makeReference(bookCode: "XYZ", chapter: 1)

        let error = #expect(throws: BibleRepositoryError.self) {
            try makeRepository().passageUrl(for: reference)
        }

        guard case .invalidBook = error else {
            Issue.record("Expected invalidBook, got \(String(describing: error))")
            return
        }
    }

    // MARK: Translations

    @Test(arguments: ["en", nil] as [String?])
    func englishOrNilLanguageTagReturnsESV(languageTag: String?) throws {
        let translations = try makeRepository().translations(languageTag: languageTag)

        #expect(translations.map(\.id) == [esvID])
    }

    @Test func nonEnglishLanguageTagReturnsEmpty() throws {
        #expect(try makeRepository().translations(languageTag: "es").isEmpty)
    }

    // MARK: Books

    @Test func booksReturnsFullCanon() async throws {
        let books = try await makeRepository().books(for: esvID)

        #expect(books.count == 66)
    }

    @Test func booksForUnknownTranslationThrows() async throws {
        await #expect(throws: BibleRepositoryError.self) {
            try await makeRepository().books(for: unknownID)
        }
    }

    // MARK: Rendered Passage

    /// PassageHTMLParser would fail on ESV's &nbsp; entities
    @Test func renderedPassageUsesCrosswayParser() throws {
        let passage = Passage(id: "JHN.3",
                              reference: "John 3",
                              htmlContent: #"<p><b class="chapter-num" id="v43003001-1">3:1&nbsp;</b>Alpha text.</p>"#)

        let renderedPassage = try makeRepository().renderedPassage(from: passage, translationID: esvID)

        #expect(renderedPassage.paragraphs.first?.runs == [
            .verseLabel(displayText: "1", verseRange: .init(startVerse: 1)),
            .text("Alpha text.", verseRange: .init(startVerse: 1))
        ])
    }

    // MARK: Functions (Private Helpers)

    private func makeRepository(apiKey: String = "KEY") throws -> CrosswayBibleRepository {
        CrosswayBibleRepository(apiKey: apiKey,
                                baseURL: try #require(URL(string: "https://api.esv.org")),
                                urlSession: .shared)
    }

    private func makeReference(bookCode: String,
                               chapter: Int) throws -> ScriptureReference {
        try #require(ScriptureReference(translationID: esvID, bookCode: bookCode, chapter: chapter))
    }

    private func queryValue(_ name: String, in url: URL) throws -> String? {
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        return components.queryItems?.first { $0.name == name }?.value
    }
}
