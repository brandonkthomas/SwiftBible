//
//  SearchStoreTests.swift
//  SwiftBibleTests
//

import Foundation
import Testing
@testable import SwiftBible

/// Search steps 5a-5d and 7: SearchStore runs a submitted Bible search, pages it, loads verse text,
/// filters saved annotations as you type, and exposes its state
@MainActor
struct SearchStoreTests {

    private let result = ScriptureSearchResult(translationID: 111, bookCode: "PSA", chapter: 23,
                                               verseRange: 1...1, snippet: nil)

    /// A search with matches shows them, in the provider's order
    @Test func submitShowsResults() async {
        let repository = SearchingBibleRepository()
        repository.page = ScriptureSearchPage(results: [result], nextCursor: nil)
        let store = makeStore(repository)

        await store.submitBibleSearch("shepherd", translationID: 111)

        #expect(store.bibleState == .results)
        #expect(store.bibleResults == [result])
        #expect(repository.searchQueries == ["shepherd"])
    }

    /// A search with no matches says so (different from "not searched yet")
    @Test func noMatchesShowsEmpty() async {
        let repository = SearchingBibleRepository()
        repository.page = ScriptureSearchPage(results: [], nextCursor: nil)
        let store = makeStore(repository)

        await store.submitBibleSearch("qwxzvb", translationID: 111)

        #expect(store.bibleState == .empty)
        #expect(store.bibleResults.isEmpty)
    }

    /// A translation without search shows "unavailable" and never calls the provider
    @Test func unsupportedTranslationSkipsRequest() async {
        let repository = SearchingBibleRepository()
        repository.supportsSearchResult = false
        let store = makeStore(repository)

        await store.submitBibleSearch("shepherd", translationID: 111)

        #expect(store.bibleState == .unsupported)
        #expect(repository.searchQueries.isEmpty)
    }

    /// Clearing the field on a translation that can't be searched goes back to idle, not "unsupported"
    @Test func blankQueryIsIdleEvenWhenTranslationUnsupported() async {
        let repository = SearchingBibleRepository()
        repository.supportsSearchResult = false
        let store = makeStore(repository)

        await store.submitBibleSearch("  ", translationID: 111)

        #expect(store.bibleState == .idle)
        #expect(repository.searchQueries.isEmpty)
    }

    // MARK: Step 5b: new searches, errors, blank queries, page details

    /// A new search starts from the first page, even when the previous search had more pages
    @Test func newSearchStartsFromFirstPage() async {
        let repository = SearchingBibleRepository()
        repository.page = ScriptureSearchPage(results: [result], nextCursor: .pageToken("old-search-page-2"))
        let store = makeStore(repository)

        await store.submitBibleSearch("shepherd", translationID: 111)
        await store.submitBibleSearch("love", translationID: 111)

        #expect(repository.searchCursors == [nil, nil])
    }

    /// No connection shows the offline state, and the previous search's results are cleared
    @Test func offlineErrorShowsOfflineAndClearsResults() async {
        let repository = SearchingBibleRepository()
        repository.page = ScriptureSearchPage(results: [result], nextCursor: nil)
        let store = makeStore(repository)
        await store.submitBibleSearch("shepherd", translationID: 111)

        repository.error = URLError(.notConnectedToInternet)
        await store.submitBibleSearch("love", translationID: 111)

        #expect(store.bibleState == .offline)
        #expect(store.bibleResults.isEmpty)
    }

    /// Any other error shows the failed state
    @Test func otherErrorShowsFailed() async {
        let repository = SearchingBibleRepository()
        repository.error = URLError(.badServerResponse)
        let store = makeStore(repository)

        await store.submitBibleSearch("shepherd", translationID: 111)

        #expect(store.bibleState == .failed)
    }

    /// A blank query clears the results and goes back to idle without calling the provider
    @Test func blankQueryClearsWithoutRequest() async {
        let repository = SearchingBibleRepository()
        repository.page = ScriptureSearchPage(results: [result], nextCursor: nil)
        let store = makeStore(repository)
        await store.submitBibleSearch("shepherd", translationID: 111)

        await store.submitBibleSearch("   ", translationID: 111)

        #expect(store.bibleState == .idle)
        #expect(store.bibleResults.isEmpty)
        #expect(repository.searchQueries == ["shepherd"])
    }

