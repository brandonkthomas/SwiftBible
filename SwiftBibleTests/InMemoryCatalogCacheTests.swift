//
//  InMemoryCatalogCacheTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-10-21.
//

import Testing
import Foundation
@testable import SwiftBible

@MainActor // required so InMemoryCatalogCache() doesnt fail
struct InMemoryCatalogCacheTests {

    // MARK: Translations

    /// Translation cache misses return nil and do not throw (only disk read errors can/should throw)
    @Test func translationMissReturnsNilAndDoesNotThrow() async throws {
        let cache = InMemoryCatalogCache()

        #expect(try await cache.translations(for: "en") == nil)
    }

    /// Saving then reading the same language tag returns the saved entry
    @Test func saveThenReadReturnsTranslations() async throws {
        let cache = InMemoryCatalogCache()
        let entry = makeEntry(FakeBibleRepository.defaultTranslations)

        try await cache.save(entry, for: "en")
        let saved = try #require(try await cache.translations(for: "en"))

        #expect(saved.value == entry.value) // works due to Equatable
        #expect(saved.createdOn == entry.createdOn)
        #expect(saved.createdByBuildNumber == entry.createdByBuildNumber)
    }

    /// Saving other translations to the same language tag overwrites that cache entry
    @Test func savingTranslationsTwiceReplaces() async throws {
        let cache = InMemoryCatalogCache()
        let entry1 = makeEntry(FakeBibleRepository.defaultTranslations)
        let entry2 = makeEntry([Translation]())

        try await cache.save(entry1, for: "en")
        #expect(try await cache.translations(for: "en")?.value == entry1.value)
        try await cache.save(entry2, for: "en")
        #expect(try await cache.translations(for: "en")?.value == entry2.value)
    }

    // MARK: Books

    /// Book cache misses return nil and do not throw (only disk read errors can/should throw)
    @Test func bookMissReturnsNilAndDoesNotThrow() async throws {
        let cache = InMemoryCatalogCache()

        #expect(try await cache.books(for: 1234) == nil)
    }

    /// Saving then reading the same translation ID returns the saved entry
    @Test func saveThenReadReturnsBooks() async throws {
        let cache = InMemoryCatalogCache()
        let entry = makeEntry(FakeBibleRepository.defaultBooks)

        try await cache.save(entry, for: 1234)
        let saved = try #require(try await cache.books(for: 1234))

        #expect(saved.value == entry.value) // works due to Equatable
        #expect(saved.createdOn == entry.createdOn)
        #expect(saved.createdByBuildNumber == entry.createdByBuildNumber)
    }

    /// Saving other books to the same translation ID overwrites that cache entry
    @Test func savingBooksTwiceReplaces() async throws {
        let cache = InMemoryCatalogCache()
        let entry1 = makeEntry(FakeBibleRepository.defaultBooks)
        let entry2 = makeEntry([Book]())

        try await cache.save(entry1, for: 1234)
        #expect(try await cache.books(for: 1234)?.value == entry1.value)
        try await cache.save(entry2, for: 1234)
        #expect(try await cache.books(for: 1234)?.value == entry2.value)
    }

    // MARK: Private Helpers

    /// Fixed date and build number so comparisons don't depend on the wall clock or bundle
    private func makeEntry<Value: Codable>(_ value: Value) -> CatalogCacheEntry<Value> {
        CatalogCacheEntry(value: value,
                          createdOn: Date(timeIntervalSinceReferenceDate: 815_000_000),
                          createdByBuildNumber: "42")
    }
}
