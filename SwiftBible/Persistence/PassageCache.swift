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
}
