//
//  BibleCatalogStoreTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-08-13.
//

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

    @Test func failedBookLoadPreservesCachedBooksForTranslation() async throws {
        let translationID = 1234
        let expectedBooks = FakeBibleRepository.defaultBooks
        let repository = StubBibleRepository(booksByTranslation: [translationID: expectedBooks])
        let catalogStore = BibleCatalogStore(repository: repository)
        try await catalogStore.loadBooks(for: translationID)
        repository.failingTranslationIDs.insert(translationID)

        await #expect(throws: StubBibleRepository.RepositoryError.self) {
            try await catalogStore.loadBooks(for: translationID)
        }

        #expect(catalogStore.books(for: translationID) == expectedBooks)
    }
}

/// Private fake dummy data implementation for BibleCatalogStoreTests ONLY
/// Differs from FakeBibleRepository in that Stub* implements failure state + per-translation routing
private final class StubBibleRepository: BibleRepository {
    enum RepositoryError: Error {
        case unsupportedOperation
    }
    
    let booksByTranslation: [Translation.ID: [Book]]
    var failingTranslationIDs: Set<Translation.ID> = []
    
    init(booksByTranslation: [Translation.ID: [Book]]) {
        self.booksByTranslation = booksByTranslation
    }
    
    func translations(languageTag: String?) async throws -> [Translation] {
        []
    }
    
    func books(for translationID: Translation.ID) async throws -> [Book] {
        if failingTranslationIDs.contains(translationID) {
            throw RepositoryError.unsupportedOperation
        }
        
        return booksByTranslation[translationID] ?? []
    }
    
    func passage(for reference: ScriptureReference) async throws -> Passage {
        throw RepositoryError.unsupportedOperation
    }
}
