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

    /// Disk and memory, kept across launches; whole chapters of the same translation are
    /// dropped from both, least recently used first, once their verses add up to more
    /// than maximumVerseCount
    case diskLimited(maximumVerseCount: Int)

    /// Whether passages under this policy are read from and written to the disk cache
    var storesOnDisk: Bool {
        switch self {
        case .unlimited, .diskLimited:
            true
        case .memoryOnly:
            false
        }
    }
}
