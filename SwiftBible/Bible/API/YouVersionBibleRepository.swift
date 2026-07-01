//
//  YouVersionBibleRepository.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/28/26.
//

import Foundation

final class YouVersionBibleRepository: BibleRepository {

    // MARK: Properties (Private)

    private let apiKey: String
    private let baseURL: URL
    private let urlSession: URLSession

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

        return collectionResponse.translationsForApp()
    }

    /// Load all available Books + Chapters + Verses for a given Translation ID
    func books(for translationID: Translation.ID) async throws -> [Book] {
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
    func passage(for reference: ScriptureReference) async throws -> Passage {
        let passagePath = baseURL.appending(path: "v1/bibles/\(reference.translationID)/passages/\(reference.passageID)")

        guard var components = URLComponents(url: passagePath,
                                             resolvingAgainstBaseURL: false) else {
            throw BibleRepositoryError.internalError("Unable to create passage request URL")
        }

        // "text" option doesnt give us any info;
        // need to use "html" to get verse#/redtext/etc back
        components.queryItems = [
            URLQueryItem(name: "format",
                         value: "html")
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
}