    /// "Did you mean", the corrected query, and the intent are available to the UI
    @Test func pageDetailsAreExposed() async {
        let repository = SearchingBibleRepository()
        repository.page = ScriptureSearchPage(results: [result],
                                              nextCursor: nil,
                                              suggestions: ["shepherd"],
                                              searchedInsteadFor: "shepherd",
                                              intent: .topical)
        let store = makeStore(repository)

        await store.submitBibleSearch("sheperd", translationID: 111)

        #expect(store.bibleSuggestions == ["shepherd"])
        #expect(store.bibleSearchedInsteadFor == "shepherd")
        #expect(store.bibleIntent == .topical)
    }

    // MARK: Step 5c: more pages, stale searches

    private let secondResult = ScriptureSearchResult(translationID: 111, bookCode: "JHN", chapter: 10,
                                                     verseRange: 11...11, snippet: nil)

    /// The next page is requested with the saved cursor and added after the first page's results
    @Test func nextPageAppendsResults() async {
        let repository = SearchingBibleRepository()
        repository.queuedPages = [
            ScriptureSearchPage(results: [result], nextCursor: .pageToken("page-2")),
            ScriptureSearchPage(results: [secondResult], nextCursor: nil)
        ]
        let store = makeStore(repository)
        await store.submitBibleSearch("shepherd", translationID: 111)
        #expect(store.canLoadMoreBibleResults)

        await store.loadNextBiblePage()

        #expect(repository.searchCursors == [nil, .pageToken("page-2")])
        #expect(repository.searchQueries == ["shepherd", "shepherd"])
        #expect(store.bibleResults == [result, secondResult])
        #expect(store.bibleState == .results)
        #expect(store.canLoadMoreBibleResults == false)
    }

    /// A failed next page keeps what's already shown and can be tried again
    @Test func failedNextPageKeepsEarlierResults() async {
        let repository = SearchingBibleRepository()
        repository.page = ScriptureSearchPage(results: [result], nextCursor: .pageToken("page-2"))
        let store = makeStore(repository)
        await store.submitBibleSearch("shepherd", translationID: 111)

        repository.error = URLError(.notConnectedToInternet)
        await store.loadNextBiblePage()

        #expect(store.bibleResults == [result])
        #expect(store.bibleState == .results)
        #expect(store.canLoadMoreBibleResults)
    }

    /// When an older search answers after a newer one, the older answer is ignored
    @Test func newerSearchWinsOverOlderStillLoading() async {
        let repository = SearchingBibleRepository()
        repository.holdsRequests = true
        let store = makeStore(repository)

        let olderSearch = Task { await store.submitBibleSearch("old", translationID: 111) }
        await repository.waitForHeldRequests(1)
        let newerSearch = Task { await store.submitBibleSearch("new", translationID: 111) }
        await repository.waitForHeldRequests(2)

        repository.releaseHeldRequest(query: "new",
                                      with: ScriptureSearchPage(results: [secondResult], nextCursor: nil))
        await newerSearch.value
        repository.releaseHeldRequest(query: "old",
                                      with: ScriptureSearchPage(results: [result], nextCursor: .pageToken("old-2")))
        await olderSearch.value

        #expect(store.bibleResults == [secondResult])
        #expect(store.bibleState == .results)
        #expect(store.canLoadMoreBibleResults == false)
    }

    /// An older search that fails after a newer one answered doesn't clear the newer results
    @Test func failedOlderSearchKeepsNewerResults() async {
        let repository = SearchingBibleRepository()
        repository.holdsRequests = true
        let store = makeStore(repository)

        let olderSearch = Task { await store.submitBibleSearch("old", translationID: 111) }
        await repository.waitForHeldRequests(1)
        let newerSearch = Task { await store.submitBibleSearch("new", translationID: 111) }
        await repository.waitForHeldRequests(2)

        repository.releaseHeldRequest(query: "new",
                                      with: ScriptureSearchPage(results: [secondResult], nextCursor: nil))
        await newerSearch.value
        repository.failHeldRequest(query: "old", with: URLError(.notConnectedToInternet))
        await olderSearch.value

        #expect(store.bibleResults == [secondResult])
        #expect(store.bibleState == .results)
    }

    /// Clearing the query while a search is loading means its answer is never shown
    @Test func blankQueryCancelsSearchInProgress() async {
        let repository = SearchingBibleRepository()
        repository.holdsRequests = true
        let store = makeStore(repository)

        let search = Task { await store.submitBibleSearch("shepherd", translationID: 111) }
        await repository.waitForHeldRequests(1)
        await store.submitBibleSearch("", translationID: 111)

        repository.releaseHeldRequest(query: "shepherd",
                                      with: ScriptureSearchPage(results: [result], nextCursor: nil))
        await search.value

        #expect(store.bibleState == .idle)
        #expect(store.bibleResults.isEmpty)
    }

