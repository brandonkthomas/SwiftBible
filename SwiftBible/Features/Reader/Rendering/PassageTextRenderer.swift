//
//  PassageTextRenderer.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 7/5/26.
//

import Foundation
import SwiftUI

struct PassageTextRenderer {

    /// - Collapsed mode renders a single footnote marker at the end of the verse range
    /// - Inline mode renders footnote markers at their exact locations inside the verse
    /// - Hidden mode does not render footnote markers
    enum MarkerMode { case collapsed, inline, hidden }

    // MARK: Functions (Public)

    /// Build an AttributedString for a given set of RenderedPassageRuns
    ///
    /// Used by various application views for uniform passage rendering
    ///
    /// - Collapsed mode renders a single footnote marker at the end of the verse range
    /// - Inline mode renders footnote markers at their exact locations inside the verse
    /// - Hidden mode does not render footnote markers
    static func attributedString(for runs: [RenderedPassageRun],
                                 mode: MarkerMode) -> AttributedString {
        var result = AttributedString()

        // If mode.collapsed:
        // Track verse progress so we can append a single footnote marker at the end
        var accumulatingVerseRange: RenderedVerseRange?   // verse currently being built
        var verseHasFootnote = false

        // If mode.inline:
        // Running count of footnote markers emitted so far; drives the a/b/c label.
        // Not reset per verse so it matches a single continuous footnote list.
        var inlineFootnoteIndex = 0

        // Append footnote marker if current verse has a footnote
        func flushMarkerIfNeeded() {
            guard mode == .collapsed,
                  verseHasFootnote,
                  let verseRange = accumulatingVerseRange else { return }

            let marker = styledVerseEndMarker(for: verseRange)
            result.append(marker)

            verseHasFootnote = false
        }

        // If prev verse just ended, append marker to end of old verse
        // + swap to new verse
        func beginVerseIfChanged(_ verseRange: RenderedVerseRange?) {
            if verseRange != accumulatingVerseRange {
                if mode == .collapsed {
                    flushMarkerIfNeeded()
                }

                accumulatingVerseRange = verseRange
            }
        }

        // Actual output loop
        for run in runs {
            switch run {
            case .text(let runText,
                       verseRange: let currentVerseRange):
                // If prev verse just ended, swap to new verse
                // + append marker to end of old verse
                beginVerseIfChanged(currentVerseRange)

                // append verse text immediately
                let text = styledText(text: runText)
                result.append(text)

            case .verseLabel(displayText: let displayText,
                             verseRange: let currentVerseRange):
                // If prev verse just ended, swap to new verse
                // + append marker to end of old verse
                beginVerseIfChanged(currentVerseRange)

                // append verse label immediately
                let label = styledVerseLabel(displayText: displayText,
                                             verseRange: currentVerseRange)
                result.append(label)

            case .footnoteMarker(let footnoteID,
                                 verseRange: let currentVerseRange):
                switch mode {
                case .collapsed:
                    // don't append right now;
                    // just set a marker that the current verse has footnote(s)
                    verseHasFootnote = true
                case .inline:
                    // If prev verse just ended, swap to new verse
                    beginVerseIfChanged(currentVerseRange)

                    // append a lettered footnote marker (a, b, c...) at this exact spot
                    let marker = styledInlineMarker(index: inlineFootnoteIndex)
                    inlineFootnoteIndex += 1
                    result.append(marker)
                case .hidden:
                    break
                }
            }
        }

        // final call for footnotes
        flushMarkerIfNeeded()

        // we're done!
        return result
    }

    /// Map zero-based footnote index within a verse to its display label (a, b, c...)
    ///
    /// Shared so inline markers and the footnote list below always use identical labels
    static func footnoteSymbol(for index: Int) -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz")
        return String(alphabet[index % alphabet.count])
    }

    // MARK: Functions (Private)

    private static func styledText(text: String) -> AttributedString {
        return AttributedString("\(text) ")
    }

    private static func styledVerseLabel(displayText: String,
                                  verseRange: RenderedVerseRange?) -> AttributedString {
        var label = AttributedString("\(displayText) ")
        label.baselineOffset = 6
        label.font = .system(.caption2, design: .serif)
        label.foregroundColor = .secondary
        return label
    }

    private static func styledInlineMarker(index: Int) -> AttributedString {
        var marker = AttributedString("\(footnoteSymbol(for: index)) ")
        marker.baselineOffset = 6
        marker.font = .system(.caption2, design: .serif, weight: .bold)
        marker.foregroundColor = .accentColor
        return marker
    }

    private static func styledVerseEndMarker(for verseRange: RenderedVerseRange) -> AttributedString {
        var marker = AttributedString("† ")
        marker.baselineOffset = 6
        marker.font = .system(.caption2, design: .serif, weight: .bold)
        marker.foregroundColor = .accentColor

        // NOTE: this will allow iOS long-press behavior; to replace
        var url = "swiftbible://footnote?sv=\(verseRange.startVerse)"

        if let endVerse = verseRange.endVerse {
            url.append("&ev=\(endVerse)")
        }
        marker.link = URL(string: url)
        return marker
    }
}
