//
//  PassageCache.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-09-25.
//

import Foundation

/// Implementations for passage cache storage / access
///
/// "throws" required because disk access can technically fail
protocol PassageCache {
    /// Retrieves cached passage for the given key
    func passage(for key: BiblePassageKey) async throws -> Passage?

    /// Persists passage to cache for the given key
    func save(_ passage: Passage, for key: BiblePassageKey) async throws

    /// Removes the cached passage for the given key; nothing cached is not an error
    func removePassage(for key: BiblePassageKey) async throws

    /// The saved list of one translation's verse-limited chapters, least recently used first
    ///
    /// Also removes this translation's cached passages the list does not include, and drops
    /// entries whose passage is gone, so every stored chapter is counted against the limit
    func verseLimitEntries(for translationID: Translation.ID) async throws -> [PassageCacheEntry]

    /// Replaces the saved list of one translation's verse-limited chapters
    func saveVerseLimitEntries(_ entries: [PassageCacheEntry],
                               for translationID: Translation.ID) async throws
}
