//
//  YouVersionBibleRepository.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/28/26.
//

import Foundation
import OSLog

final class YouVersionBibleRepository: BibleRepository {

    static let searchPageSize = 25

    // MARK: Properties (Private)

    private let apiKey: String
    private let baseURL: URL
    private let urlSession: URLSession

    private static let logger = Logger(subsystem: "SwiftBible", category: "YouVersionBibleRepository")

    init(apiKey: String,
         baseURL: URL,
         urlSession: URLSession) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    // MARK: Functions

    /// Load all available Translations
    ///
    /// nil languageTag will not pass the filter
    func translations(languageTag: String? = "en") async throws -> [Translation] {
        Self.logger.debug("ENTRY YouVersionBibleRepository.translations(languageTag: \(languageTag ?? "nil", privacy: .public)) -- /v1/bibles")

        let bibleCollectionPath = baseURL.appending(path: "v1/bibles")

        guard var components = URLComponents(url: bibleCollectionPath,
                                             resolvingAgainstBaseURL: false) else {
            throw BibleRepositoryError.internalError("Unable to create translation request URL")
        }

        var items: [URLQueryItem] = []

        if let languageTag {
            items.append(URLQueryItem(name: "language_ranges[]",
                                      value: languageTag))
            components.queryItems = items
        }

        guard let builtUrl = components.url else {
            throw BibleRepositoryError.invalidRequestURL
        }

        // no need to wrap so ReaderStore can handle failures directly
        let data = try await HttpRequest.fetchData(url: builtUrl,
                                                   httpMethod: "GET",
                                                   headers: ["X-YVP-App-Key": apiKey],
                                                   urlSession: urlSession)

        let jsonDecoder = JSONDecoder()
        let collectionResponse = try jsonDecoder.decode(YouVersionBibleCollectionResponse.self,
                                                        from: data)

        var translations = collectionResponse.translationsForApp()

        // Manual cleanup -- unwanted English translations
        let unwantedTranslations = ["amp","bsb","cpdv","easy","fbv","gnv","lsv","nasb1995","nivuk","pev","tojb2011","tcent","webus","wmb","wmbbe"]
        translations.removeAll(where: { unwantedTranslations.contains($0.abbreviation.lowercased()) })

        // Manual cleanup -- NASB
        if let nasb2020Index = translations.firstIndex(where: { $0.abbreviation.lowercased() == "nasb2020" }) {
            let nasb2020Old = translations[nasb2020Index]
            let nasb2020New = Translation(
                id: nasb2020Old.id,
                abbreviation: nasb2020Old.abbreviation.replacing("2020", with: ""),
                title: nasb2020Old.title.replacing(" - NASB", with: ""),
                languageTag: nasb2020Old.languageTag,
                license: nasb2020Old.license,
                promotionalText: nasb2020Old.promotionalText,
                availableBookCodes: nasb2020Old.availableBookCodes
            )

            translations.remove(at: nasb2020Index)
            translations.append(nasb2020New)
        }

        // Manual cleanup -- TPT
        if let tptIndex = translations.firstIndex(where: {
            $0.abbreviation.lowercased() == "tpt"
            && $0.title.contains("(In Review)")
        }) {
            let tptOld = translations[tptIndex]
            let tptNew = Translation(
                id: tptOld.id,
                abbreviation: tptOld.abbreviation,
                title: tptOld.title.replacing(" (In Review)", with: ""),
                languageTag: tptOld.languageTag,
                license: tptOld.license,
                promotionalText: tptOld.promotionalText,
                availableBookCodes: tptOld.availableBookCodes
            )

            translations.remove(at: tptIndex)
            translations.append(tptNew)
        }

        return translations
    }

    /// Load translation details incl. copyright that the /v1/bibles list leaves out
    func translationDetail(for translationID: Translation.ID) async throws -> Translation? {
        Self.logger.debug("ENTRY YouVersionBibleRepository.translationDetail(translationID: \(translationID, privacy: .public)) -- /v1/bibles/:id")

        let data = try await HttpRequest.fetchData(url: translationDetailUrl(for: translationID),
                                                   httpMethod: "GET",
                                                   headers: ["X-YVP-App-Key": apiKey],
                                                   urlSession: urlSession)

        return try Self.translation(fromDetail: data)
    }

    internal func translationDetailUrl(for translationID: Translation.ID) -> URL {
        baseURL.appending(path: "v1/bibles/\(translationID)")
    }

    /// Decode /v1/bibles/{id} response
    internal static func translation(fromDetail data: Data) throws -> Translation {
        try JSONDecoder().decode(YouVersionBible.self, from: data).translationForApp()
    }

