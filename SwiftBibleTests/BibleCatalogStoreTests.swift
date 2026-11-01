//
//  BibleCatalogStoreTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-08-13.
//

import Foundation
import Testing
@testable import SwiftBible

@MainActor
struct BibleCatalogStoreTests {

    /// Ensure translations load and store their data inside BibleCatalogStore losslessly
    @Test func loadTranslationsStoresAndResolvesResults() async throws {
        // Confirm catalog starts empty
        let repository = FakeBibleRepository()
        let catalogStore = BibleCatalogStore(repository: repository)
        #expect(catalogStore.translations.isEmpty)

        // Call try await loadTranslations()
        // Confirm it contains fake translation data
        try await catalogStore.loadTranslations()
        #expect(!catalogStore.translations.isEmpty)
        #expect(catalogStore.translations == FakeBibleRepository.defaultTranslations)

        // Resolve ID and compare w/ expected
        let expected = try #require(FakeBibleRepository.defaultTranslations.first)
        #expect(catalogStore.translation(for: expected.id) == expected)

        // Confirm unknown ID returns nil
        #expect(catalogStore.translation(for: 9999) == nil)
    }

    /// Ensure failing to load translations does not populate BibleCatalogStore
    @Test func failedTranslationLoadLeavesCatalogEmpty() async {
        // Confirm the catalog starts empty
        let repository = FakeBibleRepository(throwWhenLoadingTranslations: true)
        let catalogStore = BibleCatalogStore(repository: repository)

        do {
            try await catalogStore.loadTranslations()
        } catch {
            #expect(catalogStore.translations.isEmpty)
            return
        }

        Issue.record("catalogStore unexpectedly succeeded; expected it to fail")
    }

    /// A network failure after translations were cached does not throw; the cached translations are kept
    @Test func failedTranslationLoadWithCachedCopyDoesNotThrowAndKeepsTranslations() async throws {
        // Expired entry forces a network attempt; the network always fails
        let catalogCache = InMemoryCatalogCache()
        try await catalogCache.save(makeEntry(Self.cachedTranslations, ageInDays: 8), for: "en")
        let repository = StubBibleRepository(translations: Self.repositoryTranslations)
        repository.failsLoadingTranslations = true
        let catalogStore = makeStore(repository: repository, catalogCache: catalogCache)

        await #expect(throws: Never.self) {
            try await catalogStore.loadTranslations()
        }

