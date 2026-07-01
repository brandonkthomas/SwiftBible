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
    private let passages: [Passage]
    private let throwWhenLoadingTranslations: Bool
    private let forceLoadingState: Bool

    init(translations: [Translation] = FakeBibleRepository.defaultTranslations,
         books: [Book] = FakeBibleRepository.defaultBooks,
         passages: [Passage] = FakeBibleRepository.defaultPassages,
         throwWhenLoadingTranslations: Bool = false,
         forceLoadingState: Bool = false) {
        self.translations = translations
        self.books = books
        self.passages = passages
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

    func books(for translationID: Translation.ID) async throws -> [Book] {
        return books
    }

    func passage(for reference: ScriptureReference) async throws -> Passage {
        guard let passage = passages.first(where: { $0.id == reference.passageID }) else {
            throw TestError.passageNotFound
        }

        return passage
    }

    static let defaultTranslations: [Translation] = [
        Translation(id: 1234,
                    abbreviation: "NIV",
                    title: "New International Version",
                    languageTag: "en",
                    license: "Copyright (c) 2026 by Publishing Company.",
                    promotionalText: nil,
                    availableBookCodes: ["GEN", "EXO", "LEV"]),
        Translation(id: 1849,
                    abbreviation: "TPT",
                    title: "The Passion Translation",
                    languageTag: "en",
                    license: "Copyright (c) 2026 by BroadStreet Publishing.",
                    promotionalText: nil,
                    availableBookCodes: ["GEN", "EXO", "LEV"])
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
                        displayName: "1",
                        verses: [
                            Verse(id: "GEN.1.1",
                                  number: 1,
                                  chapterID: "GEN.1",
                                  bookID: "GEN",
                                  displayName: "1"),
                            Verse(id: "GEN.1.2",
                                  number: 2,
                                  chapterID: "GEN.1",
                                  bookID: "GEN",
                                  displayName: "2"),
                            Verse(id: "GEN.1.3",
                                  number: 3,
                                  chapterID: "GEN.1",
                                  bookID: "GEN",
                                  displayName: "3")
                        ]),
                Chapter(id: "GEN.2",
                        number: 2,
                        bookID: "GEN",
                        displayName: "2",
                        verses: []),
                Chapter(id: "GEN.3",
                        number: 3,
                        bookID: "GEN",
                        displayName: "3",
                        verses: [])
             ]),
        Book(id: "EXO",
             code: "EXO",
             displayName: "Exodus",
             canon: .oldTestament,
             chapters: [])
    ]

    static let booksWithoutChapters: [Book] = [
        Book(id: "GEN",
             code: "GEN",
             displayName: "Genesis",
             canon: .oldTestament,
             chapters: [])
    ]

    static let defaultPassages: [Passage] = [
        Passage(id: "GEN.1",
                reference: "Genesis 1",
                htmlContent: """
                <div>
                    <div class="p">
                        <span class="yv-v" v="1"></span><span class="yv-vlbl">1</span>In the beginning God created the heavens and the earth.
                    </div>
                    <div class="p">
                        <span class="yv-v" v="2"></span><span class="yv-vlbl">2</span>Now the earth was formless and empty.
                    </div>
                </div>
                """)
    ]

    enum TestError: Error {
        case testError(String)
        case passageNotFound
    }
}
