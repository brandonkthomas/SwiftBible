//
//  BibleRepository.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

/// Implementations for Bible translation/index API access
protocol BibleRepository {
    /// Returns all available translations (optionally filtered by a given language; i.e. "en")
    func translations(languageTag: String?) async throws -> [Translation]

    /// Returns all available books for a given translation w/ canon and individual chapters
    func books(for translationID: Translation.ID) async throws -> [Book]

    /// Returns HTML passage content for the selected reference
    func passage(for reference: ScriptureReference) async throws -> Passage
}

enum BibleRepositoryError: Error {
    case invalidRequestURL
    case internalError(String)
}