    // MARK: Step 5d: verse text for results without a snippet

    /// The fake repository's only chapter with text: translation 1234, Genesis 1
    private let genesisResult = ScriptureSearchResult(translationID: 1234, bookCode: "GEN", chapter: 1,
                                                      verseRange: 1...1, snippet: nil)

    /// A YouVersion-style result (no snippet) gets its verse from the loaded chapter
    @Test func resultWithoutSnippetLoadsItsVerse() async {
        let repository = SearchingBibleRepository()
        let store = makeStore(repository)

        await store.loadPassage(for: genesisResult)

        let runs = store.passageRuns(for: genesisResult)
        #expect(runs?.contains(.text("In the beginning God created the heavens and the earth.",
                                     verseRange: RenderedVerseRange(startVerse: 1))) == true)
        #expect(repository.passageRequestCount == 1)
    }

    /// An ESV-style result already has its text, so no chapter is loaded
    @Test func resultWithSnippetSkipsChapterLoad() async {
        let repository = SearchingBibleRepository()
        let store = makeStore(repository)
        let esvResult = ScriptureSearchResult(translationID: 1234, bookCode: "GEN", chapter: 1,
                                              verseRange: 1...1, snippet: "In the beginning, God created")

        await store.loadPassage(for: esvResult)

        #expect(repository.passageRequestCount == 0)
        #expect(store.passageRuns(for: esvResult) == nil)
    }

    /// Offline, the row learns why its text is missing instead of loading forever
    @Test(.enabled(if: ArtificialNetworkConstraint.isNetworkRequired,
                   "Online-only passages are turned off"))
    func offlineChapterLoadRecordsOfflineFailure() async {
        let repository = SearchingBibleRepository()
        let networkStatus = FakeNetworkStatus()
        networkStatus.isOnline = false
        let store = makeStore(repository, networkStatus: networkStatus)

        await store.loadPassage(for: genesisResult)

        #expect(store.passageRuns(for: genesisResult) == nil)
        #expect(store.passageLoadFailure(for: genesisResult) == .offline)
    }

    // MARK: Task 7: Bible result labels

    /// Without that translation's books in memory, standard book names are used (no request is
    /// made for labels), and a verse range uses the same en dash as Library labels
    @Test func resultLabelFallsBackToStandardBookName() {
        let repository = SearchingBibleRepository()
        let store = makeStore(repository)
        let range = ScriptureSearchResult(translationID: 111, bookCode: "PSA", chapter: 23,
                                          verseRange: 1...3, snippet: nil)

        #expect(store.referenceLabel(for: range) == "Psalms 23:1\u{2013}3")
        #expect(repository.passageRequestCount == 0)
    }

    /// A book code the app doesn't know is shown as-is rather than dropped
    @Test func resultLabelShowsUnknownBookCode() {
        let store = makeStore(SearchingBibleRepository())
        let unknown = ScriptureSearchResult(translationID: 111, bookCode: "XYZ", chapter: 2,
                                            verseRange: 5...5, snippet: nil)

        #expect(store.referenceLabel(for: unknown) == "XYZ 2:5")
    }

    // MARK: Step 7: saved annotations, filtered as you type

    /// Matching annotations show newest first; others are left out
    @Test func annotationResultsMatchQueryNewestFirst() throws {
        let libraryRepository = InMemoryLibraryRepository()
        let older = makeAnnotation(.note("the good shepherd"), createdAt: Date(timeIntervalSince1970: 1_000))
        let newer = makeAnnotation(.note("shepherd psalm"), createdAt: Date(timeIntervalSince1970: 2_000))
        let other = makeAnnotation(.tags(["Faith"]), createdAt: Date(timeIntervalSince1970: 3_000))
        try libraryRepository.save(older)
        try libraryRepository.save(newer)
        try libraryRepository.save(other)
        let store = makeStore(SearchingBibleRepository(), libraryRepository: libraryRepository)

        store.annotationSearchQuery = "shepherd"

        #expect(store.annotationResults.map(\.id) == [newer.id, older.id])
    }

    /// An annotation saved while searching shows up without searching again
    @Test func annotationResultsFollowLibraryChanges() throws {
        let libraryRepository = InMemoryLibraryRepository()
        let (store, libraryStore) = makeStores(SearchingBibleRepository(), libraryRepository: libraryRepository)
        store.annotationSearchQuery = "hope"
        #expect(store.annotationResults.isEmpty)

        let saved = makeAnnotation(.tags(["Hope"]), createdAt: .now)
        try libraryRepository.save(saved)
        libraryStore.load()

        #expect(store.annotationResults.map(\.id) == [saved.id])
    }

    /// A blank query shows no annotations rather than all of them
    @Test func blankAnnotationQueryShowsNothing() throws {
        let libraryRepository = InMemoryLibraryRepository()
        try libraryRepository.save(makeAnnotation(.note("anything"), createdAt: .now))
        let store = makeStore(SearchingBibleRepository(), libraryRepository: libraryRepository)

        store.annotationSearchQuery = "  "

        #expect(store.annotationResults.isEmpty)
    }

    // MARK: Task 9b: "Search instead for" searches the original words exactly

    /// An exact search asks for exact text, and so does its next page; a later normal search doesn't
    @Test func exactSearchStaysExactForNextPageOnly() async {
        let repository = SearchingBibleRepository()
        repository.queuedPages = [
            ScriptureSearchPage(results: [result], nextCursor: .pageToken("page-2")),
            ScriptureSearchPage(results: [secondResult], nextCursor: nil),
            ScriptureSearchPage(results: [result], nextCursor: nil)
        ]
        let store = makeStore(repository)

        await store.submitBibleSearch("sheperd", translationID: 111, exactText: true)
        await store.loadNextBiblePage()
        await store.submitBibleSearch("shepherd", translationID: 111)

        #expect(repository.searchExactTextFlags == [true, true, false])
    }

    // MARK: Task 10: "Load More" row

    /// The row can show a spinner while the next page is loading, and only then
    @Test func nextPageIsLoadingUntilAnswered() async {
        let repository = SearchingBibleRepository()
        repository.holdsRequests = true
        let store = makeStore(repository)
        let search = Task { await store.submitBibleSearch("shepherd", translationID: 111) }
        await repository.waitForHeldRequests(1)
        repository.releaseHeldRequest(query: "shepherd",
                                      with: ScriptureSearchPage(results: [result], nextCursor: .pageToken("page-2")))
        await search.value
        #expect(store.isLoadingNextPage == false)

        let nextPage = Task { await store.loadNextBiblePage() }
        await repository.waitForHeldRequests(1)
        #expect(store.isLoadingNextPage)

        repository.releaseHeldRequest(query: "shepherd",
                                      with: ScriptureSearchPage(results: [secondResult], nextCursor: nil))
        await nextPage.value
        #expect(store.isLoadingNextPage == false)
    }

    /// A failed next page says why (offline or other), until a retry succeeds
    @Test func failedNextPageReportsWhyUntilRetried() async {
        let repository = SearchingBibleRepository()
        repository.queuedPages = [
            ScriptureSearchPage(results: [result], nextCursor: .pageToken("page-2")),
            ScriptureSearchPage(results: [secondResult], nextCursor: nil)
        ]
        let store = makeStore(repository)
        await store.submitBibleSearch("shepherd", translationID: 111)
        #expect(store.bibleNextPageFailure == nil)

        repository.error = URLError(.notConnectedToInternet)
        await store.loadNextBiblePage()
        #expect(store.bibleNextPageFailure == .offline)

        repository.error = URLError(.badServerResponse)
        await store.loadNextBiblePage()
        #expect(store.bibleNextPageFailure == .failed)

        repository.error = nil
        await store.loadNextBiblePage()
        #expect(store.bibleNextPageFailure == nil)
        #expect(store.bibleResults == [result, secondResult])
    }

    /// A new search doesn't carry the old search's next-page failure
    @Test func newSearchClearsNextPageFailure() async {
        let repository = SearchingBibleRepository()
        repository.page = ScriptureSearchPage(results: [result], nextCursor: .pageToken("page-2"))
        let store = makeStore(repository)
        await store.submitBibleSearch("shepherd", translationID: 111)
        repository.error = URLError(.notConnectedToInternet)
        await store.loadNextBiblePage()

        repository.error = nil
        await store.submitBibleSearch("lamb", translationID: 111)

        #expect(store.bibleNextPageFailure == nil)
    }

    // MARK: Task 8: when Search shows its start screen

    /// Typed text with no annotation matches still shows the sections (so "press Search" can appear)
    @Test func typedQueryWithoutMatchesIsNotIdle() {
        let store = makeStore(SearchingBibleRepository())

        store.annotationSearchQuery = "zzz"

        #expect(store.annotationResults.isEmpty)
        #expect(store.isIdle == false)
    }

    /// Nothing typed and nothing searched shows the start screen
    @Test func blankQueryWithoutSearchIsIdle() {
        let store = makeStore(SearchingBibleRepository())

        store.annotationSearchQuery = "   "

        #expect(store.isIdle)
    }

    // MARK: Helpers

    private func makeStore(_ repository: SearchingBibleRepository,
                           networkStatus: FakeNetworkStatus? = nil,
                           libraryRepository: InMemoryLibraryRepository? = nil) -> SearchStore {
        makeStores(repository, networkStatus: networkStatus, libraryRepository: libraryRepository).search
    }

    /// The search store plus the LibraryStore it reads annotations from
    private func makeStores(_ repository: SearchingBibleRepository,
                            networkStatus: FakeNetworkStatus? = nil,
                            libraryRepository: InMemoryLibraryRepository? = nil) -> (search: SearchStore,
                                                                                     library: LibraryStore) {
        let passageStore = BiblePassageStore(repository: repository,
                                             passageCache: InMemoryPassageCache(),
                                             networkStatus: networkStatus ?? FakeNetworkStatus())
        let catalogStore = BibleCatalogStore(repository: repository)
        let libraryStore = LibraryStore(libraryRepository: libraryRepository ?? InMemoryLibraryRepository(),
                                        catalogStore: catalogStore,
                                        passageStore: passageStore)
        libraryStore.load()
        let searchStore = SearchStore(repository: repository,
                                      libraryStore: libraryStore,
                                      bibleCatalogStore: catalogStore,
                                      biblePassageStore: passageStore)
        return (searchStore, libraryStore)
    }

    private func makeAnnotation(_ content: AnnotationContent, createdAt: Date) -> VerseAnnotation {
        VerseAnnotation(id: UUID(),
                        translationID: 111,
                        bookCode: "PSA",
                        chapter: 23,
                        startVerse: 1,
                        endVerse: nil,
                        content: content,
                        createdAt: createdAt)
    }
}

