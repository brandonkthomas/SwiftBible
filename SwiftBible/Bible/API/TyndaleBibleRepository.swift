//
//  TyndaleBibleRepository.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-04.
//

import Foundation
import OSLog

/// Responsible for NLT and KJV translations from https://api.nlt.to
final class TyndaleBibleRepository: BibleRepository {

    static let nltTranslation = Translation(
        id: 116,
        abbreviation: "NLT",
        title: "New Living Translation",
        languageTag: "en",
        license: nil,
        promotionalText: nil,
        availableBookCodes: BookDefaults.defaultBooks.map { $0.code }
    )

    static let kjvTranslation = Translation(
        id: 1,
        abbreviation: "KJV",
        title: "King James Version",
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
                                       category: "TyndaleBibleRepository")

    private static let translations: [Translation] = [
        nltTranslation,
        kjvTranslation
    ]

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

    /// Return hardcoded NLT and KJV translations (English only)
    func translations(languageTag: String? = "en") -> [Translation] {
        Self.logger.debug("ENTRY TyndaleBibleRepository.translations(languageTag: \(languageTag ?? "nil", privacy: .public)) -- NO URL")

        // Tyndale only supports English
        guard languageTag == "en" || languageTag == nil else {
            return []
        }

        // Return hardcoded translations supported by this API
        // (they dont have an endpoint for this)
        return Self.translations
    }

    /// Load all available Books + Chapters for either NLT or KJV (both use defaults)
    ///
    /// Verses are omitted here
    func books(for translationID: Translation.ID) async throws -> [Book] {
        Self.logger.debug("ENTRY TyndaleBibleRepository.books(translationID: \(translationID, privacy: .public)) -- NO URL")

        // if not NLT nor KJV, throw
        if translationID != Self.nltTranslation.id,
           translationID != Self.kjvTranslation.id {
            throw BibleRepositoryError.invalidTranslation
        }

        return Self.books
    }

    /// Load HTML passage content for a given ScriptureReference
    ///
    /// ScriptureReference
    ///  translationID: 116
    ///  passageID: JHN.1
    ///
    /// TyndaleBibleRepository builds:
    ///  /api/passages?key=XXX&ref=John.1&version=NLT
    ///
    /// Tyndale returns:
    ///  Passage(id: "JHN.1", reference: "John 1", htmlContent: "<div>...</div>")
    func passage(for reference: ScriptureReference) async throws -> Passage {
        Self.logger.debug("ENTRY TyndaleBibleRepository.passage(reference.passageID: \(reference.passageID, privacy: .public)) -- /api/passages")

        let builtUrl = try passageUrl(for: reference)

        // Finally, make the request
        let data = try await HttpRequest.fetchData(url: builtUrl,
                                                   httpMethod: "GET",
                                                   headers: [:],
                                                   urlSession: urlSession)

        // data parses, is non-nil, and is non-empty
        guard let dataString = String(data: data, encoding: .utf8),
              !dataString.isEmpty else {
            throw BibleRepositoryError.responseParsingError
        }

        return try Passage(id: reference.passageID,
                           reference: Self.passageDisplayName(for: reference),
                           htmlContent: dataString)
    }

    // MARK: Functions (Local)

    /// Build full request URL for Passage request
    /// Internal (no modifier) so tests can call it via @testable import
    func passageUrl(for reference: ScriptureReference) throws -> URL {
        // API path
        let passagePath = baseURL.appending(path: "api/passages")

        guard var components = URLComponents(url: passagePath,
                                             resolvingAgainstBaseURL: false) else {
            throw BibleRepositoryError.internalError("Unable to create passage request URL")
        }

        // Query items (key, ref, version)
        components.queryItems = try [
            URLQueryItem(name: "key",
                         value: apiKey),
            URLQueryItem(name: "ref",
                         value: Self.passageRefParam(for: reference)),
            URLQueryItem(name: "version",
                         value: Self.passageTranslationAbbreviation(for: reference))
        ]

        guard let builtUrl = components.url else {
            throw BibleRepositoryError.invalidRequestURL
        }

        return builtUrl
    }

    // MARK: Functions (Private Helpers)

    private static func passageTranslationAbbreviation(for reference: ScriptureReference) throws -> String {
        let translationAbbreviation = Self.translations
            .first { $0.id == reference.translationID }?
            .abbreviation

        guard let translationAbbreviation else {
            throw BibleRepositoryError.invalidTranslation
        }

        return translationAbbreviation
    }

    private static func passageBookDisplayName(for reference: ScriptureReference) throws -> String {
        let bookDisplayName = Self.books
            .first { $0.code == reference.bookCode }?
            .displayName

        guard let bookDisplayName else {
            throw BibleRepositoryError.invalidBook
        }

        return bookDisplayName
    }

    private static func passageRefParam(for reference: ScriptureReference) throws -> String {
        return try "\(passageBookDisplayName(for: reference)).\(reference.chapter)"
    }

    private static func passageDisplayName(for reference: ScriptureReference) throws -> String {
        return try "\(passageBookDisplayName(for: reference)) \(reference.chapter)"
    }
}
