//
//  BibleCatalogStore.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-08-13.
//

import Observation

@Observable
final class BibleCatalogStore {

    // MARK: Properties (Private)

    private(set) var translations: [Translation] = []

    private let repository: any BibleRepository

    // MARK: Init

    init(repository: any BibleRepository) {
        self.repository = repository
    }

    // MARK: Functions

    /// Assigns to self.translations only if repository.translations() call does not throw
    func loadTranslations(languageTag: String? = "en") async throws {
        let updatedTranslations = try await repository.translations(languageTag: languageTag)
        self.translations = updatedTranslations
    }

    func translation(for id: Translation.ID) -> Translation? {
        return self.translations.first { $0.id == id }
    }
}
