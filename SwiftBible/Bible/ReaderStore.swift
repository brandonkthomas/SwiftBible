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

    /// Load a collection of available Translations w/ optional languageTag filter
    func loadTranslations(languageTag: String? = "en") async {
        // Only load if we're not doing anything right now OR if we failed previously
        // (allow retries)
        switch loadState {
        case .idle, .failed:
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

            do {
                let books = try await repository.books(for: firstTranslation.id)
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
        } catch {
            // TODO: log exception
            clearAllStates()
            self.loadState = .failed("Unable to load translations.")
        }
    }

    // MARK: Functions (Private)

    private func clearAllStates() {
        clearTranslationStates()
        clearBookAndChapterStates()
    }

    private func clearTranslationStates() {
        self.translations = []
        self.selectedTranslation = nil
    }

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
