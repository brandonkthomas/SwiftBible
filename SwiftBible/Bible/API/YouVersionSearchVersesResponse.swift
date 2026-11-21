//
//  YouVersionSearchVersesResponse.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-20.
//

import Foundation

/// Maps to "~/v1/search-verses?query={}&bible_id={}"
/// Optional params: user_intent, page_size, page_token
///
/// TODO: this does NOT return passage text; need separate requests for each result :(
///
/// See https://developers.youversion.com/search-apis#get-v1search-verses
///
/// Returns:
/// {
///   "verses": [
///       { "reference": "JHN.3.16" },
///       { "reference": "1JN.4.8" }
///   ],
///   "user_intent": "text",
///   "did_you_mean": [],
///   "search_instead_for": null,
///   "next_page_token": "example-page-token"
/// }
nonisolated struct YouVersionSearchVersesResponse: Decodable {
    let verses: [YouVersionSearchVerseResponse]
    let userIntent: YouVersionSearchVerseUserIntentResponse?
    let didYouMean: [String]
    let searchInsteadFor: String?
    let nextPageToken: String?

    // aliases for JSONDecoder
    enum CodingKeys: String, CodingKey {
        case verses
        case userIntent = "user_intent"
        case didYouMean = "did_you_mean"
        case searchInsteadFor = "search_instead_for"
        case nextPageToken = "next_page_token"
    }

    /// Map search results to our ScriptureSearchPage
    func searchPage(translationID: Translation.ID) -> ScriptureSearchPage {
        var results: [ScriptureSearchResult] = []

        // Loop over + map results
        for reference in self.verses.map(\.reference) {
            let components = reference.components(separatedBy: ".")

            guard components.count == 3,
                  let chapter = Int(components[1]),
                  let verse = Int(components[2]) else {
                continue
            }

            results.append(ScriptureSearchResult(
                translationID: translationID,
                bookCode: components[0],
                chapter: chapter,
                verseRange: verse...verse,
                snippet: nil
            ))
        }

        // TODO: loop again to consolidate immediately-adjacent verse ranges in same book/chapter
        // into one result

        // Return final listing
        if let nextPageToken {
            return ScriptureSearchPage(results: results,
                                       nextCursor: .pageToken(nextPageToken),
                                       suggestions: didYouMean,
                                       searchedInsteadFor: searchInsteadFor,
                                       intent: userIntent?.searchIntent ?? .unknown)
        } else {
            return ScriptureSearchPage(results: results,
                                       nextCursor: nil,
                                       suggestions: didYouMean,
                                       searchedInsteadFor: searchInsteadFor,
                                       intent: userIntent?.searchIntent ?? .unknown)
        }
    }
}

/// Verse reference response param -- see YouVersionSearchVersesResponse
nonisolated struct YouVersionSearchVerseResponse: Decodable {
    let reference: String
}

/// User search-query intent response param -- see YouVersionSearchVersesResponse
///
/// Keep in sync w/ ScriptureSearchIntent
nonisolated enum YouVersionSearchVerseUserIntentResponse: String, Decodable {
    /// default
    case unknown
    /// i.e. love your enemies
    case text
    /// i.e. anxiety, forgiveness
    case topical
    /// i.e. John 3:16
    case reference

    /// Failsafe to prevent API changes from breaking the response (fallback to unknown)
    init(from decoder: any Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = YouVersionSearchVerseUserIntentResponse(rawValue: rawValue) ?? .unknown
    }

    /// Map to our domain ScriptureSearchIntent
    var searchIntent: ScriptureSearchIntent {
        switch self {
        case .unknown: .unknown
        case .text: .text
        case .topical: .topical
        case .reference: .reference
        }
    }
}
