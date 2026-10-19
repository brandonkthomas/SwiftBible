//
//  BibleCatalogStore.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-08-13.
//

import Observation

@Observable
final class BibleCatalogStore {

    // MARK: Properties (Private)

    /// BibleRepository implementation
    private let repository: any BibleRepository
    
    /// All available translations
    ///
    /// private(set) allows only us to write; all other external referencers can read
    private(set) var translations: [Translation] = []
    
    /// All available books; each mapped to one translation
    private var booksByTranslation: [Translation.ID: [Book]] = [:]

    /// USFM book codes in Protestant canonical order, then deuterocanonical books in USFM order
    /// https://ubsicap.github.io/usfm/identification/books.html
    private static let canonicalBookCodes: [String] = [
        // Old Testament
        "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA",
        "1KI", "2KI", "1CH", "2CH", "EZR", "NEH", "EST", "JOB", "PSA", "PRO",
        "ECC", "SNG", "ISA", "JER", "LAM", "EZK", "DAN", "HOS", "JOL", "AMO",
        "OBA", "JON", "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL",
        // New Testament
        "MAT", "MRK", "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL", "EPH",
        "PHP", "COL", "1TH", "2TH", "1TI", "2TI", "TIT", "PHM", "HEB", "JAS",
        "1PE", "2PE", "1JN", "2JN", "3JN", "JUD", "REV",
        // Deuterocanon
        "TOB", "JDT", "ESG", "WIS", "SIR", "BAR", "LJE", "S3Y", "SUS", "BEL",
        "1MA", "2MA", "3MA", "4MA", "1ES", "2ES", "MAN", "PS2"
    ]

    // MARK: Init

    init(repository: any BibleRepository) {
        self.repository = repository
    }

    // MARK: Functions
    
    // Translations

    /// Assigns to self.translations only if repository.translations() call does not throw
    func loadTranslations(languageTag: String? = "en") async throws {
        let updatedTranslations = try await repository.translations(languageTag: languageTag)
        self.translations = updatedTranslations
    }

    /// Retrieve a Translation by ID (from memory)
    func translation(for id: Translation.ID) -> Translation? {
        return self.translations.first { $0.id == id }
    }
    
    // Books
    
    /// Load books using given BibleRepository implementation
    func loadBooks(for translationID: Translation.ID) async throws {
        self.booksByTranslation[translationID] = try await repository.books(for: translationID)
    }
    
    /// Retrieve all books for a given Translation.ID (from memory)
    func books(for translationID: Translation.ID) -> [Book]? {
        return self.booksByTranslation[translationID]
    }
    
    /// Retrieve a specific book by code + its Translation.ID (from memory)
    func book(for translationID: Translation.ID,
              bookCode: String) -> Book? {
        guard let books = books(for: translationID) else {
            return nil
        }
        return books.first { $0.code == bookCode }
    }

    /// Where is a given Translation's Book located in its index?
    static func bookPosition(for bookCode: String) -> Int? {
        // BUG: this was returning different indexes for same book across different translations (TPT)
        // Changed to use canonical static list instead
//        return books(for: translationID)?.firstIndex { $0.code == bookCode }
        return canonicalBookCodes.firstIndex { $0 == bookCode }
    }

    /// Builds a friendly name (i.e. "Genesis 1:1-2") for a given ScriptureReference + range
    /// (i.e. AnnotationEditor)
    func friendlyPassageName(for reference: ScriptureReference,
                             selectedVerses: ClosedRange<Int>?) -> String {
        return passageFriendlyNameCalc(translationID: reference.translationID,
                                       bookCode: reference.bookCode,
                                       chapter: reference.chapter,
                                       verseRange: selectedVerses)
    }

    /// Builds a friendly name (i.e. "Genesis 1:1-2") for a given VerseAnnotation
    func friendlyPassageName(for annotation: VerseAnnotation) -> String {
        return passageFriendlyNameCalc(translationID: annotation.translationID,
                                       bookCode: annotation.bookCode,
                                       chapter: annotation.chapter,
                                       verseRange: annotation.verseRange)
    }

    // MARK: Functions (Private)

    /// Builds a friendly name (i.e. "Genesis 1:1-2") -- SHARED LOGIC
    private func passageFriendlyNameCalc(translationID: Translation.ID,
                                         bookCode: String,
                                         chapter: Int,
                                         verseRange: ClosedRange<Int>?) -> String {
        let book = book(for: translationID,
                        bookCode: bookCode)

        guard let verseRange else {
            return "\(book?.displayName ?? bookCode) \(chapter)"
        }

        let verseRangeText = RenderedVerseRange(range: verseRange).displayText

        return "\(book?.displayName ?? bookCode) \(chapter):\(verseRangeText)"
    }
}
