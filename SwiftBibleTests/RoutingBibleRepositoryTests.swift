//
//  RoutingBibleRepositoryTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-02.
//

import Testing
@testable import SwiftBible

@MainActor
struct RoutingBibleRepositoryTests {

    private let routedTranslationID = 116
    private let secondRoutedTranslationID = 1
    private let unclaimedTranslationID = 3034

    // MARK: Books

    /// Also proves routing doesn't depend on translations() having been called first
    @Test func claimedBooksRequestReachesOnlyOwningProvider() async throws {
        let (router, routed, fallback) = makeRouter()

        _ = try await router.books(for: routedTranslationID)

        #expect(routed.booksRequests == [routedTranslationID])
        #expect(routed.translationsLanguageTags.isEmpty)
        #expect(fallback.booksRequests.isEmpty)
    }

    @Test func unclaimedBooksRequestReachesFallback() async throws {
        let (router, routed, fallback) = makeRouter()

        _ = try await router.books(for: unclaimedTranslationID)

        #expect(fallback.booksRequests == [unclaimedTranslationID])
        #expect(routed.booksRequests.isEmpty)
    }

    /// One provider owning two IDs receives requests for both
    @Test func providerOwningTwoIDsReceivesBoth() async throws {
        let (router, routed, fallback) = makeRouter()

        _ = try await router.books(for: routedTranslationID)
        _ = try await router.books(for: secondRoutedTranslationID)

        #expect(routed.booksRequests == [routedTranslationID, secondRoutedTranslationID])
        #expect(fallback.booksRequests.isEmpty)
    }

    // MARK: Passages

    @Test func claimedPassageRequestReachesOnlyOwningProvider() async throws {
        let (router, routed, fallback) = makeRouter()
        let reference = try makeReference(translationID: routedTranslationID)

        _ = try await router.passage(for: reference)

        #expect(routed.passageRequests == [reference])
        #expect(routed.translationsLanguageTags.isEmpty)
        #expect(fallback.passageRequests.isEmpty)
    }

    @Test func unclaimedPassageRequestReachesFallback() async throws {
        let (router, routed, fallback) = makeRouter()
        let reference = try makeReference(translationID: unclaimedTranslationID)

        _ = try await router.passage(for: reference)

        #expect(fallback.passageRequests == [reference])
        #expect(routed.passageRequests.isEmpty)
    }

    // MARK: Rendered Passages

    /// The provider that fetched a passage is the one that parses it
    @Test func claimedRenderReachesOnlyOwningProvider() throws {
        let (router, routed, fallback) = makeRouter()

        _ = try router.renderedPassage(from: makePassage(), translationID: routedTranslationID)

        #expect(routed.renderRequests == [routedTranslationID])
        #expect(fallback.renderRequests.isEmpty)
    }

    /// Each provider's terms set its cache policy, so the owning provider must answer
    @Test func cachePolicyComesFromOwningProvider() {
        let (router, routed, _) = makeRouter()
        routed.cachePolicy = .memoryOnly(maximumVerseCount: 500)

        #expect(router.passageCachePolicy(for: routedTranslationID) == .memoryOnly(maximumVerseCount: 500))
        #expect(router.passageCachePolicy(for: unclaimedTranslationID) == .unlimited)
    }

    @Test func unclaimedRenderReachesFallback() throws {
        let (router, routed, fallback) = makeRouter()

        _ = try router.renderedPassage(from: makePassage(), translationID: unclaimedTranslationID)

        #expect(fallback.renderRequests == [unclaimedTranslationID])
        #expect(routed.renderRequests.isEmpty)
    }

    // MARK: Translations

    /// A provider owning two IDs is asked once, so its translations aren't listed twice
    @Test func translationsCombineProvidersWithFallbackFirst() async throws {
        let fallbackTranslation = makeTranslation(id: unclaimedTranslationID, abbreviation: "NIV")
        let routedTranslations = [
            makeTranslation(id: routedTranslationID, abbreviation: "NLT"),
            makeTranslation(id: secondRoutedTranslationID, abbreviation: "KJV")
        ]
        let (router, routed, fallback) = makeRouter(routedTranslations: routedTranslations,
                                                    fallbackTranslations: [fallbackTranslation])

        let translations = try await router.translations(languageTag: "en")

        #expect(translations == [fallbackTranslation] + routedTranslations)
        #expect(routed.translationsLanguageTags.count == 1)
        #expect(fallback.translationsLanguageTags.count == 1)
    }

    /// YouVersion may list a translation that another provider serves; the routed entry wins
    @Test func duplicateIDKeepsRoutedEntry() async throws {
        let routedEntry = makeTranslation(id: routedTranslationID, abbreviation: "Routed")
        let fallbackEntry = makeTranslation(id: routedTranslationID, abbreviation: "Fallback")
        let (router, _, _) = makeRouter(routedTranslations: [routedEntry],
                                        fallbackTranslations: [fallbackEntry])

        let translations = try await router.translations(languageTag: "en")

        #expect(translations == [routedEntry])
    }

    @Test(arguments: ["en", nil] as [String?])
    func languageTagPassesThroughUnchanged(languageTag: String?) async throws {
        let (router, routed, fallback) = makeRouter()

        _ = try await router.translations(languageTag: languageTag)

        #expect(routed.translationsLanguageTags == [languageTag])
        #expect(fallback.translationsLanguageTags == [languageTag])
    }