        #expect(repository.translationsCallCount == 1)
        #expect(catalogStore.translations == Self.cachedTranslations)
    }

    // MARK: Translations Cache Freshness

    /// A fresh entry from the current build is used as-is; the network is never called
    @Test func freshCachedTranslationsSkipRepository() async throws {
        let catalogCache = InMemoryCatalogCache()
        try await catalogCache.save(makeEntry(Self.cachedTranslations), for: "en")
        let repository = StubBibleRepository(translations: Self.repositoryTranslations)
        let catalogStore = makeStore(repository: repository, catalogCache: catalogCache)

        try await catalogStore.loadTranslations()

        #expect(repository.translationsCallCount == 0)
        #expect(catalogStore.translations == Self.cachedTranslations)
    }

    /// An entry older than the maximum age is replaced by the repository's list
    @Test func expiredCachedTranslationsRefreshFromRepository() async throws {
        let catalogCache = InMemoryCatalogCache()
        try await catalogCache.save(makeEntry(Self.cachedTranslations, ageInDays: 8), for: "en")
        let repository = StubBibleRepository(translations: Self.repositoryTranslations)
        let catalogStore = makeStore(repository: repository, catalogCache: catalogCache)

        try await catalogStore.loadTranslations()

        #expect(repository.translationsCallCount == 1)
        #expect(catalogStore.translations == Self.repositoryTranslations)

        // The refresh must be saved, otherwise every launch hits the network again
        let savedEntry = try #require(try await catalogCache.translations(for: "en"))
        #expect(savedEntry.value == Self.repositoryTranslations)
        #expect(savedEntry.isEntryFresh(.now,
                                        maximumAgeInDays: Self.maximumCacheAgeInDays,
                                        currentBuildNumber: Self.currentBuildNumber))
    }

    /// A recent, same-build entry with an empty list is treated as a miss; the repository is called
    @Test func emptyCachedTranslationsRefreshFromRepository() async throws {
        let catalogCache = InMemoryCatalogCache()
        try await catalogCache.save(makeEntry([Translation]()), for: "en")
        let repository = StubBibleRepository(translations: Self.repositoryTranslations)
        let catalogStore = makeStore(repository: repository, catalogCache: catalogCache)

        try await catalogStore.loadTranslations()

        #expect(repository.translationsCallCount == 1)
        #expect(catalogStore.translations == Self.repositoryTranslations)
    }

    /// An entry saved by a different build is replaced by the repository's list
    @Test func cachedTranslationsFromOtherBuildRefreshFromRepository() async throws {
        let catalogCache = InMemoryCatalogCache()
        try await catalogCache.save(makeEntry(Self.cachedTranslations, buildNumber: Self.otherBuildNumber), for: "en")
        let repository = StubBibleRepository(translations: Self.repositoryTranslations)
        let catalogStore = makeStore(repository: repository, catalogCache: catalogCache)

        try await catalogStore.loadTranslations()

        #expect(repository.translationsCallCount == 1)
        #expect(catalogStore.translations == Self.repositoryTranslations)
    }

    @Test func booksLoadLosslesslyForTranslation() async throws {
        let translationID = 1234
        let expectedBooks = FakeBibleRepository.defaultBooks
        let repository = StubBibleRepository(booksByTranslation: [translationID: expectedBooks])
        let catalogStore = BibleCatalogStore(repository: repository)

        try await catalogStore.loadBooks(for: translationID)

        #expect(catalogStore.books(for: translationID) == expectedBooks)
    }

    @Test func knownTranslationAndBookCodeResolvesCorrectly() async throws {
        let translationID = 1234
        let expectedBook = try #require(
            FakeBibleRepository.defaultBooks.first(where: { $0.code == "GEN" })
        )
        let repository = StubBibleRepository(
            booksByTranslation: [translationID: FakeBibleRepository.defaultBooks]
        )
        let catalogStore = BibleCatalogStore(repository: repository)

        try await catalogStore.loadBooks(for: translationID)

        #expect(catalogStore.book(for: translationID, bookCode: "GEN") == expectedBook)
    }

    @Test func unknownTranslationReturnsNil() async throws {
        let translationIDActual = 1234
        let translationIDFake = 385438
        let repository = StubBibleRepository(
            booksByTranslation: [translationIDActual: FakeBibleRepository.defaultBooks]
        )
        let catalogStore = BibleCatalogStore(repository: repository)

        try await catalogStore.loadBooks(for: translationIDActual)

        #expect(catalogStore.books(for: translationIDFake) == nil)
    }

    @Test func unknownBookCodeReturnsNil() async throws {
        let translationID = 1234
        let repository = StubBibleRepository(
            booksByTranslation: [translationID: FakeBibleRepository.defaultBooks]
        )
        let catalogStore = BibleCatalogStore(repository: repository)

        try await catalogStore.loadBooks(for: translationID)

        #expect(catalogStore.book(for: translationID, bookCode: "UNKNOWN") == nil)
    }

    @Test func loadingTwoTranslationsPreservesIndependentEntries() async throws {
        let firstTranslationID = 1234
        let secondTranslationID = 1849
        let firstBooks = FakeBibleRepository.defaultBooks
        let secondBooks = FakeBibleRepository.booksWithoutChapters
        let repository = StubBibleRepository(booksByTranslation: [
            firstTranslationID: firstBooks,
            secondTranslationID: secondBooks
        ])
        let catalogStore = BibleCatalogStore(repository: repository)

        try await catalogStore.loadBooks(for: firstTranslationID)
        try await catalogStore.loadBooks(for: secondTranslationID)

        #expect(catalogStore.books(for: firstTranslationID) == firstBooks)
        #expect(catalogStore.books(for: secondTranslationID) == secondBooks)
    }

    /// A network failure after books were cached does not throw; the cached books are kept
    @Test func failedBookLoadWithCachedCopyDoesNotThrowAndKeepsBooks() async throws {
        // Expired entry forces a network attempt; the network always fails
        let translationID = 1234
        let catalogCache = InMemoryCatalogCache()
        try await catalogCache.save(makeEntry(Self.cachedBooks, ageInDays: 8), for: translationID)
        let repository = StubBibleRepository(booksByTranslation: [translationID: Self.repositoryBooks])
        repository.failingTranslationIDs.insert(translationID)
        let catalogStore = makeStore(repository: repository, catalogCache: catalogCache)

        await #expect(throws: Never.self) {
            try await catalogStore.loadBooks(for: translationID)
        }

        #expect(repository.booksCallCount == 1)
        #expect(catalogStore.books(for: translationID) == Self.cachedBooks)
    }

    /// A network failure with nothing cached throws, and no books are stored
    @Test func failedBookLoadWithoutCachedCopyThrows() async {
        let translationID = 1234
        let repository = StubBibleRepository(booksByTranslation: [translationID: FakeBibleRepository.defaultBooks])
        repository.failingTranslationIDs.insert(translationID)
        let catalogStore = BibleCatalogStore(repository: repository)

        await #expect(throws: StubBibleRepository.RepositoryError.self) {
            try await catalogStore.loadBooks(for: translationID)
        }

        #expect(catalogStore.books(for: translationID) == nil)
    }

    // MARK: Books Cache Freshness

    /// A fresh entry from the current build is used as-is; the network is never called
    @Test func freshCachedBooksSkipRepository() async throws {
        let translationID = 1234
        let catalogCache = InMemoryCatalogCache()
        try await catalogCache.save(makeEntry(Self.cachedBooks), for: translationID)
        let repository = StubBibleRepository(booksByTranslation: [translationID: Self.repositoryBooks])
        let catalogStore = makeStore(repository: repository, catalogCache: catalogCache)

        try await catalogStore.loadBooks(for: translationID)

        #expect(repository.booksCallCount == 0)
        #expect(catalogStore.books(for: translationID) == Self.cachedBooks)
    }

    /// An entry older than the maximum age is replaced by the repository's list
    @Test func expiredCachedBooksRefreshFromRepository() async throws {
        let translationID = 1234
        let catalogCache = InMemoryCatalogCache()
        try await catalogCache.save(makeEntry(Self.cachedBooks, ageInDays: 8), for: translationID)
        let repository = StubBibleRepository(booksByTranslation: [translationID: Self.repositoryBooks])
        let catalogStore = makeStore(repository: repository, catalogCache: catalogCache)

        try await catalogStore.loadBooks(for: translationID)

        #expect(repository.booksCallCount == 1)
        #expect(catalogStore.books(for: translationID) == Self.repositoryBooks)

        // The refresh must be saved, otherwise every launch hits the network again
        let savedEntry = try #require(try await catalogCache.books(for: translationID))
        #expect(savedEntry.value == Self.repositoryBooks)
        #expect(savedEntry.isEntryFresh(.now,
                                        maximumAgeInDays: Self.maximumCacheAgeInDays,
                                        currentBuildNumber: Self.currentBuildNumber))
    }

    /// A recent, same-build entry with an empty list is treated as a miss; the repository is called
    @Test func emptyCachedBooksRefreshFromRepository() async throws {
        let translationID = 1234
        let catalogCache = InMemoryCatalogCache()
        try await catalogCache.save(makeEntry([Book]()), for: translationID)
        let repository = StubBibleRepository(booksByTranslation: [translationID: Self.repositoryBooks])
        let catalogStore = makeStore(repository: repository, catalogCache: catalogCache)

        try await catalogStore.loadBooks(for: translationID)

        #expect(repository.booksCallCount == 1)
        #expect(catalogStore.books(for: translationID) == Self.repositoryBooks)
    }

    /// An entry saved by a different build is replaced by the repository's list
    @Test func cachedBooksFromOtherBuildRefreshFromRepository() async throws {
        let translationID = 1234
        let catalogCache = InMemoryCatalogCache()
        try await catalogCache.save(makeEntry(Self.cachedBooks, buildNumber: Self.otherBuildNumber), for: translationID)
        let repository = StubBibleRepository(booksByTranslation: [translationID: Self.repositoryBooks])
        let catalogStore = makeStore(repository: repository, catalogCache: catalogCache)

        try await catalogStore.loadBooks(for: translationID)

        #expect(repository.booksCallCount == 1)
        #expect(catalogStore.books(for: translationID) == Self.repositoryBooks)
    }

    /// Fixtures must differ, otherwise a cache answer and a network answer look identical
    @Test func cacheFixturesDifferFromRepositoryFixtures() {
        #expect(Self.cachedTranslations != Self.repositoryTranslations)
        #expect(Self.cachedBooks != Self.repositoryBooks)
    }

    // MARK: Friendly Passage Name

    /// A loaded book resolves to its display name instead of the raw book code
    @Test func friendlyPassageNameUsesBookDisplayName() async throws {
        let catalogStore = BibleCatalogStore(repository: FakeBibleRepository())
        try await catalogStore.loadBooks(for: 1234)
        let annotation = makeAnnotation(startVerse: 1)

        #expect(catalogStore.friendlyPassageName(for: annotation) == "Genesis 1:1")
    }

    /// An unloaded book falls back to the raw book code
    @Test func friendlyPassageNameFallsBackToRawBookCode() {
        // books never loaded, so book(for:bookCode:) returns nil
        let catalogStore = BibleCatalogStore(repository: FakeBibleRepository())
        let annotation = makeAnnotation(startVerse: 1)

        #expect(catalogStore.friendlyPassageName(for: annotation) == "GEN 1:1")
    }

    /// A nil verse range produces a chapter-only name
    @Test func friendlyPassageNameWithoutVersesIsChapterOnly() async throws {
        let catalogStore = BibleCatalogStore(repository: FakeBibleRepository())
        try await catalogStore.loadBooks(for: 1234)
        let reference = try #require(ScriptureReference(translationID: 1234,
                                                        bookCode: "GEN",
                                                        chapter: 1))

        #expect(catalogStore.friendlyPassageName(for: reference, selectedVerses: nil) == "Genesis 1")
    }

    /// A single-verse range shows one verse number
    @Test func friendlyPassageNameShowsSingleVerse() async throws {
        let catalogStore = BibleCatalogStore(repository: FakeBibleRepository())
        try await catalogStore.loadBooks(for: 1234)
        let reference = try #require(ScriptureReference(translationID: 1234,
                                                        bookCode: "GEN",
                                                        chapter: 1))

        #expect(catalogStore.friendlyPassageName(for: reference, selectedVerses: 5...5) == "Genesis 1:5")
    }

    /// A multi-verse range shows both bounds
    @Test func friendlyPassageNameShowsVerseRange() async throws {
        let catalogStore = BibleCatalogStore(repository: FakeBibleRepository())
        try await catalogStore.loadBooks(for: 1234)
        let reference = try #require(ScriptureReference(translationID: 1234,
                                                        bookCode: "GEN",
                                                        chapter: 1))

        #expect(catalogStore.friendlyPassageName(for: reference, selectedVerses: 1...3) == "Genesis 1:1–3")
    }

    // MARK: Fixtures (Cache)

    private static let currentBuildNumber = "100"
    private static let otherBuildNumber = "99"

    /// Mirrors BibleCatalogStore.maximumCacheAgeInDays (private there)
    private static let maximumCacheAgeInDays = 7

    /// Cache and repository lists differ so assertions show which source the store used
    private static let cachedTranslations = Array(FakeBibleRepository.defaultTranslations.suffix(1))
    private static let repositoryTranslations = FakeBibleRepository.defaultTranslations
    private static let cachedBooks = FakeBibleRepository.booksWithoutChapters
    private static let repositoryBooks = FakeBibleRepository.defaultBooks

    // MARK: Functions (Private Helpers)

    private func makeStore(repository: StubBibleRepository,
                           catalogCache: InMemoryCatalogCache) -> BibleCatalogStore {
        BibleCatalogStore(repository: repository,
                          catalogCache: catalogCache,
                          appBuildNumber: Self.currentBuildNumber)
    }

    private func makeEntry<Value: Codable>(_ value: Value,
                                           ageInDays: Int = 0,
                                           buildNumber: String = BibleCatalogStoreTests.currentBuildNumber) -> CatalogCacheEntry<Value> {
        let createdOn = Calendar.current.date(byAdding: .day, value: -ageInDays, to: .now) ?? .now
        return CatalogCacheEntry(value: value,
                                 createdOn: createdOn,
                                 createdByBuildNumber: buildNumber)
    }

    private func makeAnnotation(startVerse: Int,
                                endVerse: Int? = nil) -> VerseAnnotation {
        VerseAnnotation(id: UUID(),
                        translationID: 1234,
                        bookCode: "GEN",
                        chapter: 1,
                        startVerse: startVerse,
                        endVerse: endVerse,
                        content: .note("Test note"),
                        createdAt: .now)
    }
}