/// Answers searches with a fixed page and records every query it receives
@MainActor
private final class SearchingBibleRepository: BibleRepository {
    private let repository = FakeBibleRepository()

    var supportsSearchResult = true
    var page = ScriptureSearchPage(results: [], nextCursor: nil)

    /// Thrown by searchVerses instead of returning page, when set
    var error: (any Error)?

    /// Returned in order, one per search, before falling back to page
    var queuedPages: [ScriptureSearchPage] = []

    /// When true, each search waits until the test releases it (to answer out of order)
    var holdsRequests = false
    private var heldRequests: [(query: String, continuation: CheckedContinuation<ScriptureSearchPage, any Error>)] = []

    private(set) var passageRequestCount = 0

    private(set) var searchQueries: [String] = []
    private(set) var searchCursors: [ScriptureSearchCursor?] = []
    private(set) var searchExactTextFlags: [Bool] = []

    func translations(languageTag: String?) async throws -> [Translation] {
        try await repository.translations(languageTag: languageTag)
    }

    func books(for translationID: Translation.ID) async throws -> [Book] {
        try await repository.books(for: translationID)
    }

    func passage(for reference: ScriptureReference) async throws -> Passage {
        passageRequestCount += 1
        return try await repository.passage(for: reference)
    }

    func supportsSearch(translationID: Translation.ID) -> Bool {
        supportsSearchResult
    }

