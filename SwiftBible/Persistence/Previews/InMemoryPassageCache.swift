//
//  InMemoryPassageCache.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-09-25.
//

import Foundation

final class InMemoryPassageCache: PassageCache {

    // MARK: Variables (Private)

    /// Maps keys => Passage
    private var cache: [BiblePassageKey: Passage] = [:]

    /// Verse-limited chapter lists per translation, least recently used first
    private var verseLimitEntriesByTranslation: [Translation.ID: [PassageCacheEntry]] = [:]

    // MARK: Functions

    /// Returns cached Passage for a given BiblePassageKey if cached in memory; else nil
    func passage(for key: BiblePassageKey) async throws -> Passage? {
        return self.cache[key] // this is optional
    }

    /// Persists given Passage to the in-memory cache for the given BiblePassageKey
    ///
    /// Replaces the key if it already exists
    func save(_ passage: Passage, for key: BiblePassageKey) async throws {
        self.cache[key] = passage
    }

    /// Removes the cached Passage for a key, if any
    func removePassage(for key: BiblePassageKey) async throws {
        self.cache[key] = nil
    }

    /// Same contract as DiskPassageCache: drops entries without a passage, and removes this
    /// translation's passages the list does not include
    func verseLimitEntries(for translationID: Translation.ID) async throws -> [PassageCacheEntry] {
        let entries = (verseLimitEntriesByTranslation[translationID] ?? [])
            .filter { cache[$0.key] != nil }

        let listedKeys = Set(entries.map(\.key))
        cache = cache.filter { key, _ in
            key.translationID != translationID || listedKeys.contains(key)
        }

        verseLimitEntriesByTranslation[translationID] = entries
        return entries
    }

    /// Replaces one translation's verse-limited chapter list
    func saveVerseLimitEntries(_ entries: [PassageCacheEntry],
                               for translationID: Translation.ID) async throws {
        verseLimitEntriesByTranslation[translationID] = entries
    }
}