    /// Load all available Books + Chapters + Verses for a given Translation ID
    func books(for translationID: Translation.ID) async throws -> [Book] {
        Self.logger.debug("ENTRY YouVersionBibleRepository.books(translationID: \(translationID, privacy: .public)) -- /v1/bibles/:id/index")

        let bibleIndexPath = baseURL.appending(path: "v1/bibles/\(translationID)/index")

        // no need to wrap so ReaderStore can handle failures directly
        let data = try await HttpRequest.fetchData(url: bibleIndexPath,
                                                   httpMethod: "GET",
                                                   headers: ["X-YVP-App-Key": apiKey],
                                                   urlSession: urlSession)

        let jsonDecoder = JSONDecoder()
        let indexResponse = try jsonDecoder.decode(YouVersionBibleIndexResponse.self,
                                                        from: data)

        return indexResponse.booksForApp()
    }

    /// Load HTML passage content for a given ScriptureReference
    ///
    /// ScriptureReference
    ///  translationID: 1849
    ///  passageID: JHN.1
    ///
    /// YouVersionBibleRepository builds:
    ///  /v1/bibles/1849/passages/JHN.1?format=html
    ///
    /// YouVersion returns:
    ///  Passage(id: "JHN.1", reference: "John 1", htmlContent: "<div>...</div>")
    func passage(for reference: ScriptureReference) async throws -> Passage {
        Self.logger.debug("ENTRY YouVersionBibleRepository.passage(reference.passageID: \(reference.passageID, privacy: .public)) -- /v1/bibles/:id/passages/:passage")

        let passagePath = baseURL.appending(path: "v1/bibles/\(reference.translationID)/passages/\(reference.passageID)")

        guard var components = URLComponents(url: passagePath,
                                             resolvingAgainstBaseURL: false) else {
            throw BibleRepositoryError.internalError("Unable to create passage request URL")
        }

        // "text" option doesnt give us any info;
        // need to use "html" to get verse#/redtext/etc back
        components.queryItems = [
            URLQueryItem(name: "format",
                         value: "html"),
            URLQueryItem(name: "include_notes",
                         value: "true")
        ]

        guard let builtUrl = components.url else {
            throw BibleRepositoryError.invalidRequestURL
        }

        let data = try await HttpRequest.fetchData(url: builtUrl,
                                                   httpMethod: "GET",
                                                   headers: ["X-YVP-App-Key": apiKey],
                                                   urlSession: urlSession)

        let jsonDecoder = JSONDecoder()
        let passageResponse = try jsonDecoder.decode(YouVersionPassageResponse.self,
                                                     from: data)

        return passageResponse.passageForApp()
    }

    /// All YouVersion translations support search
    func supportsSearch(translationID: Translation.ID) -> Bool { true }

    /// API verse search implementation
    func searchVerses(_ query: String,
                      translationID: Translation.ID,
                      cursor: ScriptureSearchCursor?,
                      exactText: Bool) async throws -> ScriptureSearchPage {
        Self.logger.debug("ENTRY YouVersionBibleRepository.searchVerses(query: \(query, privacy: .public)) -- /v1/search-verses")

        // obtain URL
        let url = try searchVersesUrl(for: query,
                                      translationID: translationID,
                                      cursor: cursor,
                                      exactText: exactText)

        // make request
        let data = try await HttpRequest.fetchData(url: url,
                                                   httpMethod: "GET",
                                                   headers: ["X-YVP-App-Key": apiKey],
                                                   urlSession: urlSession)

        // decode into YouVersionSearchVersesResponse
        let jsonDecoder = JSONDecoder()
        let searchResponse = try jsonDecoder.decode(YouVersionSearchVersesResponse.self,
                                                    from: data)

        // build ScriptureSearchPage from YouVersionSearchVersesResponse
        return searchResponse.searchPage(translationID: translationID)
    }

    // MARK: Functions (Helpers)

    // Internal for unit tests
    internal func searchVersesUrl(for query: String,
                                  translationID: Translation.ID,
                                  cursor: ScriptureSearchCursor?,
                                  exactText: Bool = false) throws -> URL {
        // build base URL
        let searchPath = baseURL.appending(path: "v1/search-verses")

        guard var components = URLComponents(url: searchPath,
                                             resolvingAgainstBaseURL: false) else {
            throw BibleRepositoryError.internalError("Unable to create search request URL")
        }

        // clean user search query
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAndShortenedQuery = String(trimmedQuery.prefix(100))

        // build URL query
        components.queryItems = [
            URLQueryItem(name: "query",
                         value: trimmedAndShortenedQuery),
            URLQueryItem(name: "bible_id",
                         value: translationID.description),
            URLQueryItem(name: "page_size",
                         value: Self.searchPageSize.description)
        ]
        if case .pageToken(let pageToken) = cursor { // dont need pageNumber (Crossway exclusive)
            components.queryItems?.append(URLQueryItem(name: "page_token",
                                                       value: pageToken))
        }

        // "text" intent searches the words as typed; without it YouVersion auto-corrects typos
        // (probe 2026-11-21: quotes did NOT stop the correction, user_intent=text did)
        if exactText {
            components.queryItems?.append(URLQueryItem(name: "user_intent",
                                                       value: "text"))
        }

        guard let builtUrl = components.url else {
            throw BibleRepositoryError.invalidRequestURL
        }

        return builtUrl
    }
}
