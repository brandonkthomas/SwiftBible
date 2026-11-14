//
//  PassageCacheEntry.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-13.
//

import Foundation

/// One cached chapter under a .diskLimited policy, with the verse count it adds to the limit
///
/// Saved in a list beside the cached passages so the verse count and least recently used
/// order survive app launches
nonisolated struct PassageCacheEntry: Codable, Equatable {
    let key: BiblePassageKey
    let verseCount: Int
}
