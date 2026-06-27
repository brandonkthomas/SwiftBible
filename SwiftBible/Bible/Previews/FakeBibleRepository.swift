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

    init(translations: [Translation] = FakeBibleRepository.defaultTranslations,
         books: [Book] = FakeBibleRepository.defaultBooks) {
        self.translations = translations
        self.books = books
    }

    func translations(languageTag: String?) async throws -> [Translation] {
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
        Book(id: "BOK",
             code: "BOK",
             displayName: "Book Name",
             canon: .deuterocanon,
             chapters: [
                Chapter(id: "BOK.1",
                        number: 1,
                        bookID: "BOK",
                        displayName: "1")
             ])
    ]

    static let booksWithoutChapters: [Book] = [
        Book(id: "BOK",
             code: "BOK",
             displayName: "Book Name",
             canon: .deuterocanon,
             chapters: [])
    ]
}
