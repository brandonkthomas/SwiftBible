//
//  FakeBibleRepository.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

/// Fake dummy data implementation for Canvas Previews & unit testing
final class FakeBibleRepository: BibleRepository {

    private let translation = Translation(id: "1849",
                                          abbreviation: "TPT",
                                          title: "The Passion Translation",
                                          languageTag: "en",
                                          license: "Copyright (c) 2026 by BroadStreet Publishing.",
                                          promotionalText: nil)

    private let book = Book(id: "BOK",
                            code: "BOK",
                            displayName: "Book Name",
                            canon: Canon.deuterocanon,
                            chapters: [])

//    private let chapter = Chapter(id: "BOK.1",
//                                  number: 1,
//                                  bookID: "BOK",
//                                  displayName: "1")

    func translations(languageTag: String?) async throws -> [Translation] {
        return [translation]
    }

    func books(for translationID: String) async throws -> [Book] {
        return [book]
    }
}
