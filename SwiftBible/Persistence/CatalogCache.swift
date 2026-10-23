//
//  CatalogCache.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-10-21.
//

import Foundation

/// Shared cache for Translations & Books
///
/// "throws" required because disk access can technically fail
protocol CatalogCache {
    /// Retrieves cached translation list for a given language
    func translations(for languageTag: String) async throws -> [Translation]?

    /// Overwrites cache contents with a given translation collection
    /// (requires language tag as PK)
    func save(_ translations: [Translation], for languageTag: String) async throws

    /// Retrieves cached book list for a given translation
    func books(for translationID: Translation.ID) async throws -> [Book]?

    /// Overwrites cache contents with a given book collection
    /// (requires translation ID as PK)
    func save(_ books: [Book], for translationID: Translation.ID) async throws
}
