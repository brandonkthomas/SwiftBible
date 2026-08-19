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
}
