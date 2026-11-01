//
//  BibleCatalogStore.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-08-13.
//

import Observation
import OSLog

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

    private static let logger = Logger(subsystem: "SwiftBible", category: "BibleCatalogStore")

    // MARK: Properties (Private, Cache)

    /// Stores API-retrieved Translations/Books clientside for performance
    private let catalogCache: any CatalogCache

    private let appBuildNumber: String?
    private static let unknownBuildNumber: String = "unknownBuildNumber"

    // MARK: Init

    init(repository: any BibleRepository,
         catalogCache: any CatalogCache = InMemoryCatalogCache(),
         appBuildNumber: String? = Bundle.main.infoDictionary?["CFBundleVersion"] as? String) {
        self.repository = repository
        self.catalogCache = catalogCache
        self.appBuildNumber = appBuildNumber
    }

    // MARK: Functions (Translations)

    /// Assigns to self.translations (try from cache first)
    func loadTranslations(languageTag: String? = "en") async throws {
        // try from the cache first-and-foremost; fast assignment if it hits
        // (swallow failures to give network a chance later)
        var didCacheHit = false
        do {
            if let languageTag,
               let cachedTranslations = try await catalogCache.translations(for: languageTag) {
                self.translations = cachedTranslations.value
                didCacheHit = true
                Self.logger.info("CACHE: loadTranslations catalogCache.translations(for: \(languageTag))")
            }
        } catch {
            Self.logger.error("loadTranslations catalogCache.translations(for:) failed: \(error.localizedDescription)")
        }

        // hit network anyway to replace w/ a new result in the background if necessary
        do {
            let loadedTranslations = try await repository.translations(languageTag: languageTag)
            self.translations = loadedTranslations
        } catch {
            if didCacheHit {
                // if we already had a cache hit, ignore
                Self.logger.error("loadTranslations repository.translations() failed: \(error.localizedDescription)")
                return
            } else {
                // else, both failed; we have nothing; rethrow original error
                throw error
            }
        }

        // network done; try to update cache (best-effort)
        do {
            if let languageTag {
                // unknownBuildNumber: still allow saving + cache to function in case Info.plist is wrong
                let catalogCacheEntry = CatalogCacheEntry<[Translation]>(value: self.translations,
                                                                         createdOn: Date.now,
                                                                         createdByBuildNumber: appBuildNumber ?? Self.unknownBuildNumber)
                try await catalogCache.save(catalogCacheEntry, for: languageTag)
            }
        } catch {
            Self.logger.error("loadTranslations catalogCache.save(:for:) failed: \(error.localizedDescription)")
        }
    }

    /// Retrieve a Translation by ID (from memory)
    func translation(for id: Translation.ID) -> Translation? {
        return self.translations.first { $0.id == id }
    }
    
    // MARK: Functions (Books)

    /// Load books using given BibleRepository implementation (try cache first)
    func loadBooks(for translationID: Translation.ID) async throws {
        // try from the cache first-and-foremost; fast assignment if it hits
        // (swallow failures to give network a chance later)
        var didCacheHit = false
        do {
            if let cachedBooks = try await catalogCache.books(for: translationID) {
                self.booksByTranslation[translationID] = cachedBooks.value
                didCacheHit = true
                Self.logger.info("CACHE: loadBooks catalogCache.books(for: \(translationID))")
            }
        } catch {
            Self.logger.error("loadBooks catalogCache.books(for:) failed: \(error.localizedDescription)")
        }

        // hit network anyway to replace w/ a new result in the background if necessary
        do {
            let loadedBooks = try await repository.books(for: translationID)
            self.booksByTranslation[translationID] = loadedBooks
        } catch {
            if didCacheHit {
                // if we already had a cache hit, ignore
                Self.logger.error("loadBooks repository.books() failed: \(error.localizedDescription)")
                return
            } else {
                // else, both failed; we have nothing; rethrow original error
                throw error
            }
        }

        // network done; try to update cache (best-effort)
        do {
            if let books = self.booksByTranslation[translationID] {
                // unknownBuildNumber: still allow saving + cache to function in case Info.plist is wrong
                let catalogCacheEntry = CatalogCacheEntry<[Book]>(value: books,
                                                                  createdOn: Date.now,
                                                                  createdByBuildNumber: appBuildNumber ?? Self.unknownBuildNumber)
                try await catalogCache.save(catalogCacheEntry, for: translationID)
            }
        } catch {
            Self.logger.error("loadBooks catalogCache.save(:for:) failed: \(error.localizedDescription)")
        }
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

    /// Where is a Book located in the canonical index?
    static func bookPosition(for bookCode: String) -> Int? {
        canonicalBookCodes.firstIndex(of: bookCode)
    }

    // MARK: Functions (Passage Names)

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
