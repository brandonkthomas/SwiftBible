//
//  YouVersionSearchRequestTests.swift
//  SwiftBibleTests
//

import Foundation
import Testing
@testable import SwiftBible

/// Search step 2b: the GET /v1/search-verses request URL
///
/// The app key goes in the X-YVP-App-Key header (same as the other YouVersion calls), never in
/// the URL. Live call 2026-11-20: page 2 came back when page_token was passed with the same
/// query and bible_id.
@MainActor
struct YouVersionSearchRequestTests {

    /// First page: search-verses path, the query, the translation, and the app's page size
    @Test func firstPageBuildsPathAndQuery() throws {
        let url = try makeRepository().searchVersesUrl(for: "love is patient",
                                                       translationID: 111,
                                                       cursor: nil)

        #expect(url.path() == "/v1/search-verses")
        #expect(try queryValue("query", in: url) == "love is patient")
        #expect(try queryValue("bible_id", in: url) == "111")
        #expect(try queryValue("page_size", in: url) == String(YouVersionBibleRepository.searchPageSize))
        #expect(try queryValue("page_token", in: url) == nil)
        #expect(try queryValue("user_intent", in: url) == nil)
    }

    /// Exact text adds user_intent=text, which turns off YouVersion's spelling correction
    /// (probe 2026-11-21: quotes didn't; user_intent=text did)
    @Test func exactTextAddsTextIntent() throws {
        let url = try makeRepository().searchVersesUrl(for: "sheperd",
                                                       translationID: 1849,
                                                       cursor: nil,
                                                       exactText: true)

        #expect(try queryValue("user_intent", in: url) == "text")
        #expect(try queryValue("query", in: url) == "sheperd")
    }

    /// Later pages repeat the query and translation and add the token from the previous page
    @Test func nextPageAddsPageToken() throws {
        let token = "gAAAAABrAHFx-_token="

        let url = try makeRepository().searchVersesUrl(for: "shepherd",
                                                       translationID: 111,
                                                       cursor: .pageToken(token))

        #expect(try queryValue("page_token", in: url) == token)
        #expect(try queryValue("query", in: url) == "shepherd")
        #expect(try queryValue("bible_id", in: url) == "111")
    }

    /// The API accepts 1-100 characters; surrounding spaces are dropped and a longer query is cut
    @Test func queryIsTrimmedAndCutToApiLimit() throws {
        let longQuery = "  " + String(repeating: "a", count: 150) + "  "

        let url = try makeRepository().searchVersesUrl(for: longQuery,
                                                       translationID: 111,
                                                       cursor: nil)

        #expect(try queryValue("query", in: url) == String(repeating: "a", count: 100))
    }

    // MARK: Helpers

    private func makeRepository() throws -> YouVersionBibleRepository {
        YouVersionBibleRepository(apiKey: "KEY",
                                  baseURL: try #require(URL(string: "https://api.youversion.com")),
                                  urlSession: .shared)
    }

    private func queryValue(_ name: String, in url: URL) throws -> String? {
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        return components.queryItems?.first { $0.name == name }?.value
    }
}
