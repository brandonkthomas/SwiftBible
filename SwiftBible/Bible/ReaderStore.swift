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
/// final: cannot be subclassed; buys us shared, mutable, observable state
///  (when compared to a struct)
/// \@Observable: one source of truth that many views read & mutations are seen
///  immediately by all observers.
///
/// Owns:
/// - available translations
/// - selected translation
/// - available books for that translation
/// - selected book
/// - selected chapter
/// - loading state
/// - error state
/// - selected verse range (tap-to-select and take action)
/// - TODO: last-read restoration
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

    /// Tracks tapped verse(s) for use with verse actions
    ///
    /// Updated by ReaderPassageView => ReaderStore.handleVerseSelection()
    var selectedVerses: ClosedRange<Int>?

    var selectedPassage: Passage?
    var selectedRenderedPassage: RenderedPassage?

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

    /// Does the current selection contain a highlight annotation?
    var selectionContainsHighlight: Bool {
        // do we have a selection?
        guard let selectedVerses else {
            return false
        }
        return selectedVerses.contains { passageHighlightColors[$0] != nil }
    }

    /// Can we navigate backward by 1 chapter right now given the current selection + loaded collections?
    var previousAdjacentChapterExists: Bool {
        guard let selectedChapterNumber = self.selectedChapter?.number else {
            return false
        }
        return selectedChapterNumber > 1
        || self.selectedBook != self.books.first
    }

    /// Can we navigate forward by 1 chapter right now given the current selection + loaded collections?
    var nextAdjacentChapterExists: Bool {
        guard let selectedBook = self.selectedBook,
              let selectedChapterNumber = self.selectedChapter?.number else {
            return false
        }
        return selectedChapterNumber < selectedBook.chapters.count
        || self.selectedBook != self.books.last
    }

    // MARK: Properties (Private)

    /// API (Bible passage) command implementations
    private let repository: BibleRepository

    /// User storage command implementations
    private let libraryRepository: any LibraryRepository

    /// User highlight colors for the currently-selected passage
    private(set) var passageHighlightColors: [Int: VerseAnnotationHighlightColor] = [:]

    /// OS Logging
    private static let logger = Logger(subsystem: "SwiftBible", category: "ReaderStore")

    // MARK: Init

    init(repository: BibleRepository,
         libraryRepository: LibraryRepository) {
        self.repository = repository
        self.libraryRepository = libraryRepository
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

        // TODO: split into 2 do's (passage load + passage parse)
        do {
            // Try to retrieve passage HTML + parse into SwiftBible.Passage
            // + mark result as selected
            let passage = try await repository.passage(for: selectedReference)
            self.selectedPassage = passage

            // Try to render the now-selected passage HTML
            let parser: PassageHTMLParser = .init()

            var renderedPassage = try parser.parse(html: passage.htmlContent)
            renderedPassage.referenceBookAndChapterDisplayName = selectedReferenceFriendlyName

            self.selectedRenderedPassage = renderedPassage

            // we're done at this point; anything below here is supplementary
            // + will NOT prevent loading
            loadPassageHighlights(for: selectedReference)

            // we're done
            self.passageLoadState = .loaded
        } catch {
            // TODO: log exception
            self.selectedPassage = nil
            self.passageLoadState = .failed("An error occurred while loading the selected passage.")
        }
    }

    /// Called by ReaderPassageView to refresh current verse selection state
    /// according to tapped verse's metadata
    func handleVerseSelection(startVerse: Int,
                              endVerse: Int?) {
        let top = endVerse ?? startVerse

        // nothing currently selected...
        // select current tap target only
        guard let current = self.selectedVerses else {
            self.selectedVerses = startVerse...top
            return
        }

        switch startVerse {
        // sv falls inside current selection range...
        case current: // Swift compares Int to ClosedRange<Int> here using ~=
            // if the tapped verse IS the entire current selection, deselect;
            // otherwise collapse the selection down to just this verse
            self.selectedVerses = (current == startVerse...top) ? nil : startVerse...top
        // sv is below current selection range...
        // add the difference to the selection
        case ..<current.lowerBound: // ..<x is Swift one-sided range
            self.selectedVerses = startVerse...current.upperBound
        // sv is above current selection range...
        // add the difference to the selection
        default:
            self.selectedVerses = current.lowerBound...top
        }
    }

    /// Save the selected verse range as some annotation content w/ provided data
    func save(_ content: AnnotationContent) {
        Self.logger.debug("ENTRY ReaderStore.save()")

        // Ensure current selection
        guard let selectedVerses,
              let selectedReference else {
            return
        }

        // Try to build annotation
        let annotation = VerseAnnotation(reference: selectedReference,
                                         selectedVerses: selectedVerses,
                                         content: content)

        guard let annotation else {
            return
        }

        // Try to save
        do {
            try libraryRepository.save(annotation)
        } catch {
            Self.logger.error("Unable to save annotation: \(error.localizedDescription)")
            return
        }

        // Refresh highlights
        loadPassageHighlights(for: selectedReference)

        // Deselect
        self.selectedVerses = nil
    }

    /// Delete all highlights in selected verse range
    func deleteHighlights() {
        Self.logger.debug("ENTRY ReaderStore.deleteHighlight()")

        // Ensure current selection
        guard let selectedVerses,
              let selectedReference else {
            return
        }

        // Try to find + delete
        do {
            let annotations = try libraryRepository.annotations(for: selectedReference)
            let highlightedAnnotations = annotations.filter {
                if case .highlight = $0.content {
                    return true
                }

                return false
            }

            // loop over all highlights: parse range + detect overlap + delete
            for annotation in highlightedAnnotations {
                let annotationRange = annotation.startVerse...(annotation.endVerse ?? annotation.startVerse)
                // does this annotation contain ANY of our selected verses?
                guard annotationRange.overlaps(selectedVerses) else { continue }

                // try to delete
                do {
                    try libraryRepository.delete(annotation.id)
                } catch {
                    Self.logger.error("Unable to delete annotation \(annotation.id): \(error.localizedDescription)")
                    continue
                }
            }
        } catch {
            Self.logger.error("Unable to delete annotations: \(error.localizedDescription)")
            return
        }

        // Refresh highlights
        loadPassageHighlights(for: selectedReference)

        // Deselect
        self.selectedVerses = nil
    }

    func selectAdjacentChapter(
            _ direction: ChapterNavigationDirection
        ) async {
        guard let selectedBook,
              let selectedChapter,
              let bookIndex = books.firstIndex(where: {
                  $0.id == selectedBook.id
              }),
              let chapterIndex = selectedBook.chapters.firstIndex(where: {
                  $0.id == selectedChapter.id
              }) else {
            return
        }

        let destination: (book: Book, chapter: Chapter)?

        switch direction {
        case .previous:
            destination = previousChapter(
                bookIndex: bookIndex,
                chapterIndex: chapterIndex
            )
        case .next:
            destination = nextChapter(
                bookIndex: bookIndex,
                chapterIndex: chapterIndex
            )
        }

        guard let destination else {
            return
        }

        await selectBookAndChapter(
            bookID: destination.book.id,
            chapterID: destination.chapter.id,
            reloadPassage: true
        )
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

    /// retrieve + assign a passage's user stored highlights
    private func loadPassageHighlights(for reference: ScriptureReference) {
        Self.logger.debug("ENTRY ReaderStore.loadPassageHighlights(for: \(reference.passageID, privacy: .public))")

        do {
            let annotations = try libraryRepository.annotations(for: reference)

            passageHighlightColors = VerseAnnotationHelpers.getPassageHighlightColors(
                for: annotations,
                reference: reference
            )
        } catch {
            passageHighlightColors = [:]
            // this is supplementary; no need to fail
        }
    }

    /// Try to select the prev chapter in order w/ wrap around for prev book
    private func previousChapter(
        bookIndex: Int,
        chapterIndex: Int
    ) -> (book: Book, chapter: Chapter)? {
        let currentBook = books[bookIndex]

        // Previous chapter in current book
        if chapterIndex > currentBook.chapters.startIndex {
            let previousChapterIndex =
                currentBook.chapters.index(before: chapterIndex)

            return (
                currentBook,
                currentBook.chapters[previousChapterIndex]
            )
        }

        // Already at first chapter of first book
        guard bookIndex > books.startIndex else {
            return nil
        }

        // Last chapter of previous book
        let previousBookIndex = books.index(before: bookIndex)
        let previousBook = books[previousBookIndex]

        guard let lastChapter = previousBook.chapters.last else {
            return nil
        }

        return (previousBook, lastChapter)
    }

    /// Try to select the next chapter in order w/ wrap around for next book
    private func nextChapter(
        bookIndex: Int,
        chapterIndex: Int
    ) -> (book: Book, chapter: Chapter)? {
        let currentBook = books[bookIndex]

        // Next chapter in current book
        if chapterIndex < currentBook.chapters.index(before: currentBook.chapters.endIndex) {
            let nextChapterIndex =
                currentBook.chapters.index(after: chapterIndex)

            return (
                currentBook,
                currentBook.chapters[nextChapterIndex]
            )
        }

        // Already at last chapter of last book
        guard bookIndex < books.index(before: books.endIndex) else {
            return nil
        }

        // First chapter of next book
        let nextBookIndex = books.index(after: bookIndex)
        let nextBook = books[nextBookIndex]

        guard let firstChapter = nextBook.chapters.first else {
            return nil
        }

        return (nextBook, firstChapter)
    }

    // MARK: Functions (State; Private)

    /// Clear translations, books, selections
    /// (loadState not modified)
    private func clearAllStates() {
        Self.logger.debug("ENTRY ReaderStore.clearAllStates()")
        clearTranslationStates()
        clearBookAndChapterStates()
        clearPassageStates()
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
        self.selectedVerses = nil // also clear verse selection
        self.selectedPassage = nil
        self.selectedRenderedPassage = nil
        self.passageLoadState = .idle
        self.passageHighlightColors = [:]
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

enum ChapterNavigationDirection {
    case previous
    case next
}
