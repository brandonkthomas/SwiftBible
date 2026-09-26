//
//  InMemoryPassageCacheTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-09-25.
//

import Testing
@testable import SwiftBible

@MainActor // required so line 16 doesnt fail
struct InMemoryPassageCacheTests {

    /// Cache misses return nil and do not throw (only disk read errors can/should throw)
    @Test func missReturnsNilAndDoesNotThrow() async throws {
        let cache = InMemoryPassageCache()

        let key = BiblePassageKey(translationID: 1234,
                                  bookCode: "GEN",
                                  chapter: 1)

        #expect(try await cache.passage(for: key) == nil)
    }

    /// Saving then reading the same key returns the saved passage
    @Test func saveThenReadReturnsPassage() async throws {
        let cache = InMemoryPassageCache()

        let key = BiblePassageKey(translationID: 1234,
                                  bookCode: "GEN",
                                  chapter: 1)
        let passage = Passage(id: "GEN.1",
                              reference: "Test",
                              htmlContent: "<div></div>")

        try await cache.save(passage, for: key)
        #expect(try await cache.passage(for: key) == passage) // works due to Equatable
    }

    /// Saving another passage to the same key overwrites that cache entry
    @Test func savingTwiceReplaces() async throws {
        let cache = InMemoryPassageCache()

        let key1 = BiblePassageKey(translationID: 1234,
                                   bookCode: "GEN",
                                   chapter: 1)
        let passage1 = Passage(id: "GEN.1",
                               reference: "Test",
                               htmlContent: "<div></div>")

        let passage2 = Passage(id: "GEN.1",
                               reference: "Test",
                               htmlContent: "<div>Hello</div>")

        try await cache.save(passage1, for: key1)
        #expect(try await cache.passage(for: key1) == passage1)
        try await cache.save(passage2, for: key1)
        #expect(try await cache.passage(for: key1) == passage2)
    }
}
