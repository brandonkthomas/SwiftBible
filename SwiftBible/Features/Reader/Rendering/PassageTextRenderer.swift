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

    /// Build a Text view for a given set of RenderedPassageRuns
    ///
    /// Used by various application views for uniform passage rendering
    ///
    /// - Collapsed mode renders a single footnote marker at the end of the verse range
    /// - Inline mode renders footnote markers at their exact locations inside the verse
    /// - Hidden mode does not render footnote markers
    static func text(for runs: [RenderedPassageRun],
                     mode: MarkerMode) -> Text {
        var result = Text("")

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

            // '+' was deprecated in iOS 26.0:
            // Use string interpolation on `Text` instead: `Text("Hello \(name)")`
            result = Text("\(result)\(marker)")

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
                let text = styledText(runText,
                                      verseRange: currentVerseRange,
                                      useLinkAttribute: true)

                var segment = Text(text)

                if let currentVerseRange {
                    segment = segment
                        .customAttribute(VerseNumberAttribute(number: currentVerseRange.startVerse))
                }

                result = Text("\(result)\(segment)")

            case .verseLabel(displayText: let displayText,
                             verseRange: let currentVerseRange):
                // If prev verse just ended, swap to new verse
                // + append marker to end of old verse
                beginVerseIfChanged(currentVerseRange)

                // append verse label immediately
                let label = styledVerseLabel(displayText: displayText,
                                             verseRange: currentVerseRange)

                let segment = Text(label)

//                if let currentVerseRange {
//                    segment = segment
//                        .customAttribute(VerseNumberAttribute(number: currentVerseRange.startVerse))
//                }

                result = Text("\(result)\(segment)")

            case .footnoteMarker(_,
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

                    result = Text("\(result)\(marker)")
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

    private static func styledText(_ text: String,
                                   verseRange: RenderedVerseRange?,
                                   useLinkAttribute: Bool = false) -> AttributedString {
        var result = AttributedString("\(text) ")

        // Tap link (adds support for verse selection via tap action)
        if useLinkAttribute,
           let verseRange {
            var url = "swiftbible://verse?sv=\(verseRange.startVerse)"
            if let endVerse = verseRange.endVerse {
                url.append("&ev=\(endVerse)")
            }
            result.link = URL(string: url)
            result.foregroundColor = .primary
        }

        return result
    }

    private static func styledVerseLabel(displayText: String,
                                         verseRange: RenderedVerseRange?) -> AttributedString {
        var result = AttributedString("\(displayText) ")
        result.baselineOffset = 6
        result.font = .system(.caption2, design: .serif)
        result.foregroundColor = .secondary

        return result
    }

    private static func styledInlineMarker(index: Int) -> AttributedString {
        var result = AttributedString("\(footnoteSymbol(for: index)) ")
        result.baselineOffset = 6
        result.font = .system(.caption2, design: .serif, weight: .bold)
        result.foregroundColor = .accentColor

        return result
    }

    private static func styledVerseEndMarker(for verseRange: RenderedVerseRange) -> AttributedString {
        var result = AttributedString("† ")
        result.baselineOffset = 6
        result.font = .system(.caption2, design: .serif, weight: .bold)
        result.foregroundColor = .accentColor

        // Tap link (adds support for opening ReaderPassageFootnoteSheetView via tap action)
        var url = "swiftbible://footnote?sv=\(verseRange.startVerse)"
        if let endVerse = verseRange.endVerse {
            url.append("&ev=\(endVerse)")
        }
        result.link = URL(string: url)

        return result
    }

//    private static func isSelected(_ verseRange: RenderedVerseRange?,
//                    in selection: ClosedRange<Int>?) -> Bool {
//        guard let verseRange,
//              let selection else {
//            return false
//        }
//        return selection.contains(verseRange.startVerse)
//    }
}
