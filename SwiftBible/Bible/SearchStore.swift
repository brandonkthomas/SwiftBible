//
//  SearchStore.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-21.
//

import Foundation
import OSLog

/// Observable feature state for Search interface
///
/// Flow: RoutingBibleRepository -> SearchStore -> SearchView
@Observable
final class SearchStore {

    /// What was our last search?
    var annotationSearchQuery: String = ""

    // MARK: Properties (Computed)

    // True if we have an upcoming cursor object
    var canLoadMoreBibleResults: Bool {
        bibleNextCursor != nil
    }

    var isIdle: Bool {
        bibleState == .idle
        && annotationSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Computed annotation search results according to current annotationSearchQuery value
    ///
    /// Ordered by date; 
    var annotationResults: [VerseAnnotation] {
        let annotations = libraryStore.annotations
            .sorted(by: { $0.createdAt > $1.createdAt })

        let librarySearch = LibrarySearch(query: annotationSearchQuery)
        let searchedAnnotations = librarySearch.results(
            in: annotations,
            passageLabel: { bibleCatalogStore.friendlyPassageName(for: $0) },
            translationAbbreviation: { bibleCatalogStore.translation(for: $0.translationID)?.abbreviation }
        )
        return searchedAnnotations
    }

    // MARK: Properties (Private)

    /// Used to interface w/ search functions
    private let repository: any BibleRepository

    /// Used to search annotations
    private let libraryStore: LibraryStore

    /// Used to retrieve passageLabel and translationAbbreviation for annotationResults
    private let bibleCatalogStore: BibleCatalogStore

    /// Used to load any missing passage texts
    private let biblePassageStore: BiblePassageStore

    // MARK: Properties (Private, Bible Search)

    /// Current Bible results state
    private(set) var bibleState: BibleSearchState = .idle

    /// Results from a Bible search (if any)
    private(set) var bibleResults: [ScriptureSearchResult] = []

    /// Do we have any more results to retrieve after the last search?
    private var bibleNextCursor: ScriptureSearchCursor?

    /// Do we have any search suggestions/replacements?
    private(set) var bibleSuggestions: [String] = []

    /// Did the API correct our query?
    private(set) var bibleSearchedInsteadFor: String?

    /// What was the intent of this search? (youversion API only)
    private(set) var bibleIntent: ScriptureSearchIntent = .unknown

    /// What was our last search?
    private var bibleSearchQuery: String = ""

    /// What is the latest search number? (used for async cancellations)
    private var latestSearchNumber: Int = 0

    /// Is a next-page request in flight? (prevents duplicate page loads)
    private var isLoadingNextPage: Bool = false

    /// What is our current translation filter?
    private(set) var bibleSearchTranslationID: Translation.ID?

    /// Track which requests' passages we've loaded
    private(set) var loadedPassages: [BiblePassageKey: LoadedBiblePassage] = [:]

    /// Track passage load failures
    private(set) var passageLoadFailures: [BiblePassageKey: LibraryPassageLoadFailure] = [:]

    // MARK: Properties (Private, Shared Search)



    // MARK: Properties (Private, Static)

    private static let logger = Logger(subsystem: "SwiftBible", category: "SearchStore")

    // MARK: Init

    init(repository: any BibleRepository,
         libraryStore: LibraryStore,
         bibleCatalogStore: BibleCatalogStore,
         biblePassageStore: BiblePassageStore) {
        self.repository = repository
        self.libraryStore = libraryStore
        self.bibleCatalogStore = bibleCatalogStore
        self.biblePassageStore = biblePassageStore
    }

    // MARK: Functions

    /// Search a Bible translation for a given text query
    func submitBibleSearch(_ query: String,
                           translationID: Translation.ID) async {
        // mark this function call for later async cancellation if needed
        let thisSearchNumber = self.latestSearchNumber + 1
        self.latestSearchNumber = thisSearchNumber

        // clean query & short-circuit if empty
        bibleSearchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bibleSearchQuery.isEmpty else {
            self.bibleState = .idle
            resetBibleResults()
            return
        }

        // supportsSearch check
        guard repository.supportsSearch(translationID: translationID) else {
            self.bibleState = .unsupported
            resetBibleResults()
            return
        }

        // begin search
        self.bibleState = .searching
        self.bibleSearchTranslationID = translationID
        self.isLoadingNextPage = false

        do {
            // kick off search
            let page = try await repository.searchVerses(bibleSearchQuery,
                                                         translationID: translationID,
                                                         cursor: nil)

            // discard if we're no longer the latest search
            guard thisSearchNumber == self.latestSearchNumber else {
                return
            }

            // cache results from Page
            self.bibleResults = page.results
            self.bibleNextCursor = page.nextCursor
            self.bibleSuggestions = page.suggestions
            self.bibleSearchedInsteadFor = page.searchedInsteadFor
            self.bibleIntent = page.intent

            // we're done; set .empty/.results state & exit
            if self.bibleResults.isEmpty {
                self.bibleState = .empty
            } else {
                self.bibleState = .results
            }
        } catch {
            Self.logger.error("submitBibleSearch() failed: \(error)")

            // discard if we're no longer the latest search
            guard thisSearchNumber == self.latestSearchNumber else {
                return
            }

            resetBibleResults()

            // check for offline state
            if error.isOfflineError {
                self.bibleState = .offline
            } else {
                self.bibleState = .failed
            }
        }
    }

    /// Return next page for the previous search query (if one exists)
    func loadNextBiblePage() async {
        guard let bibleSearchTranslationID else { return }

        // sanity check
        guard repository.supportsSearch(translationID: bibleSearchTranslationID) else {
            self.bibleState = .unsupported
            resetBibleResults()
            return
        }

        guard let cursor = bibleNextCursor, !isLoadingNextPage else {
            return
        }

        // capture search number so a newer search can invalidate this page
        let thisSearchNumber = self.latestSearchNumber
        self.isLoadingNextPage = true
        defer {
            // a newer search owns the flag now; leave it alone
            if thisSearchNumber == self.latestSearchNumber {
                self.isLoadingNextPage = false
            }
        }

        do {
            let page = try await repository.searchVerses(bibleSearchQuery,
                                                         translationID: bibleSearchTranslationID,
                                                         cursor: cursor)

            // discard if a new search started while loading
            guard thisSearchNumber == self.latestSearchNumber else {
                return
            }

            // append results from Page
            self.bibleResults += page.results
            self.bibleNextCursor = page.nextCursor
        } catch {
            // keep results, state & cursor so "Load more" can retry
            Self.logger.error("loadNextBiblePage() failed: \(error)")
        }
    }

    /// Load a result's chapter when the API gave no snippet text to show
    func loadPassage(for result: ScriptureSearchResult) async {
        let key = result.passageKey

        // a snippet means there is nothing to load
        guard result.snippet?.isEmpty ?? true else {
            return
        }

        // every write notifies all observing rows; skip chapters already loaded
        if loadedPassages[key] != nil {
            return
        }

        do {
            let loadedPassage = try await biblePassageStore.passage(for: key)
            loadedPassages[key] = loadedPassage

            // only write when needed: every write notifies all observing rows
            if passageLoadFailures[key] != nil {
                passageLoadFailures[key] = nil
            }
        } catch {
            Self.logger.error("Unable to load passage: \(error.localizedDescription)")
            passageLoadFailures[key] = error.isOfflineError ? .offline : .failed
        }
    }

    /// Reference label for a given ScriptureSearchResult (i.e. Genesis 1:1-2)
    func referenceLabel(for result: ScriptureSearchResult) -> String {
        let book = bibleCatalogStore.book(for: result.translationID, bookCode: result.bookCode)

        var displayName = ""
        if let book {
            displayName = book.displayName
        } else {
            let defaultBook = BookDefaults.defaultBooks.filter { $0.code == result.bookCode }
            let defaultBookDisplayName = defaultBook.first?.displayName
            displayName = defaultBookDisplayName ?? result.bookCode
        }

        let versesText = RenderedVerseRange(range: result.verseRange).displayText
        return "\(displayName) \(result.chapter):\(versesText)"
    }

    /// Text runs for a result's verses, once its chapter is loaded
    func passageRuns(for result: ScriptureSearchResult) -> [RenderedPassageRun]? {
        loadedPassages[result.passageKey]?.renderedPassage.runs(for: RenderedVerseRange(range: result.verseRange))
    }

    /// Why a result's chapter could not be loaded, if its last load failed
    func passageLoadFailure(for result: ScriptureSearchResult) -> LibraryPassageLoadFailure? {
        passageLoadFailures[result.passageKey]
    }

    // MARK: Functions (Private)

    private func resetBibleResults() {
        self.bibleResults = []
        self.bibleNextCursor = nil
        self.bibleSuggestions = []
        self.bibleSearchedInsteadFor = nil
        self.bibleIntent = .unknown

        self.bibleSearchQuery = ""

        self.loadedPassages = [:]
        self.passageLoadFailures = [:]
    }
}

enum BibleSearchState: Equatable {
    case idle
    case searching
    case results
    case empty
    case unsupported
    case offline
    case failed
}
