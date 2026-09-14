//
//  BiblePassageKey.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-09-02.
//

import Foundation

/// Stable hashable (+ equatable) identity for one translation-specific chapter
///
/// Passage.ID cannot do this since it only gives us book + chapter
nonisolated struct BiblePassageKey: Hashable {
    let translationID: Translation.ID
    let bookCode: String
    let chapter: Int
}
