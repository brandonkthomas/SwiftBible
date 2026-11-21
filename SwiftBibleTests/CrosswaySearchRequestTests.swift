//
//  CrosswaySearchRequestTests.swift
//  SwiftBibleTests
//

import Foundation
import Testing
@testable import SwiftBible

/// Search step 3b: the GET /v3/passage/search/ request, and search being ESV-only
///
/// The key goes in the Authorization header (same as passage requests), never in the URL.
/// Live calls 2026-11-21: `page=2` with the same `q` and `page-size` returned the next results.
@MainActor
struct CrosswaySearchRequestTests {

    private let esvID = CrosswayBibleRepository.esvTranslation.id

    /// First page: search path, the query, the app's page size, and no page number
    @Test func firstPageBuildsPathAndQuery() throws {
        let url = try makeRepository().searchVersesUrl(for: "love is patient", cursor: nil)

        #expect(url.path() == "/v3/passage/search/")
        #expect(try queryValue("q", in: url) == "love is patient")
        #expect(try queryValue("page-size", in: url) == String(CrosswayBibleRepository.searchPageSize))
        #expect(try queryValue("page", in: url) == nil)
    }

    /// Later pages add the page number; a YouVersion token means nothing to ESV and is ignored
    @Test func pageNumberIsAddedAndTokenIgnored() throws {
        let repository = try makeRepository()

        let numberedUrl = try repository.searchVersesUrl(for: "shepherd", cursor: .pageNumber(3))
        let tokenUrl = try repository.searchVersesUrl(for: "shepherd", cursor: .pageToken("token"))

        #expect(try queryValue("page", in: numberedUrl) == "3")
        #expect(try queryValue("page", in: tokenUrl) == nil)
    }

    /// Surrounding spaces and line breaks are dropped
    @Test func queryIsTrimmed() throws {
        let url = try makeRepository().searchVersesUrl(for: "  shepherd \n", cursor: nil)

        #expect(try queryValue("q", in: url) == "shepherd")
    }

    /// The ESV API searches only the ESV
    @Test func searchIsSupportedOnlyForESV() throws {
        let repository = try makeRepository()

        #expect(repository.supportsSearch(translationID: esvID))
        #expect(repository.supportsSearch(translationID: 111) == false)
    }

    /// Asking ESV to search another translation fails before any request is made
    @Test func searchingAnotherTranslationThrowsUnsupported() async throws {
        let repository = try makeRepository()

        await #expect(throws: ScriptureSearchError.unsupportedTranslation) {
            try await repository.searchVerses("shepherd", translationID: 111, cursor: nil)
        }
    }

    // MARK: Helpers

    private func makeRepository() throws -> CrosswayBibleRepository {
        CrosswayBibleRepository(apiKey: "KEY",
                                baseURL: try #require(URL(string: "https://api.esv.org")),
                                urlSession: .shared)
    }

    private func queryValue(_ name: String, in url: URL) throws -> String? {
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        return components.queryItems?.first { $0.name == name }?.value
    }
}
