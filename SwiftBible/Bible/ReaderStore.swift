//
//  ReaderStore.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import Observation

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

    var loadState: ReaderLoadState = .idle

    var translations: [Translation] = []
    var selectedTranslation: Translation?

    var books: [Book] = []
    var selectedBook: Book?
    var selectedChapter: Chapter?

    // MARK: Properties (Private)

    /// Command implementations
    private let repository: BibleRepository

    // MARK: Init

    init(repository: BibleRepository) {
        self.repository = repository
    }

    // MARK: Functions

    /// Load a collection of available Translations w/ optional languageTag filter;
    /// set self.translations to results
    func loadTranslationsAndBooks(languageTag: String? = "en") async {
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
            self.loadState = .failed("Unable to load translations.")
        }
    }

    /// If translation ID exists in store, select it and reload self.books + self.chapters
    func selectTranslationAndReloadBooks(id: String) async {
        guard let requestedTranslation = self.translations.first(where: { $0.id == id }) else {
            return
        }

        self.selectedTranslation = requestedTranslation
        await self.loadBooks()
    }

    /// If book ID exists in store, select it
    func selectBook(id: String) {
        guard let requestedBook = self.books.first(where: { $0.id == id }) else {
            return
        }

        self.selectedBook = requestedBook

        // ensure there's at least one chapter
        guard let firstChapter = requestedBook.chapters.first else {
            clearBookAndChapterStates()
            self.loadState = .emptyChapters
            return
        }

        self.selectedChapter = firstChapter
    }

    /// If chapter ID exists in selected Book, select it
    func selectChapter(id: String) {
        guard let selectedBook = self.selectedBook,
              let requestedChapter = selectedBook.chapters.first(where: { $0.id == id }) else {
            return
        }

        self.selectedChapter = requestedChapter
    }

    /// Selects a book ID + chapter ID if they exist
    func selectBookAndChapter(bookID: String,
                              chapterID: String) {
        guard let requestedBook = self.books.first(where: { $0.id == bookID }),
              let requestedChapter = requestedBook.chapters.first(where: { $0.id == chapterID }) else {
            return
        }

        self.selectedBook = requestedBook
        self.selectedChapter = requestedChapter
    }

    // MARK: Functions (Private)

    /// Load a collection of available Books;
    /// set self.books to results;
    /// select first chapter
    ///
    /// Private for now unless needed externally
    private func loadBooks() async {
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

    /// Clear translations, books, selections
    /// (loadState not modified)
    private func clearAllStates() {
        clearTranslationStates()
        clearBookAndChapterStates()
    }

    /// Clear translations + selectedTranslation
    private func clearTranslationStates() {
        self.translations = []
        self.selectedTranslation = nil
    }

    /// Clear books + selectedBook + selectedChapter
    private func clearBookAndChapterStates() {
        self.books = []
        self.selectedBook = nil
        self.selectedChapter = nil
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
