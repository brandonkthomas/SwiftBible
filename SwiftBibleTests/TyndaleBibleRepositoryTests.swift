//
//  TyndaleBibleRepositoryTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-04.
//

import Foundation
import Testing
@testable import SwiftBible

@MainActor
struct TyndaleBibleRepositoryTests {

    private let nltID = TyndaleBibleRepository.nltTranslation.id
    private let unknownID = 3034

    // MARK: Passage URL

    @Test(arguments: [
        (TyndaleBibleRepository.nltTranslation.id, "NLT"),
        (TyndaleBibleRepository.kjvTranslation.id, "KJV")
    ])
    func translationIDBuildsMatchingVersion(translationID: Translation.ID, expectedVersion: String) throws {
        let reference = try makeReference(translationID: translationID, bookCode: "JHN", chapter: 3)

        let url = try makeRepository().passageUrl(for: reference)

        #expect(try queryValue("version", in: url) == expectedVersion)
    }

    @Test func johnBuildsRefParam() throws {
        let reference = try makeReference(translationID: nltID, bookCode: "JHN", chapter: 3)

        let url = try makeRepository().passageUrl(for: reference)

        #expect(try queryValue("ref", in: url) == "John.3")
    }

    /// "1 Samuel" contains a space, so the ref must be percent-encoded in the URL
    @Test func firstSamuelBuildsEncodedRefParam() throws {
        let reference = try makeReference(translationID: nltID, bookCode: "1SA", chapter: 1)

        let url = try makeRepository().passageUrl(for: reference)

        #expect(try queryValue("ref", in: url) == "1 Samuel.1")
        #expect(url.absoluteString.contains("ref=1%20Samuel.1"))
    }

    @Test func unknownTranslationIDThrowsInvalidTranslation() throws {
        let reference = try makeReference(translationID: unknownID, bookCode: "JHN", chapter: 3)

        let error = #expect(throws: BibleRepositoryError.self) {
            try makeRepository().passageUrl(for: reference)
        }

        guard case .invalidTranslation = error else {
            Issue.record("Expected invalidTranslation, got \(String(describing: error))")
            return
        }
    }

    @Test func unknownBookCodeThrowsInvalidBook() throws {
        let reference = try makeReference(translationID: nltID, bookCode: "XYZ", chapter: 1)

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
    func englishOrNilLanguageTagReturnsBothTranslations(languageTag: String?) throws {
        let translations = try makeRepository().translations(languageTag: languageTag)

        #expect(translations == [TyndaleBibleRepository.nltTranslation,
                                 TyndaleBibleRepository.kjvTranslation])
    }

    @Test func nonEnglishLanguageTagReturnsEmpty() throws {
        #expect(try makeRepository().translations(languageTag: "es").isEmpty)
    }

    // MARK: Books

    @Test(arguments: [
        TyndaleBibleRepository.nltTranslation.id,
        TyndaleBibleRepository.kjvTranslation.id
    ])
    func booksReturnsFullCanon(translationID: Translation.ID) async throws {
        let books = try await makeRepository().books(for: translationID)

        #expect(books.count == 66)
    }

    // MARK: Live

//    /// Hits https://api.nlt.to over the network
//    @Test func liveJohn3WithTestKey() async throws {
//        let repository = try makeRepository(apiKey: "TEST")
//        let reference = try makeReference(translationID: nltID, bookCode: "JHN", chapter: 3)
//
//        let passage = try await repository.passage(for: reference)
//
//        #expect(passage.id == "JHN.3")
//        #expect(passage.reference == "John 3")
//        #expect(!passage.htmlContent.isEmpty)
//    }

    // MARK: Functions (Private Helpers)

    private func makeRepository(apiKey: String = "KEY") throws -> TyndaleBibleRepository {
        TyndaleBibleRepository(apiKey: apiKey,
                               baseURL: try #require(URL(string: "https://api.nlt.to")),
                               urlSession: .shared)
    }

    private func makeReference(translationID: Translation.ID,
                               bookCode: String,
                               chapter: Int) throws -> ScriptureReference {
        try #require(ScriptureReference(translationID: translationID, bookCode: bookCode, chapter: chapter))
    }

    private func queryValue(_ name: String, in url: URL) throws -> String? {
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        return components.queryItems?.first { $0.name == name }?.value
    }
}
