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

    static let esvTranslation = Translation(
        id: 59,
        abbreviation: "ESV",
        title: "English Standard Version 2016",
        languageTag: "en",
        license: nil,
        promotionalText: nil,
        availableBookCodes: BookDefaults.defaultBooks.map { $0.code }
    )

    // MARK: Properties (Private)

    private let apiKey: String
    private let baseURL: URL
    private let urlSession: URLSession

    private static let logger = Logger(subsystem: "SwiftBible",
                                       category: "CrosswayBibleRepository")

    private static let books: [Book] = BookDefaults.defaultBooks

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
}
