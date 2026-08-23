//
//  FakeBibleRepository.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

/// Fake dummy data implementation for Canvas Previews & unit testing
final class FakeBibleRepository: BibleRepository {

    /// fake repo does not have a real URL/server to separate translation in results;
    /// If it stores two fake passages with the same id then it needs some private extra
    /// key to know which one to return. That private key is translationID
    struct PassageFixture {
        let translationID: Translation.ID
        let passage: Passage
    }

    private let translations: [Translation]
    private let books: [Book]
    private let passages: [PassageFixture]
    private let throwWhenLoadingTranslations: Bool
    private let forceLoadingState: Bool
    
    var throwWhenLoadingBooks: Bool

    init(translations: [Translation] = FakeBibleRepository.defaultTranslations,
         books: [Book] = FakeBibleRepository.defaultBooks,
         passages: [PassageFixture] = FakeBibleRepository.defaultPassages,
         throwWhenLoadingTranslations: Bool = false,
         throwWhenLoadingBooks: Bool = false,
         forceLoadingState: Bool = false) {
        self.translations = translations
        self.books = books
        self.passages = passages
        self.throwWhenLoadingTranslations = throwWhenLoadingTranslations
        self.throwWhenLoadingBooks = throwWhenLoadingBooks
        self.forceLoadingState = forceLoadingState
    }

    func translations(languageTag: String?) async throws -> [Translation] {
        if throwWhenLoadingTranslations {
            throw TestError.testError("Test Error thrown for Translations.")
        }

        if forceLoadingState {
            try await Task.sleep(for: .seconds(99999))
        }

        return translations
    }

    func books(for translationID: Translation.ID) async throws -> [Book] {
        if throwWhenLoadingBooks {
            throw TestError.testError("Test Error thrown for Books.")
        }
        
        return books
    }

    func passage(for reference: ScriptureReference) async throws -> Passage {
        guard let fixture = passages.first(where: {
            $0.translationID == reference.translationID &&
            $0.passage.id == reference.passageID
        }) else {
            throw TestError.passageNotFound
        }

        return fixture.passage
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

    static let defaultPassages: [PassageFixture] = [
        PassageFixture(translationID: 1234,
                       passage: Passage(id: "GEN.1",
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
                                        """)),
        PassageFixture(translationID: 1849,
                       passage: Passage(id: "GEN.1",
                                        reference: "Genesis 1",
                                        htmlContent: """
                                        <div>
                                            <div class="p">
                                                <span class="yv-v" v="1"></span><span class="yv-vlbl">1</span>In the beginning the Living Expression was already there.
                                            </div>
                                            <div class="p">
                                                <span class="yv-v" v="2"></span><span class="yv-vlbl">2</span>They were together in the very beginning.
                                            </div>
                                        </div>
                                        """))
    ]

    /// Passage HTML containing footnotes in verse 2, for previews/tests that need
    /// footnote rendering. Pass to `PassageHTMLParser` to produce a `RenderedPassage`.
    static let footnotePassageHTML = """
    <div class="p">
        <span class="yv-v" v="1"></span><span class="yv-vlbl">1</span>In the beginning God created the heavens and the earth.
    </div>
    <div class="p">
        <span class="yv-v" v="2"></span><span class="yv-vlbl">2</span>Now the earth was formless<span class="yv-n f"><span class="fr">1:2</span><span class="ft">Or “a wind from God swept over the waters.”</span></span> and empty, and darkness<span class="yv-n f"><span class="fr">1:2</span><span class="ft">Darkness here is a distinct entity, more than the absence of light.</span></span><span class="yv-n f"><span class="fr">1:2</span><span class="ft">Footnote # 3</span></span><span class="yv-n f"><span class="fr">1:2</span><span class="ft">Footnote # 4</span></span><span class="yv-n f"><span class="fr">1:2</span><span class="ft">Footnote # 5</span></span><span class="yv-n f"><span class="fr">1:2</span><span class="ft">Footnote # 6</span></span><span class="yv-n f"><span class="fr">1:2</span><span class="ft">Footnote # 7</span></span> covered the deep.
    </div>
    """

    enum TestError: Error {
        case testError(String)
        case passageNotFound
    }
}
