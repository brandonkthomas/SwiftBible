//
//  ReaderStoreTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 6/27/26.
//

import Foundation
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
        let passageStore = BiblePassageStore(repository: repository,
                                             passageCache: InMemoryPassageCache())
        let readerStore = ReaderStore(passageStore: passageStore,
                                      catalogStore: BibleCatalogStore(repository: repository),
                                      preferencesStore: PreferencesStore(userDefaults: userDefaults()),
                                      libraryRepository: InMemoryLibraryRepository())

        await readerStore.loadTranslationsAndBooks(languageTag: "en")

        #expect(readerStore.loadState == .emptyChapters)
        #expect(readerStore.selectedTranslation == readerStore.translations.first)
        #expect(readerStore.selectedBook == nil)
        #expect(readerStore.selectedChapter == nil)
    }

    /// No translations matches expected state;
    /// no selected translation/book/chapter
    @Test func noTranslationsReturned() async {
        let repository = FakeBibleRepository(translations: [])
        let passageStore = BiblePassageStore(repository: repository,
                                             passageCache: InMemoryPassageCache())
        let readerStore = ReaderStore(passageStore: passageStore,
                                      catalogStore: BibleCatalogStore(repository: repository),
                                      preferencesStore: PreferencesStore(userDefaults: userDefaults()),
                                      libraryRepository: InMemoryLibraryRepository())

        await readerStore.loadTranslationsAndBooks(languageTag: "en")

        #expect(readerStore.loadState == .emptyTranslations)
        #expect(readerStore.selectedTranslation == nil)
        #expect(readerStore.selectedBook == nil)
        #expect(readerStore.selectedChapter == nil)
    }

    /// No books matches expected state;
    /// no selected book/chapter
    @Test func noBooksReturned() async {
        let repository = FakeBibleRepository(books: [])
        let passageStore = BiblePassageStore(repository: repository,
                                             passageCache: InMemoryPassageCache())
        let readerStore = ReaderStore(passageStore: passageStore,
                                      catalogStore: BibleCatalogStore(repository: repository),
                                      preferencesStore: PreferencesStore(userDefaults: userDefaults()),
                                      libraryRepository: InMemoryLibraryRepository())

        await readerStore.loadTranslationsAndBooks(languageTag: "en")

        #expect(readerStore.loadState == .emptyBooks)
        #expect(readerStore.selectedTranslation == readerStore.translations.first)
        #expect(readerStore.selectedBook == nil)
        #expect(readerStore.selectedChapter == nil)
    }

    /// Exceptions thrown in protocol implementations will set failed status
    /// and clear data
    @Test func selectionsClearedOnLoadTranslationsThrow() async {
        let repository = FakeBibleRepository(throwWhenLoadingTranslations: true)
        let passageStore = BiblePassageStore(repository: repository,
                                             passageCache: InMemoryPassageCache())
        let readerStore = ReaderStore(passageStore: passageStore,
                                      catalogStore: BibleCatalogStore(repository: repository),
                                      preferencesStore: PreferencesStore(userDefaults: userDefaults()),
                                      libraryRepository: InMemoryLibraryRepository())

        await readerStore.loadTranslationsAndBooks(languageTag: "en")

        #expect(readerStore.loadState == .failed("An error occurred while loading Bibles."))

        #expect(readerStore.translations == [])
        #expect(readerStore.selectedTranslation == nil)
        #expect(readerStore.books == [])
        #expect(readerStore.selectedBook == nil)
        #expect(readerStore.selectedChapter == nil)
        #expect(readerStore.selectedReference == nil)
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
    
    /// if a book load fails with no cached copy (first offline load of a new translation),
    /// old passage information should be cleared
    @Test func failedBookReloadClearsStalePassageState() async {
        let repository = FakeBibleRepository()
        let passageStore = BiblePassageStore(repository: repository,
                                             passageCache: InMemoryPassageCache())
        let readerStore = ReaderStore(passageStore: passageStore,
                                      catalogStore: BibleCatalogStore(repository: repository),
                                      preferencesStore: PreferencesStore(userDefaults: userDefaults()),
                                      libraryRepository: InMemoryLibraryRepository())
        
        await readerStore.loadTranslationsAndBooks(languageTag: "en")
        await readerStore.loadSelectedPassage()

        #expect(readerStore.passageLoadState == .loaded)
        #expect(readerStore.selectedPassage?.id == "GEN.1")

        readerStore.selectedVerses = 1...1

        // Only 1234's books were loaded (and cached). Switching to 1849 while the network
        // fails matches a first offline load of a new translation: no cached copy, so it fails
        #expect(readerStore.selectedTranslation?.id == 1234)
        repository.throwWhenLoadingBooks = true
        let uncachedTranslationID = 1849

        // loadTranslationsAndBooks wont work again here since it guards state != .loaded;
        // use this method instead for subsequent book loads
        await readerStore.selectTranslationAndReloadAll(id: uncachedTranslationID)

        if case .failed = readerStore.loadState {
            // expect to fail
        } else {
            Issue.record("Expected loadState to be failed")
        }
        #expect(readerStore.selectedBook == nil)
        #expect(readerStore.selectedChapter == nil)
        #expect(readerStore.selectedPassage == nil)
        #expect(readerStore.selectedRenderedPassage == nil)
        #expect(readerStore.selectedVerses == nil)
        #expect(readerStore.passageLoadState == .idle)
        #expect(readerStore.passageHighlightColors.isEmpty)
        #expect(readerStore.passageVersesWithTextAnnotations.isEmpty)
    }

    /// A highlight deleted outside ReaderStore (i.e. from LibraryView) disappears
    /// from passageHighlightColors after refreshPassageHighlights()
    @Test func externallyDeletedHighlightDisappearsAfterRefresh() async throws {
        let libraryRepository = InMemoryLibraryRepository()
        let store = readerStore(libraryRepository: libraryRepository)
        await store.loadTranslationsAndBooks()

        store.selectedVerses = 1...1
        store.save(.highlight(.yellow))
        #expect(store.passageHighlightColors[1] == .yellow)

        // delete directly through the repository, bypassing ReaderStore
        let annotation = try #require(try libraryRepository.allAnnotations().first)
        try libraryRepository.delete(annotation.id)

        store.refreshPassageHighlights()

        #expect(store.passageHighlightColors[1] == nil)
        #expect(store.passageHighlightColors.isEmpty)
    }

    /// Deleting an annotation from another chapter, then refreshing, leaves the
    /// current chapter's highlight colors unchanged
    @Test func refreshAfterUnrelatedDeleteLeavesCurrentColorsUnchanged() async throws {
        let libraryRepository = InMemoryLibraryRepository()
        let store = readerStore(libraryRepository: libraryRepository)
        await store.loadTranslationsAndBooks()

        store.selectedVerses = 1...1
        store.save(.highlight(.yellow))
        store.selectedVerses = 2...3
        store.save(.highlight(.green))

        // unrelated highlight in a different chapter of the same book
        let reference = try #require(store.selectedReference)
        let unrelatedAnnotation = VerseAnnotation(id: UUID(),
                                                  translationID: reference.translationID,
                                                  bookCode: reference.bookCode,
                                                  chapter: reference.chapter + 1,
                                                  startVerse: 1,
                                                  endVerse: nil,
                                                  content: .highlight(.pink),
                                                  createdAt: .now)
        try libraryRepository.save(unrelatedAnnotation)

        store.refreshPassageHighlights()
        let colorsBeforeDelete = store.passageHighlightColors
        #expect(colorsBeforeDelete == [1: .yellow, 2: .green, 3: .green])

        try libraryRepository.delete(unrelatedAnnotation.id)
        store.refreshPassageHighlights()

        #expect(store.passageHighlightColors == colorsBeforeDelete)
    }

    /// A note seeded in the repository surfaces in passageVersesWithTextAnnotations
    /// once its passage is loaded
    @Test func seededNoteAppearsInPassageVersesWithTextAnnotations() async throws {
        let libraryRepository = InMemoryLibraryRepository()
        let niv = try translation(abbreviation: "NIV")
        let note = VerseAnnotation(id: UUID(),
                                   translationID: niv.id,
                                   bookCode: "GEN",
                                   chapter: 1,
                                   startVerse: 2,
                                   endVerse: nil,
                                   content: .note("In the beginning"),
                                   createdAt: .now)
        try libraryRepository.save(note)

        let store = readerStore(libraryRepository: libraryRepository)
        await store.loadTranslationsAndBooks(languageTag: "en")
        await store.loadSelectedPassage()

        #expect(store.passageVersesWithTextAnnotations == [2])
    }

    /// Tapping a verse label inside a ranged note opens an editor for the note's full range
    @Test func annotatedVerseEditorUsesFullAnnotationRange() async throws {
        let libraryRepository = InMemoryLibraryRepository()
        let niv = try translation(abbreviation: "NIV")
        let note = VerseAnnotation(id: UUID(),
                                   translationID: niv.id,
                                   bookCode: "GEN",
                                   chapter: 1,
                                   startVerse: 2,
                                   endVerse: 3,
                                   content: .note("In the beginning"),
                                   createdAt: .now)
        try libraryRepository.save(note)

        let store = readerStore(libraryRepository: libraryRepository)
        await store.loadTranslationsAndBooks(languageTag: "en")
        await store.loadSelectedPassage()

        let editor = try #require(store.makeAnnotationEditor(forAnnotatedVerse: 3))

        #expect(editor.selectedVerses == 2...3)
    }

    // MARK: Reader Position Restoration

    /// A saved position whose translation, book and chapter all exist is restored at launch
    ///
    /// Books are reversed so Exodus (no chapters) is first; if the saved book weren't
    /// restored, the first-book fallback would land on .emptyChapters instead of Genesis
    @Test func savedPositionIsRestored() async throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let preferencesStore = PreferencesStore(userDefaults: userDefaults)
        preferencesStore.readerPosition = ReaderPosition(translationID: 1849, bookCode: "GEN", chapter: 2)

        let store = readerStore(preferencesStore: preferencesStore,
                                books: FakeBibleRepository.defaultBooks.reversed())
        await store.loadTranslationsAndBooks(languageTag: "en")

        #expect(store.loadState == .loaded)
        #expect(store.selectedTranslation?.abbreviation == "TPT")
        #expect(store.selectedBook?.displayName == "Genesis")
        #expect(store.selectedChapter?.number == 2)
    }

    /// A saved translation that no longer exists falls back to NIV, Genesis 1
    @Test func savedTranslationMissingFallsBackToNIV() async throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let preferencesStore = PreferencesStore(userDefaults: userDefaults)
        preferencesStore.readerPosition = ReaderPosition(translationID: 9999, bookCode: "GEN", chapter: 2)

        let store = readerStore(preferencesStore: preferencesStore)
        await store.loadTranslationsAndBooks(languageTag: "en")

        #expect(store.loadState == .loaded)
        #expect(store.selectedTranslation?.abbreviation == "NIV")
        #expect(store.selectedBook?.displayName == "Genesis")
        #expect(store.selectedChapter?.number == 1)
    }

    /// With nothing saved, NIV is selected even when it isn't the first translation
    @Test func nothingSavedSelectsNIVWhenNotFirst() async throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let tpt = try translation(abbreviation: "TPT")
        let niv = try translation(abbreviation: "NIV")

        let store = readerStore(preferencesStore: PreferencesStore(userDefaults: userDefaults),
                                translations: [tpt, niv])
        await store.loadTranslationsAndBooks(languageTag: "en")

        #expect(store.loadState == .loaded)
        #expect(store.translations.first == tpt)
        #expect(store.selectedTranslation == niv)
    }

    /// With nothing saved and no NIV available, the first translation is selected
    @Test func nothingSavedWithoutNIVSelectsFirstTranslation() async throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let tpt = try translation(abbreviation: "TPT")

        let store = readerStore(preferencesStore: PreferencesStore(userDefaults: userDefaults),
                                translations: [tpt])
        await store.loadTranslationsAndBooks(languageTag: "en")

        #expect(store.loadState == .loaded)
        #expect(store.selectedTranslation == tpt)
    }

    /// A saved chapter that doesn't exist in the saved book falls back to chapter 1
    @Test func savedChapterMissingFallsBackToFirstChapter() async throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let preferencesStore = PreferencesStore(userDefaults: userDefaults)
        preferencesStore.readerPosition = ReaderPosition(translationID: 1234, bookCode: "GEN", chapter: 99)

        let store = readerStore(preferencesStore: preferencesStore)
        await store.loadTranslationsAndBooks(languageTag: "en")

        #expect(store.loadState == .loaded)
        #expect(store.selectedTranslation?.abbreviation == "NIV")
        #expect(store.selectedBook?.displayName == "Genesis")
        #expect(store.selectedChapter?.number == 1)
    }

    /// A successful passage load saves the position; a second PreferencesStore
    /// on the same suite reads it back
    @Test func successfulPassageLoadSavesPosition() async throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = readerStore(preferencesStore: PreferencesStore(userDefaults: userDefaults))
        await store.loadTranslationsAndBooks(languageTag: "en")
        await store.loadSelectedPassage()

        #expect(store.passageLoadState == .loaded)

        let secondPreferencesStore = PreferencesStore(userDefaults: userDefaults)
        #expect(secondPreferencesStore.readerPosition == ReaderPosition(translationID: 1234,
                                                                        bookCode: "GEN",
                                                                        chapter: 1))
    }

    // MARK: Functions (Private)

    private func readerStore(
        libraryRepository: any LibraryRepository = InMemoryLibraryRepository(),
        preferencesStore: PreferencesStore? = nil,
        translations: [Translation] = FakeBibleRepository.defaultTranslations,
        books: [Book] = FakeBibleRepository.defaultBooks
    ) -> ReaderStore {
        let repository = FakeBibleRepository(translations: translations, books: books)
        let passageStore = BiblePassageStore(repository: repository,
                                             passageCache: InMemoryPassageCache())
        return ReaderStore(passageStore: passageStore,
                           catalogStore: BibleCatalogStore(repository: repository),
                           preferencesStore: preferencesStore ?? PreferencesStore(userDefaults: userDefaults()),
                           libraryRepository: libraryRepository)
    }

    /// Looks up a fixture translation by abbreviation
    private func translation(abbreviation: String) throws -> Translation {
        try #require(FakeBibleRepository.defaultTranslations.first { $0.abbreviation == abbreviation })
    }

    private func userDefaults() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString)!
    }
}
