//
//  RenderedPassageRun.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 7/5/26.
//

import Foundation

/// A single run extracted from a passage's HTML
nonisolated enum RenderedPassageRun: Equatable {
    case text(String, verseRange: RenderedVerseRange?)
    case verseLabel(displayText: String, verseRange: RenderedVerseRange?)
    case footnoteMarker(Footnote.ID, verseRange: RenderedVerseRange)

    /// Computed VerseRange extraction from within each case
    var verseRange: RenderedVerseRange? {
        switch self {
        case .text(_, verseRange: let verseRange): return verseRange
        case .verseLabel(_, verseRange: let verseRange): return verseRange
        case .footnoteMarker(_, verseRange: let verseRange): return verseRange
        }
    }
}
