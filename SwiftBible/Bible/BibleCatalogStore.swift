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

    /// Translations sorted by title
    var translationsByTitle: [Translation] {
        translations.sorted { $0.title < $1.title }
    }

    // MARK: Properties (Private)

    /// BibleRepository implementation
    private let repository: any BibleRepository
    
    /// All available translations
    ///
    /// private(set) allows only us to write; all other external referencers can read
    private(set) var translations: [Translation] = []
    
    /// All available books; each mapped to one translation
    private var booksByTranslation: [Translation.ID: [Book]] = [:]

    /// Copyright lookups for translations whose list entry had no notice
    ///
    /// No entry can mean not looked up yet or found and merged into translations
    private(set) var copyrightNoticeStatuses: [Translation.ID: CopyrightNoticeStatus] = [:]

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

    // MARK: Properties (Private, Cache)

    /// Stores API-retrieved Translations/Books clientside for performance
    private let catalogCache: any CatalogCache

    private let appBuildNumber: String?
    private static let unknownBuildNumber: String = "unknownBuildNumber"
    private static let maximumCacheAgeInDays: Int = 7
    private static let maximumCopyrightCacheAgeInDays: Int = 30

    /// In-flight book loads per translation, so concurrent callers (ReaderStore and
    /// LibraryStore at launch) share one cache read and network request
    ///
    /// @ObservationIgnored: bookkeeping only; views never read it
    @ObservationIgnored
    private var inFlightBookLoads: [Translation.ID: Task<Void, Error>] = [:]

    private static let logger = Logger(subsystem: "SwiftBible", category: "BibleCatalogStore")

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
            // update self.translations w/ cache regardless of freshness
            // if not fresh, refresh from network below
            if let languageTag,
               let cachedTranslationsEntry = try await catalogCache.translations(for: languageTag),
               !cachedTranslationsEntry.value.isEmpty { // ensure validity
                self.translations = cachedTranslationsEntry.value
                didCacheHit = true
                Self.logger.info("CACHE: loadTranslations catalogCache.translations(for: \(languageTag))")

                let isFresh = cachedTranslationsEntry.isEntryFresh(Date.now,
                                                                   maximumAgeInDays: Self.maximumCacheAgeInDays,
                                                                   currentBuildNumber: appBuildNumber)
                if isFresh { return } // we're done here
            }
        } catch {
            // cache failed for some reason; try network
            Self.logger.error("loadTranslations catalogCache.translations(for:) failed: \(error.localizedDescription)")
        }

        // now, update w/ network if cache was NOT fresh to replace it w/ a new result
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

    /// Fill in copyright for each translation that has none
    ///
    /// Called when Acknowledgments opens
    ///
    /// Cache for 30 days; otherwise one request per translation, in order
    /// Skips translations already loading or known to have no notice; retries if failed
    func loadMissingCopyrightNotices() async {
        let missingIDs = translations
            .filter { $0.copyrightNotice == nil }
            .map(\.id)
            .filter { copyrightNoticeStatuses[$0] == nil || copyrightNoticeStatuses[$0] == .failed }

        for id in missingIDs {
            copyrightNoticeStatuses[id] = .loading
        }

        for id in missingIDs {
            guard let copyright = await copyrightFromCacheOrRepository(for: id) else {
                copyrightNoticeStatuses[id] = .failed
                continue
            }

            // translations may have been replaced while waiting; look entry up again
            if copyright.notice != nil,
               let index = translations.firstIndex(where: { $0.id == id }) {
                translations[index] = translations[index].withCopyright(copyright)
                copyrightNoticeStatuses[id] = nil
            } else {
                copyrightNoticeStatuses[id] = .unavailable
            }
        }
    }

    /// Fresh cache first; network when missing or stale; stale cache when the network fails
    ///
    /// nil only when network failed w/ nothing cached
    /// Provider with no notice is cached too (i.e. ASV isn't asked again for 30 days)
    private func copyrightFromCacheOrRepository(for translationID: Translation.ID) async -> TranslationCopyright? {
        var cachedCopyright: TranslationCopyright?
        do {
            if let cachedEntry = try await catalogCache.copyright(for: translationID) {
                cachedCopyright = cachedEntry.value

                let isFresh = cachedEntry.isEntryFresh(Date.now,
                                                       maximumAgeInDays: Self.maximumCopyrightCacheAgeInDays,
                                                       currentBuildNumber: appBuildNumber)
                if isFresh { return cachedEntry.value }
            }
        } catch {
            Self.logger.error("copyrightFromCacheOrRepository catalogCache.copyright(for: \(translationID)) failed: \(error.localizedDescription)")
        }

        let copyright: TranslationCopyright
        do {
            let detail = try await repository.translationDetail(for: translationID)
            copyright = detail?.copyright ?? TranslationCopyright(license: nil, promotionalText: nil)
        } catch {
            Self.logger.error("copyrightFromCacheOrRepository translationDetail(for: \(translationID)) failed: \(error.localizedDescription)")
            return cachedCopyright
        }

        // best-effort, like the other catalog saves
        do {
            let entry = CatalogCacheEntry<TranslationCopyright>(value: copyright,
                                                                createdOn: Date.now,
                                                                createdByBuildNumber: appBuildNumber ?? Self.unknownBuildNumber)
            try await catalogCache.save(entry, for: translationID)
        } catch {
            Self.logger.error("copyrightFromCacheOrRepository catalogCache.save(:for:) failed: \(error.localizedDescription)")
        }

        return copyright
    }

    // MARK: Functions (Books)

    /// Load books using given BibleRepository implementation (try cache first)
    ///
    /// A call while another load of the same translation is running waits for that load
    /// (and gets its error, if any) instead of starting a second one
    func loadBooks(for translationID: Translation.ID) async throws {
        if let existingLoad = inFlightBookLoads[translationID] {
            return try await existingLoad.value
        }

        // Registered before the first await, so a second caller always finds it
        let load = Task {
            try await self.loadBooksFromCacheOrRepository(for: translationID)
        }

        inFlightBookLoads[translationID] = load

        defer {
            inFlightBookLoads[translationID] = nil
        }

        try await load.value
    }

    /// Cache first; network when the cache is missing or stale; then save the refresh
    private func loadBooksFromCacheOrRepository(for translationID: Translation.ID) async throws {
        // try from the cache first-and-foremost; fast assignment if it hits
        // (swallow failures to give network a chance later)
        var didCacheHit = false
        do {
            // update self.booksByTranslation w/ cache regardless of freshness
            // if not fresh, refresh from network below
            if let cachedBooksEntry = try await catalogCache.books(for: translationID),
               !cachedBooksEntry.value.isEmpty { // ensure validity
                self.booksByTranslation[translationID] = cachedBooksEntry.value
                didCacheHit = true
                Self.logger.info("CACHE: loadBooks catalogCache.books(for: \(translationID))")

                let isFresh = cachedBooksEntry.isEntryFresh(Date.now,
                                                            maximumAgeInDays: Self.maximumCacheAgeInDays,
                                                            currentBuildNumber: appBuildNumber)
                if isFresh { return } // we're done here
            }
        } catch {
            // cache failed for some reason; try network
            Self.logger.error("loadBooks catalogCache.books(for:) failed: \(error.localizedDescription)")
        }

        // now, update w/ network if cache was NOT fresh to replace it w/ a new result
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

/// Where a missing copyright lookup stands
enum CopyrightNoticeStatus: Equatable {
    case loading
    /// The provider answered with no notice (ASV today)
    case unavailable
    /// The request failed; the next loadMissingCopyrightNotices() retries it
    case failed
}