    /// A partial list would be cached for days, so a failure must not produce one
    @Test func routedTranslationsFailureRethrows() async {
        let (router, routed, _) = makeRouter()
        routed.failsLoadingTranslations = true

        await #expect(throws: RecordingBibleRepository.RepositoryError.self) {
            try await router.translations(languageTag: "en")
        }
    }

    /// A partial list would be cached for days, so a failure must not produce one
    @Test func fallbackTranslationsFailureRethrows() async {
        let (router, _, fallback) = makeRouter()
        fallback.failsLoadingTranslations = true

        await #expect(throws: RecordingBibleRepository.RepositoryError.self) {
            try await router.translations(languageTag: "en")
        }
    }

    // MARK: Search

    /// Search for a claimed translation reaches only its provider, with the query and cursor intact
    @Test func claimedSearchReachesOnlyOwningProvider() async throws {
        let (router, routed, fallback) = makeRouter()

        _ = try await router.searchVerses("shepherd", translationID: routedTranslationID, cursor: .pageNumber(2))

        #expect(routed.searchRequests == [
            RecordingBibleRepository.SearchRequest(query: "shepherd",
                                                   translationID: routedTranslationID,
                                                   cursor: .pageNumber(2))
        ])
        #expect(fallback.searchRequests.isEmpty)
    }

    @Test func unclaimedSearchReachesFallback() async throws {
        let (router, routed, fallback) = makeRouter()

        _ = try await router.searchVerses("shepherd", translationID: unclaimedTranslationID, cursor: nil)

        #expect(fallback.searchRequests.map(\.translationID) == [unclaimedTranslationID])
        #expect(routed.searchRequests.isEmpty)
    }

    /// An exact-text search stays exact on its way to the provider
    @Test func exactTextReachesProvider() async throws {
        let (router, routed, _) = makeRouter()

        _ = try await router.searchVerses("sheperd", translationID: routedTranslationID,
                                          cursor: nil, exactText: true)

        #expect(routed.searchRequests.map(\.exactText) == [true])
    }

    /// Whether a translation can be searched is the owning provider's answer, not the router's
    @Test func searchSupportComesFromOwningProvider() {
        let (router, routed, fallback) = makeRouter()
        routed.supportsSearchResult = true
        fallback.supportsSearchResult = false

        #expect(router.supportsSearch(translationID: routedTranslationID))
        #expect(router.supportsSearch(translationID: unclaimedTranslationID) == false)
    }

    // MARK: Functions (Private Helpers)

    private func makeRouter(routedTranslations: [Translation] = [],
                            fallbackTranslations: [Translation] = []) -> (router: RoutingBibleRepository,
                                                                          routed: RecordingBibleRepository,
                                                                          fallback: RecordingBibleRepository) {
        let routed = RecordingBibleRepository(translations: routedTranslations)
        let fallback = RecordingBibleRepository(translations: fallbackTranslations)
        let route = RoutingBibleRepository.Route(translationIDs: [routedTranslationID, secondRoutedTranslationID],
                                                 repository: routed)
        let router = RoutingBibleRepository(fallbackRepository: fallback, routes: [route])
        return (router, routed, fallback)
    }

    private func makeReference(translationID: Translation.ID) throws -> ScriptureReference {
        try #require(ScriptureReference(translationID: translationID, bookCode: "GEN", chapter: 1))
    }

    private func makePassage() -> Passage {
        Passage(id: "GEN.1", reference: "Genesis 1", htmlContent: "")
    }

    private func makeTranslation(id: Translation.ID, abbreviation: String) -> Translation {
        Translation(id: id,
                    abbreviation: abbreviation,
                    title: abbreviation,
                    languageTag: "en",
                    license: nil,
                    promotionalText: nil,
                    availableBookCodes: [])
    }
}

/// Private fake for RoutingBibleRepositoryTests ONLY; records which requests reached this provider
private final class RecordingBibleRepository: BibleRepository {
    enum RepositoryError: Error {
        case translationsFailed
    }

    /// One searchVerses call, as received
    struct SearchRequest: Equatable {
        let query: String
        let translationID: Translation.ID
        let cursor: ScriptureSearchCursor?
        var exactText: Bool = false
    }

    let translations: [Translation]
    var failsLoadingTranslations = false
    var cachePolicy: PassageCachePolicy = .unlimited
    var supportsSearchResult = false

    private(set) var translationsLanguageTags: [String?] = []
    private(set) var booksRequests: [Translation.ID] = []
    private(set) var passageRequests: [ScriptureReference] = []
    private(set) var renderRequests: [Translation.ID] = []
    private(set) var searchRequests: [SearchRequest] = []

    init(translations: [Translation]) {
        self.translations = translations
    }

    func translations(languageTag: String?) async throws -> [Translation] {
        translationsLanguageTags.append(languageTag)

        if failsLoadingTranslations {
            throw RepositoryError.translationsFailed
        }

        return translations
    }

    func books(for translationID: Translation.ID) async throws -> [Book] {
        booksRequests.append(translationID)
        return []
    }

    func passage(for reference: ScriptureReference) async throws -> Passage {
        passageRequests.append(reference)
        return Passage(id: reference.passageID, reference: "", htmlContent: "")
    }

    func renderedPassage(from passage: Passage,
                         translationID: Translation.ID) throws -> RenderedPassage {
        renderRequests.append(translationID)
        return RenderedPassage(paragraphs: [], footnotes: [])
    }

    func passageCachePolicy(for translationID: Translation.ID) -> PassageCachePolicy {
        cachePolicy
    }

    func supportsSearch(translationID: Translation.ID) -> Bool {
        supportsSearchResult
    }

    func searchVerses(_ query: String,
                      translationID: Translation.ID,
                      cursor: ScriptureSearchCursor?,
                      exactText: Bool) async throws -> ScriptureSearchPage {
        searchRequests.append(SearchRequest(query: query, translationID: translationID,
                                            cursor: cursor, exactText: exactText))
        return ScriptureSearchPage(results: [], nextCursor: nil)
    }
}
