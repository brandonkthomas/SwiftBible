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
}
