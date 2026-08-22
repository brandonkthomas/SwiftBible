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

    /// BibleRepository implementation
    private let repository: any BibleRepository
    
    /// All available translations
    ///
    /// private(set) allows only us to write; all other external referencers can read
    private(set) var translations: [Translation] = []
    
    /// All available books; each mapped to one translation
    private var booksByTranslation: [Translation.ID: [Book]] = [:]

    // MARK: Init

    init(repository: any BibleRepository) {
        self.repository = repository
    }

    // MARK: Functions
    
    // Translations

    /// Assigns to self.translations only if repository.translations() call does not throw
    func loadTranslations(languageTag: String? = "en") async throws {
        let updatedTranslations = try await repository.translations(languageTag: languageTag)
        self.translations = updatedTranslations
    }

    /// Retrieve a Translation by ID (from memory)
    func translation(for id: Translation.ID) -> Translation? {
        return self.translations.first { $0.id == id }
    }
    
    // Books
    
    /// Load books using given BibleRepository implementation
    func loadBooks(for translationID: Translation.ID) async throws {
        self.booksByTranslation[translationID] = try await repository.books(for: translationID)
    }
    
    /// Retrieve all books for a given Translation.ID (from memory)
    func books(for translationID: Translation.ID) -> [Book]? {
        return self.booksByTranslation[translationID]
    }
    
    /// Retrieve a specific book by code + its Translation.ID (from memory)
    func book(for translationID: Translation.ID,
              bookCode: String) -> Book? {
        guard let books = books(for: translationID) else {
            return nil
        }
        return books.first { $0.code == bookCode }
    }
}
