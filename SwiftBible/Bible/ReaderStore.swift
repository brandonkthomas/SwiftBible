//
//  ReaderStore.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import Observation
import OSLog

/// Flow: BibleRepository -> ReaderStore -> ReaderView / picker UI
///
/// Owns:
/// - available translations
/// - selected translation
/// - available books for that translation
/// - selected book
/// - selected chapter
/// - loading state
/// - error state
/// - TODO: selected verse range, last-read restoration, next/previous chapter behavior
@Observable
final class ReaderStore {

    // MARK: Properties

    // State
    var loadState: ReaderLoadState = .idle
    var passageLoadState: PassageLoadState = .idle

    // Collections
    var translations: [Translation] = []
    var books: [Book] = []

    // Selections
    var selectedTranslation: Translation?
    var selectedBook: Book?
    var selectedChapter: Chapter?
    var selectedPassage: Passage?

    var selectedReference: ScriptureReference? {
        get {
            guard let selectedTranslation,
                  let selectedBook,
                  let selectedChapter else {
                return nil
            }
            return ScriptureReference(translationID: selectedTranslation.id,
                                      bookCode: selectedBook.code,
                                      chapter: selectedChapter.number,
                                      startVerse: nil,
                                      endVerse: nil)
        }
    }

    var selectedReferenceFriendlyName: String? {
        guard let selectedBook,
              let selectedChapter else {
            return nil
        }
        return "\(selectedBook.displayName) \(selectedChapter.number)"
    }

    // MARK: Properties (Private)

    /// Command implementations
    private let repository: BibleRepository

    /// OS Logging
    private static let logger = Logger(subsystem: "SwiftBible", category: "ReaderStore")

    // MARK: Init

    init(repository: BibleRepository) {
        self.repository = repository
    }

    // MARK: Functions

    /// Load a collection of available Translations w/ optional languageTag filter;
    /// set self.translations to results
    func loadTranslationsAndBooks(languageTag: String? = "en") async {
        Self.logger.debug("ENTRY ReaderStore.loadTranslationsAndBooks(languageTag: \(languageTag ?? "nil", privacy: .public))")

        // Only load if we're not doing anything right now OR if we failed previously
        // (allow retries)
        switch loadState {
        case .idle, .failed(_):
            break
        default:
            return
        }

        self.loadState = .loading

        do {
            let translations = try await repository.translations(languageTag: languageTag)
            self.translations = translations

            // ensure there's at least one translation
            guard let firstTranslation = self.translations.first else {
                clearAllStates()
                self.loadState = .emptyTranslations
                return
            }

            self.selectedTranslation = firstTranslation // TODO: persist preference

            await loadBooks()
        } catch {
            // TODO: log exception
            clearAllStates()
            self.loadState = .failed("An error occurred while loading Bibles.")
        }
    }

    /// If translation ID exists in store, select it and reload self.books + self.chapters
    func selectTranslationAndReloadAll(id: Int) async {
        Self.logger.debug("ENTRY ReaderStore.selectTranslationAndReloadAll(id: \(id, privacy: .public))")

        guard let requestedTranslation = self.translations.first(where: { $0.id == id }) else {
            return
        }

        // Store now for attempted restoration after we refresh
        let previousBookId = self.selectedBook?.id
        let previousChapterId = self.selectedChapter?.id

        // Select Translation + refresh available Books/Chapters
        self.selectedTranslation = requestedTranslation
        await self.loadBooks()

        // sanity check
        guard self.loadState == .loaded else {
            return
        }

        // Attempt to restore previous Book/Chapter selection w/o reloading
        if let previousBookId, let previousChapterId {
            await self.selectBookAndChapter(bookID: previousBookId,
                                            chapterID: previousChapterId,
                                            reloadPassage: false)
        }

        // Regardless of prev selection state, clear + load current passage
        clearPassageStates()
        await loadSelectedPassage()
    }

    /// Selects a book ID + chapter ID if they exist
    func selectBookAndChapter(bookID: Book.ID,
                              chapterID: Chapter.ID,
                              reloadPassage: Bool) async {
        Self.logger.debug("ENTRY ReaderStore.selectBookAndChapter(bookID: \(bookID, privacy: .public), chapterID: \(chapterID, privacy: .public))")

        guard let requestedBook = self.books.first(where: { $0.id == bookID }),
              let requestedChapter = requestedBook.chapters.first(where: { $0.id == chapterID }) else {
            clearPassageStates() // invalidate passage selection
            return
        }

        self.selectedBook = requestedBook
        self.selectedChapter = requestedChapter

        // invalidate passage selection then optionally refresh
        clearPassageStates()

        if reloadPassage {
            await self.loadSelectedPassage()
        }
    }

    /// Load the selected passage from calculated selectedReference property
    func loadSelectedPassage() async {
        Self.logger.debug("ENTRY ReaderStore.loadSelectedPassage()")

        guard let selectedReference else {
            self.passageLoadState = .failed("No passage selected.")
            return
        }

        // Only load if we're not doing anything right now OR if we failed previously
        // (allow retries)
        switch self.passageLoadState {
        case .idle, .failed(_):
            break
        default:
            return
        }

        self.passageLoadState = .loading

        do {
            let passage = try await repository.passage(for: selectedReference)

            self.selectedPassage = passage
            self.passageLoadState = .loaded
        } catch {
            // TODO: log exception
            self.selectedPassage = nil
            self.passageLoadState = .failed("An error occurred while loading the selected passage.")
        }
    }

    // MARK: Functions (Load; Private)

    /// Load a collection of available Books;
    /// set self.books to results;
    /// select first chapter
    ///
    /// Private for now unless needed externally
    private func loadBooks() async {
        Self.logger.debug("ENTRY ReaderStore.loadBooks()")

        guard let selectedTranslation else {
            return
        }

        do {
            let books = try await repository.books(for: selectedTranslation.id)
            self.books = books

            // ensure there's at least one book
            guard let firstBook = self.books.first else {
                clearBookAndChapterStates()
                self.loadState = .emptyBooks
                return
            }

            self.selectedBook = firstBook

            // ensure there's at least one chapter
            guard let firstChapter = firstBook.chapters.first else {
                clearBookAndChapterStates()
                self.loadState = .emptyChapters
                return
            }

            self.selectedChapter = firstChapter
            self.loadState = .loaded // done
        } catch {
            // TODO: log exception
            clearBookAndChapterStates()
            self.loadState = .failed("Unable to load books and chapters.")
        }
    }

    // MARK: Functions (State; Private)

    /// Clear translations, books, selections
    /// (loadState not modified)
    private func clearAllStates() {
        Self.logger.debug("ENTRY ReaderStore.clearAllStates()")
        clearTranslationStates()
        clearBookAndChapterStates()
    }

    /// Clear translations + selectedTranslation
    private func clearTranslationStates() {
        Self.logger.debug("ENTRY ReaderStore.clearTranslationStates()")
        self.translations = []
        self.selectedTranslation = nil
    }

    /// Clear books + selectedBook + selectedChapter
    private func clearBookAndChapterStates() {
        Self.logger.debug("ENTRY ReaderStore.clearBookAndChapterStates()")
        self.books = []
        self.selectedBook = nil
        self.selectedChapter = nil
    }

    /// Clear selectedPassage + passageLoadState
    private func clearPassageStates() {
        Self.logger.debug("ENTRY ReaderStore.clearPassageStates()")
        self.selectedPassage = nil
        self.passageLoadState = .idle
    }
}

enum ReaderLoadState: Equatable {
    case idle
    case loading
    case loaded
    case emptyTranslations
    case emptyBooks
    case emptyChapters
    case failed(String)
}
