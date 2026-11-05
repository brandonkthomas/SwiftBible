//
//  RoutingBibleRepository.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-01.
//

/// Sends each request to the BibleRepository that owns its translation ID
///
/// Ownership comes from the routes given at init, never from a translations() result,
/// because a fresh catalog cache hit skips translations() entirely.
final class RoutingBibleRepository: BibleRepository {

    /// One provider and every translation ID it owns
    struct Route {
        let translationIDs: Set<Translation.ID>
        let repository: any BibleRepository
    }

    // MARK: Properties (Private)

    /// Owns every translation ID that no route claims
    private let fallbackRepository: any BibleRepository

    private let routes: [Route]

    // MARK: Init

    init(fallbackRepository: any BibleRepository,
         routes: [Route] = []) {
        self.fallbackRepository = fallbackRepository
        self.routes = routes
    }

    // MARK: Functions

    /// Combine every provider's translations
    ///
    /// Any failure throws instead of returning a partial list, because BibleCatalogStore
    /// would cache that partial list for days.
    func translations(languageTag: String?) async throws -> [Translation] {
        var routedTranslations: [Translation] = []
        for route in routes {
            routedTranslations += try await route.repository.translations(languageTag: languageTag)
        }

        // Passages for these IDs come from the routed provider, so its entry is the one to keep
        let routedTranslationIDs = Set(routedTranslations.map(\.id))
        let fallbackTranslations = try await fallbackRepository.translations(languageTag: languageTag)
            .filter { !routedTranslationIDs.contains($0.id) }

        return fallbackTranslations + routedTranslations
    }

    func books(for translationID: Translation.ID) async throws -> [Book] {
        try await repository(for: translationID).books(for: translationID)
    }

    func passage(for reference: ScriptureReference) async throws -> Passage {
        try await repository(for: reference.translationID).passage(for: reference)
    }

    // MARK: Functions (Private Helpers)

    private func repository(for translationID: Translation.ID) -> any BibleRepository {
        routes.first { $0.translationIDs.contains(translationID) }?.repository ?? fallbackRepository
    }
}
