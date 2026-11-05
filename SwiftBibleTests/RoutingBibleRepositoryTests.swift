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

    let translations: [Translation]
    var failsLoadingTranslations = false

    private(set) var translationsLanguageTags: [String?] = []
    private(set) var booksRequests: [Translation.ID] = []
    private(set) var passageRequests: [ScriptureReference] = []

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
}