/// Private fake dummy data implementation for BibleCatalogStoreTests ONLY
/// Differs from FakeBibleRepository in that Stub* implements failure state + per-translation routing
private final class StubBibleRepository: BibleRepository {
    enum RepositoryError: Error {
        case unsupportedOperation
    }
    
    let translations: [Translation]
    let booksByTranslation: [Translation.ID: [Book]]
    var failsLoadingTranslations = false
    var failingTranslationIDs: Set<Translation.ID> = []

    /// Call counts; 0 proves the store answered from cache without touching the network
    private(set) var translationsCallCount = 0
    private(set) var booksCallCount = 0

    init(translations: [Translation] = [],
         booksByTranslation: [Translation.ID: [Book]] = [:]) {
        self.translations = translations
        self.booksByTranslation = booksByTranslation
    }

    func translations(languageTag: String?) async throws -> [Translation] {
        translationsCallCount += 1

        if failsLoadingTranslations {
            throw RepositoryError.unsupportedOperation
        }

        return translations
    }

    func books(for translationID: Translation.ID) async throws -> [Book] {
        booksCallCount += 1

        if failingTranslationIDs.contains(translationID) {
            throw RepositoryError.unsupportedOperation
        }
        
        return booksByTranslation[translationID] ?? []
    }
    
    func passage(for reference: ScriptureReference) async throws -> Passage {
        throw RepositoryError.unsupportedOperation
    }
}
