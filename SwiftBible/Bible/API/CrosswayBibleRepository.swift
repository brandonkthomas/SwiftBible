//
//  CrosswayBibleRepository.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-05.
//

import Foundation
import OSLog

/// Responsible for the ESV translation from https://api.esv.org
///
/// Terms (https://api.esv.org): non-commercial use, "ESV" shown with the text, a link to
/// www.esv.org, and no more than 500 verses cached or stored locally.
final class CrosswayBibleRepository: BibleRepository {

    static let searchPageSize = 25

    nonisolated static let esvTranslationID: Int = 59

    static let esvTranslation = Translation(
        id: esvTranslationID, // from YouVersion Bible list
        abbreviation: "ESV",
        title: "English Standard Version",
        languageTag: "en",
        license: CrosswayBibleRepository.esvCopyrightNotice,
        promotionalText: nil,
        availableBookCodes: BookDefaults.defaultBooks.map { $0.code }
    )

    /// Standard notice from https://api.esv.org ("What is the standard copyright notice...")
    static let esvCopyrightNotice = """
        Scripture quotations are from the ESV® Bible (The Holy Bible, English Standard Version®), \
        © 2001 by Crossway, a publishing ministry of Good News Publishers. Used by permission. \
        All rights reserved. The ESV text may not be quoted in any publication made available to \
        the public by a Creative Commons license. The ESV may not be translated into any other language.
        """

    // MARK: Properties (Private)

    private let apiKey: String
    private let baseURL: URL
    private let urlSession: URLSession

    private static let logger = Logger(subsystem: "SwiftBible",
                                       category: "CrosswayBibleRepository")

    private static let books: [Book] = BookDefaults.defaultBooks

    /// From the ESV API terms at https://api.esv.org
    static let maximumCachedVerseCount = 500

    // MARK: Init

    init(apiKey: String,
         baseURL: URL,
         urlSession: URLSession) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    // MARK: Functions

    /// Return the hardcoded ESV translation (English only)
    func translations(languageTag: String? = "en") -> [Translation] {
        Self.logger.debug("ENTRY CrosswayBibleRepository.translations(languageTag: \(languageTag ?? "nil", privacy: .public)) -- NO URL")

        guard languageTag == "en" || languageTag == nil else {
            return []
        }

        return [Self.esvTranslation]
    }

    /// Load all available Books + Chapters for the ESV (uses defaults)
    ///
    /// Verses are omitted here
    func books(for translationID: Translation.ID) async throws -> [Book] {
        Self.logger.debug("ENTRY CrosswayBibleRepository.books(translationID: \(translationID, privacy: .public)) -- NO URL")

        guard translationID == Self.esvTranslation.id else {
            throw BibleRepositoryError.invalidTranslation
        }

        return Self.books
    }

    /// Load HTML passage content for a given ScriptureReference
    ///
    /// ScriptureReference
    ///  translationID: 59
    ///  passageID: JHN.3
    ///
    /// CrosswayBibleRepository builds:
    ///  /v3/passage/html/?q=John+3&...
    ///
    /// Crossway returns JSON; `passages[0]` becomes Passage.htmlContent
    func passage(for reference: ScriptureReference) async throws -> Passage {
        Self.logger.debug("ENTRY CrosswayBibleRepository.passage(reference.passageID: \(reference.passageID, privacy: .public)) -- /v3/passage/html/")

        guard reference.translationID == Self.esvTranslation.id else {
            throw BibleRepositoryError.invalidTranslation
        }

        let builtUrl = try passageUrl(for: reference)

        let data = try await HttpRequest.fetchData(url: builtUrl,
                                                   httpMethod: "GET",
                                                   headers: ["Authorization": "Token \(apiKey)"],
                                                   urlSession: urlSession)

        let passageResponse = try JSONDecoder().decode(CrosswayPassageResponse.self,
                                                       from: data)

        guard let htmlContent = passageResponse.passages.first,
              !htmlContent.isEmpty else {
            throw BibleRepositoryError.responseParsingError
        }

        return try Passage(id: reference.passageID,
                           reference: Self.passageDisplayName(for: reference),
                           htmlContent: htmlContent)
    }

    /// Crossway HTML needs its own XMLParser delegate
    func renderedPassage(from passage: Passage,
                         translationID: Translation.ID) throws -> RenderedPassage {
        try CrosswayPassageParser().parse(html: passage.htmlContent)
    }

