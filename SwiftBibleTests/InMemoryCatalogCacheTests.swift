//
//  InMemoryCatalogCacheTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-10-21.
//

import Testing
@testable import SwiftBible

@MainActor // required so InMemoryCatalogCache() doesnt fail
struct InMemoryCatalogCacheTests {

    // MARK: Translations

    /// Translation cache misses return nil and do not throw (only disk read errors can/should throw)
    @Test func translationMissReturnsNilAndDoesNotThrow() async throws {
        let cache = InMemoryCatalogCache()

        #expect(try await cache.translations(for: "en") == nil)
    }

    /// Saving then reading the same language tag returns the saved translations
    @Test func saveThenReadReturnsTranslations() async throws {
        let cache = InMemoryCatalogCache()
        let translations = FakeBibleRepository.defaultTranslations

        try await cache.save(translations, for: "en")
        #expect(try await cache.translations(for: "en") == translations) // works due to Equatable
    }

    /// Saving other translations to the same language tag overwrites that cache entry
    @Test func savingTranslationsTwiceReplaces() async throws {
        let cache = InMemoryCatalogCache()
        let translations1 = FakeBibleRepository.defaultTranslations
        let translations2: [Translation] = []

        try await cache.save(translations1, for: "en")
        #expect(try await cache.translations(for: "en") == translations1)
        try await cache.save(translations2, for: "en")
        #expect(try await cache.translations(for: "en") == translations2)
    }

    // MARK: Books

    /// Book cache misses return nil and do not throw (only disk read errors can/should throw)
    @Test func bookMissReturnsNilAndDoesNotThrow() async throws {
        let cache = InMemoryCatalogCache()

        #expect(try await cache.books(for: 1234) == nil)
    }

    /// Saving then reading the same translation ID returns the saved books
    @Test func saveThenReadReturnsBooks() async throws {
        let cache = InMemoryCatalogCache()
        let books = FakeBibleRepository.defaultBooks

        try await cache.save(books, for: 1234)
        #expect(try await cache.books(for: 1234) == books) // works due to Equatable
    }

    /// Saving other books to the same translation ID overwrites that cache entry
    @Test func savingBooksTwiceReplaces() async throws {
        let cache = InMemoryCatalogCache()
        let books1 = FakeBibleRepository.defaultBooks
        let books2: [Book] = []

        try await cache.save(books1, for: 1234)
        #expect(try await cache.books(for: 1234) == books1)
        try await cache.save(books2, for: 1234)
        #expect(try await cache.books(for: 1234) == books2)
    }
}
