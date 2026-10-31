//
//  ChapterNavigationDirection.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-10-31.
//

import Foundation

/// nonisolated: plain value type, safe to use from any actor
nonisolated enum ChapterNavigationDirection: CaseIterable {
    case previous
    case next
}