    /// ESV terms: "You may not locally store more than 500 verses", "You can cache up to 500 verses"
    ///
    /// Stored on disk, so ESV survives relaunches; whole chapters are dropped once the
    /// cached ESV verses add up to more than 500
    func passageCachePolicy(for translationID: Translation.ID) -> PassageCachePolicy {
        .diskLimited(maximumVerseCount: Self.maximumCachedVerseCount)
    }

    // MARK: Functions (Local)

    /// Build full request URL for Passage request
    /// Internal (no modifier) so tests can call it via @testable import
    func passageUrl(for reference: ScriptureReference) throws -> URL {
        let passagePath = baseURL.appending(path: "v3/passage/html/")

        guard var components = URLComponents(url: passagePath,
                                             resolvingAgainstBaseURL: false) else {
            throw BibleRepositoryError.internalError("Unable to create passage request URL")
        }

        // Headings and the "(ESV)" line are dropped: the parser skips headings, and the
        // Reader already shows the ESV abbreviation with the text
        components.queryItems = try [
            URLQueryItem(name: "q", value: Self.passageDisplayName(for: reference)),
            URLQueryItem(name: "include-passage-references", value: "false"),
            URLQueryItem(name: "include-headings", value: "false"),
            URLQueryItem(name: "include-short-copyright", value: "false"),
            URLQueryItem(name: "include-audio-link", value: "false")
        ]

        guard let builtUrl = components.url else {
            throw BibleRepositoryError.invalidRequestURL
        }

        return builtUrl
    }

    /// Crossway ESV supports search
    func supportsSearch(translationID: Translation.ID) -> Bool {
        translationID == Self.esvTranslationID
    }

    /// API verse search implementation
    ///
    /// exactText is ignored: the ESV API never corrects spelling
    func searchVerses(_ query: String,
                      translationID: Translation.ID,
                      cursor: ScriptureSearchCursor?,
                      exactText: Bool) async throws -> ScriptureSearchPage {
        Self.logger.debug("ENTRY CrosswayBibleRepository.searchVerses(query: \(query, privacy: .public)) -- /v3/passage/search")

        // sanity check
        if !supportsSearch(translationID: translationID) {
            throw ScriptureSearchError.unsupportedTranslation
        }

        // obtain URL
        let url = try searchVersesUrl(for: query,
                                      cursor: cursor)

        // make request
        let data = try await HttpRequest.fetchData(url: url,
                                                   httpMethod: "GET",
                                                   headers: ["Authorization": "Token \(apiKey)"],
                                                   urlSession: urlSession)

        // decode into YouVersionSearchVersesResponse
        let jsonDecoder = JSONDecoder()
        let searchResponse = try jsonDecoder.decode(CrosswaySearchResponse.self,
                                                    from: data)

        // build ScriptureSearchPage from YouVersionSearchVersesResponse
        return searchResponse.searchPage()
    }

    // MARK: Functions (Private Helpers)

    /// "John 3"; also the q param, which the ESV API parses as a reference
    private static func passageDisplayName(for reference: ScriptureReference) throws -> String {
        let bookDisplayName = Self.books
            .first { $0.code == reference.bookCode }?
            .displayName

        guard let bookDisplayName else {
            throw BibleRepositoryError.invalidBook
        }

        return "\(bookDisplayName) \(reference.chapter)"
    }

    // Internal for unit tests
    internal func searchVersesUrl(for query: String,
                                  cursor: ScriptureSearchCursor?) throws -> URL {
        // build base URL
        let searchPath = baseURL.appending(path: "v3/passage/search/")

        guard var components = URLComponents(url: searchPath,
                                             resolvingAgainstBaseURL: false) else {
            throw BibleRepositoryError.internalError("Unable to create search request URL")
        }

        // clean user search query
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAndShortenedQuery = String(trimmedQuery.prefix(100))

        // build URL query
        components.queryItems = [
            URLQueryItem(name: "q",
                         value: trimmedAndShortenedQuery),
            URLQueryItem(name: "page-size",
                         value: Self.searchPageSize.description)
        ]
        if case .pageNumber(let pageNumber) = cursor { // dont need pageToken (YouVersion exclusive)
            components.queryItems?.append(URLQueryItem(name: "page",
                                                       value: pageNumber.description))
        }

        guard let builtUrl = components.url else {
            throw BibleRepositoryError.invalidRequestURL
        }

        return builtUrl
    }
}