    func searchVerses(_ query: String,
                      translationID: Translation.ID,
                      cursor: ScriptureSearchCursor?,
                      exactText: Bool) async throws -> ScriptureSearchPage {
        searchQueries.append(query)
        searchCursors.append(cursor)
        searchExactTextFlags.append(exactText)

        if let error {
            throw error
        }

        if holdsRequests {
            return try await withCheckedThrowingContinuation { continuation in
                heldRequests.append((query: query, continuation: continuation))
            }
        }

        if !queuedPages.isEmpty {
            return queuedPages.removeFirst()
        }

        return page
    }

    /// Lets other main-actor work run until this many searches are waiting
    func waitForHeldRequests(_ count: Int) async {
        for _ in 0..<1_000 where heldRequests.count < count {
            await Task.yield()
        }
    }

    /// Answers the waiting search for this query
    func releaseHeldRequest(query: String, with page: ScriptureSearchPage) {
        guard let index = heldRequests.firstIndex(where: { $0.query == query }) else { return }
        heldRequests.remove(at: index).continuation.resume(returning: page)
    }

    /// Fails the waiting search for this query
    func failHeldRequest(query: String, with error: any Error) {
        guard let index = heldRequests.firstIndex(where: { $0.query == query }) else { return }
        heldRequests.remove(at: index).continuation.resume(throwing: error)
    }
}
