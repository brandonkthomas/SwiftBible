//
//  ReaderStoreTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 6/27/26.
//

import Testing
@testable import SwiftBible

// for testing only; Swift warns about main-actor default isolation,
// and ReaderStore is observable UI state; use @MainActor to run these on UI actor
@MainActor
struct ReaderStoreTests {

    /// ReaderStore loadState is idle initially
    @Test func readerStoreStartsIdle() {
        let repository = FakeBibleRepository()
        let store = ReaderStore(repository: repository)

        #expect(store.loadState == .idle)
    }

    /// Loading Translations should select first Translation initially
    @Test func loadTranslationsSelectsInitialReferences() async {
        let repository = FakeBibleRepository()
        let store = ReaderStore(repository: repository)

        await store.loadTranslations(languageTag: "en")

        #expect(store.loadState == .emptyChapters)

        #expect(store.selectedTranslation != nil)
        #expect(store.selectedTranslation == store.translations.first)

        #expect(store.selectedBook != nil)
        #expect(store.selectedBook == store.books.first)

        #expect(store.selectedChapter == nil)
    }
}
