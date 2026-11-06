//
//  PassageCachePolicy.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-05.
//

/// How BiblePassageStore may keep a provider's passages, set by the provider's terms
nonisolated enum PassageCachePolicy: Equatable {
    /// Disk and memory, no limit
    case unlimited

    /// Never written to disk; in memory, least recently used passages of the same
    /// translation are dropped once their verses add up to more than maximumVerseCount
    case memoryOnly(maximumVerseCount: Int)
}
