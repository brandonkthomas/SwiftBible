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

    /// ReaderStore initial loadState = idle & selectedReference = nil
    @Test func readerStoreStartsIdle() {
        let store = readerStore()

        #expect(store.loadState == .idle)
        #expect(store.selectedReference == nil)
    }

    /// Loading translations should select the first translation, book, and chapter.
    @Test func loadTranslationsSelectsInitialReferences() async {
        let store = readerStore()

        await store.loadTranslationsAndBooks(languageTag: "en")

        #expect(store.loadState == .loaded)

        #expect(store.selectedTranslation != nil)
        #expect(store.selectedTranslation == store.translations.first)

        #expect(store.selectedBook != nil)
        #expect(store.selectedBook == store.books.first)

        #expect(store.selectedChapter != nil)
        #expect(store.selectedChapter == store.selectedBook?.chapters.first)

        #expect(store.selectedReference?.translationID == store.selectedTranslation?.id)
        #expect(store.selectedReference?.bookCode == store.selectedBook?.code)
        #expect(store.selectedReference?.chapter == store.selectedChapter?.number)
    }

    /// Loading a book without chapters should stop in the empty chapters state.
    @Test func loadTranslationsWithBookWithoutChaptersStopsAtEmptyChapters() async {
        let repository = FakeBibleRepository(books: FakeBibleRepository.booksWithoutChapters)
        let store = ReaderStore(repository: repository,
                                catalogStore: BibleCatalogStore(repository: repository),
                                libraryRepository: InMemoryLibraryRepository())

        await store.loadTranslationsAndBooks(languageTag: "en")

        #expect(store.loadState == .emptyChapters)
        #expect(store.selectedTranslation == store.translations.first)
        #expect(store.selectedBook == nil)
        #expect(store.selectedChapter == nil)
    }

    /// No translations matches expected state;
    /// no selected translation/book/chapter
    @Test func noTranslationsReturned() async {
        let repository = FakeBibleRepository(translations: [])
        let store = ReaderStore(repository: repository,
                                catalogStore: BibleCatalogStore(repository: repository),
                                libraryRepository: InMemoryLibraryRepository())

        await store.loadTranslationsAndBooks(languageTag: "en")

        #expect(store.loadState == .emptyTranslations)
        #expect(store.selectedTranslation == nil)
        #expect(store.selectedBook == nil)
        #expect(store.selectedChapter == nil)
    }

    /// No books matches expected state;
    /// no selected book/chapter
    @Test func noBooksReturned() async {
        let repository = FakeBibleRepository(books: [])
        let store = ReaderStore(repository: repository,
                                catalogStore: BibleCatalogStore(repository: repository),
                                libraryRepository: InMemoryLibraryRepository())

        await store.loadTranslationsAndBooks(languageTag: "en")

        #expect(store.loadState == .emptyBooks)
        #expect(store.selectedTranslation == store.translations.first)
        #expect(store.selectedBook == nil)
        #expect(store.selectedChapter == nil)
    }

    /// Exceptions thrown in protocol implementations will set failed status
    /// and clear data
    @Test func selectionsClearedOnLoadTranslationsThrow() async {
        let repository = FakeBibleRepository(throwWhenLoadingTranslations: true)
        let store = ReaderStore(repository: repository,
                                catalogStore: BibleCatalogStore(repository: repository),
                                libraryRepository: InMemoryLibraryRepository())

        await store.loadTranslationsAndBooks(languageTag: "en")

        #expect(store.loadState == .failed("An error occurred while loading Bibles."))

        #expect(store.translations == [])
        #expect(store.selectedTranslation == nil)
        #expect(store.books == [])
        #expect(store.selectedBook == nil)
        #expect(store.selectedChapter == nil)
        #expect(store.selectedReference == nil)
    }

    /// selectBookAndChapter() functions as intended
    /// (persists selected book/chapter IDs to store's selectedBook and selectedChapter fields)
    @Test func selectBookAndChapterSucceeds() async {
        let store = readerStore()

        #expect(store.selectedReference == nil)

        await store.loadTranslationsAndBooks(languageTag: "en")

        guard let book = FakeBibleRepository.defaultBooks.first,
              let firstChapter = book.chapters.first,
              let lastChapter = book.chapters.last,
              firstChapter != lastChapter else {
            #expect(Bool(false), "fixture should contain at least 1 book with 2+ chapters")
            return
        }

        #expect(store.loadState == .loaded)

        #expect(store.selectedBook == book)
        #expect(store.selectedChapter == firstChapter)

        await store.selectBookAndChapter(bookID: book.id,
                                         chapterID: lastChapter.id,
                                         reloadPassage: true)

        #expect(store.loadState == .loaded)
        #expect(store.selectedBook == book)
        #expect(store.selectedChapter == lastChapter)

        #expect(store.selectedReference?.translationID == store.selectedTranslation?.id)
        #expect(store.selectedReference?.bookCode == store.selectedBook?.code)
        #expect(store.selectedReference?.chapter == store.selectedChapter?.number)
    }

    /// loadSelectedPassage() functions as intended
    @Test func loadSelectedPassageSucceeds() async {
        let store = readerStore()

        await store.loadTranslationsAndBooks(languageTag: "en")

        await store.loadSelectedPassage()

        #expect(store.passageLoadState == .loaded)
        #expect(store.selectedPassage?.id == "GEN.1")
        #expect(store.selectedPassage?.htmlContent.isEmpty == false)
    }

    /// load passage, change chapter/book, verify selectedPassage becomes nil
    /// and passageLoadState becomes idle again
    @Test func changeSelectedChapterInvalidatesSelectedPassage() async {
        let store = readerStore()

        await store.loadTranslationsAndBooks(languageTag: "en")

        await store.loadSelectedPassage()

        #expect(store.passageLoadState == .loaded)
        #expect(store.selectedPassage?.id == "GEN.1")
        #expect(store.selectedPassage?.htmlContent.isEmpty == false)

        await store.selectBookAndChapter(bookID: "GEN",
                                         chapterID: "GEN.2",
                                         reloadPassage: false)

        #expect(store.passageLoadState == .idle)
        #expect(store.selectedPassage == nil)
    }

    /// single verse selection is properly reflected in .selectedVerses
    @Test func singleVerseSelectionCreatesSingleVerseRange() {
        let store = readerStore()

        store.handleVerseSelection(startVerse: 5, endVerse: nil)
        #expect(store.selectedVerses == 5...5)
    }

    /// Selecting a verse further forward in the range extends .selectedVerses forward
    @Test func forwardSelectionExtendsUpperRange() {
        let store = readerStore()

        store.selectedVerses = 5...5
        store.handleVerseSelection(startVerse: 8, endVerse: nil)
        #expect(store.selectedVerses == 5...8)
    }

    /// Selecting a verse further backward in the range extends .selectedVerses backward
    @Test func backwardSelectionExtendsLowerRange() {
        let store = readerStore()

        store.selectedVerses = 5...5
        store.handleVerseSelection(startVerse: 2, endVerse: nil)
        #expect(store.selectedVerses == 2...5)
    }

    /// Selecting a verse inside the current range shrinks the current range to only the tapped verse
    @Test func selectionChangeInsideCurrentRangeCollapsesSelection() {
        let store = readerStore()

        store.selectedVerses = 3...8
        store.handleVerseSelection(startVerse: 5, endVerse: nil)
        #expect(store.selectedVerses == 5...5)
    }

    /// Selecting a verse where the current range matches identically sets .selectedVerses to nil
    @Test func selectingCurrentRangeExactlyDeselects() {
        let store = readerStore()

        store.selectedVerses = 5...5
        store.handleVerseSelection(startVerse: 5, endVerse: nil)
        #expect(store.selectedVerses == nil)
    }

    /// Saving a highlight via the save() method successfully saves to LibraryRepository
    /// then updates the ReaderStore's passageHighlightColors dict
    @Test func savingHighlightsPersistsToStore() async {
        let store = readerStore()
        await store.loadTranslationsAndBooks()

        store.selectedVerses = 1...1
        store.save(.highlight(.yellow))
        #expect(store.selectedVerses == nil)
        #expect(store.passageHighlightColors[1] == .yellow)
    }

    /// Saving a highlight via the save() method successfully saves to LibraryRepository
    /// then updates the ReaderStore's passageHighlightColors dict
    @Test func deletingHighlightsPersistsToStore() async {
        let store = readerStore()
        await store.loadTranslationsAndBooks()

        store.selectedVerses = 1...1
        store.save(.highlight(.yellow))

        store.selectedVerses = 1...1
        store.deleteHighlights()
        #expect(store.passageHighlightColors.count == 0)
    }
    
    /// if book load fails, old passage information should be cleared
    @Test func failedBookReloadClearsStalePassageState() async {
        let repository = FakeBibleRepository()
        let store = ReaderStore(repository: repository,
                                catalogStore: BibleCatalogStore(repository: repository),
                                libraryRepository: InMemoryLibraryRepository())
        
        await store.loadTranslationsAndBooks(languageTag: "en")
        await store.loadSelectedPassage()
        
        #expect(store.passageLoadState == .loaded)
        #expect(store.selectedPassage?.id == "GEN.1")
        
        store.selectedVerses = 1...1
        
        // now we need to simulate a failure
        repository.throwWhenLoadingBooks = true
        
        guard let translationID = store.selectedTranslation?.id else {
            Issue.record("Expected an initially selected translation")
            return
        }
        
        // loadTranslationsAndBooks wont work again here since it guards state != .loaded;
        // use this method instead for subsequent book loads
        await store.selectTranslationAndReloadAll(id: translationID)
        
        if case .failed = store.loadState {
            // expect to fail
        } else {
            Issue.record("Expected loadState to be failed")
        }
        #expect(store.selectedBook == nil)
        #expect(store.selectedChapter == nil)
        #expect(store.selectedPassage == nil)
        #expect(store.selectedRenderedPassage == nil)
        #expect(store.selectedVerses == nil)
        #expect(store.passageLoadState == .idle)
        #expect(store.passageHighlightColors.isEmpty)
    }

    // MARK: Functions (Private)

    private func readerStore() -> ReaderStore {
        let repository = FakeBibleRepository()
        return ReaderStore(repository: repository,
                           catalogStore: BibleCatalogStore(repository: repository),
                           libraryRepository: InMemoryLibraryRepository())
    }
}
