//
//  RenderedPassageRun.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 7/5/26.
//

import Foundation

nonisolated struct RenderedPassageTextStyle: OptionSet, Equatable {
    let rawValue: Int

    static let italic = RenderedPassageTextStyle(rawValue: 1 << 0)
    static let wordsOfJesus = RenderedPassageTextStyle(rawValue: 1 << 1)
    static let divineName = RenderedPassageTextStyle(rawValue: 1 << 2)
}

/// A single run extracted from a passage's HTML
nonisolated enum RenderedPassageRun: Equatable {
    case text(String, verseRange: RenderedVerseRange?)
    case styledText(String, style: RenderedPassageTextStyle, verseRange: RenderedVerseRange?)
    case verseLabel(displayText: String, verseRange: RenderedVerseRange?)
    case footnoteMarker(Footnote.ID, verseRange: RenderedVerseRange)

    /// Computed VerseRange extraction from within each case
    var verseRange: RenderedVerseRange? {
        switch self {
        case .text(_, verseRange: let verseRange): return verseRange
        case .styledText(_, style: _, verseRange: let verseRange): return verseRange
        case .verseLabel(_, verseRange: let verseRange): return verseRange
        case .footnoteMarker(_, verseRange: let verseRange): return verseRange
        }
    }
}
