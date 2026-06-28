//
//  FakeBibleRepository.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

/// Fake dummy data implementation for Canvas Previews & unit testing
final class FakeBibleRepository: BibleRepository {

    private let translations: [Translation]
    private let books: [Book]
    private let throwWhenLoadingTranslations: Bool
    private let forceLoadingState: Bool

    init(translations: [Translation] = FakeBibleRepository.defaultTranslations,
         books: [Book] = FakeBibleRepository.defaultBooks,
         throwWhenLoadingTranslations: Bool = false,
         forceLoadingState: Bool = false) {
        self.translations = translations
        self.books = books
        self.throwWhenLoadingTranslations = throwWhenLoadingTranslations
        self.forceLoadingState = forceLoadingState
    }

    func translations(languageTag: String?) async throws -> [Translation] {
        if throwWhenLoadingTranslations {
            throw TestError.testError("Test Error thrown.")
        }

        if forceLoadingState {
            try await Task.sleep(for: .seconds(99999))
        }

        return translations
    }

    func books(for translationID: String) async throws -> [Book] {
        return books
    }

    static let defaultTranslations: [Translation] = [
        Translation(id: "1849",
                    abbreviation: "TPT",
                    title: "The Passion Translation",
                    languageTag: "en",
                    license: "Copyright (c) 2026 by BroadStreet Publishing.",
                    promotionalText: nil)
    ]

    static let defaultBooks: [Book] = [
        Book(id: "GEN",
             code: "GEN",
             displayName: "Genesis",
             canon: .oldTestament,
             chapters: [
                Chapter(id: "GEN.1",
                        number: 1,
                        bookID: "GEN",
                        displayName: "1"),
                Chapter(id: "GEN.2",
                        number: 2,
                        bookID: "GEN",
                        displayName: "2"),
                Chapter(id: "GEN.3",
                        number: 3,
                        bookID: "GEN",
                        displayName: "3")
             ])
    ]

    static let booksWithoutChapters: [Book] = [
        Book(id: "GEN",
             code: "GEN",
             displayName: "Genesis",
             canon: .oldTestament,
             chapters: [])
    ]

    enum TestError: Error {
        case testError(String)
    }
}
