//
//  InMemoryCatalogCache.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-10-21.
//

import Foundation

final class InMemoryCatalogCache: CatalogCache {

    // MARK: Variables (Private)

    /// Maps language tag keys => translations
    private var translationCache: [String: [Translation]] = [:]

    /// Maps translation ID keys => books
    private var bookCache: [Translation.ID: [Book]] = [:]

    // MARK: Functions

    /// Retrieves cached translation list for a given language
    func translations(for languageTag: String) async throws -> [Translation]? {
        return self.translationCache[languageTag] // this is optional
    }

    /// Persists a given translation collection to the in-memory cache
    /// (requires language tag as PK)
    ///
    /// Replaces the key if it already exists
    func save(_ translations: [Translation], for languageTag: String) async throws {
        self.translationCache[languageTag] = translations
    }

    /// Retrieves cached book list for a given translation
    func books(for translationID: Translation.ID) async throws -> [Book]? {
        return self.bookCache[translationID] // this is optional
    }

    /// Persists a given book collection to the in-memory cache
    /// (requires translation ID as PK)
    ///
    /// Replaces the key if it already exists
    func save(_ books: [Book], for translationID: Translation.ID) async throws {
        self.bookCache[translationID] = books
    }
}
