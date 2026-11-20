//
//  PassageRunBuilding.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-05.
//

import Foundation

// Helpers shared by every provider's XMLParser delegate

// MARK: - HTML class attribute

/// Reads the whitespace-separated `class` attribute of an XMLParser element
nonisolated enum HTMLClassList {

    /// Return every class in its original order
    static func names(in attributes: [String: String]) -> [Substring] {
        guard let classValue = attributes["class"] else {
            return []
        }

        return classValue.split(whereSeparator: \.isWhitespace)
    }

    /// Check an attribute dictionary for an expected class
    static func contains(_ expectedClass: String,
                         in attributes: [String: String]) -> Bool {
        names(in: attributes).contains { $0 == expectedClass }
    }

    /// Level of a numbered class: `q2` with prefix `q` -> 2; `q` or `qa` -> nil
    static func numberedLevel(of className: Substring,
                              prefix: String) -> Int? {
        guard className.hasPrefix(prefix) else {
            return nil
        }

        let levelText = className.dropFirst(prefix.count)

        guard !levelText.isEmpty else {
            return nil
        }

        return Int(levelText)
    }
}

// MARK: - Inline text styles

/// Tracks the text style each open <span> applies; nested spans combine
nonisolated struct TextStyleStack {

    private var styles: [RenderedPassageTextStyle?] = []

    /// Union of every open span's style
    var current: RenderedPassageTextStyle {
        styles.reduce(into: []) { style, activeStyle in
            if let activeStyle {
                style.formUnion(activeStyle)
            }
        }
    }

    /// Call on every <span> open; pass nil for a span with no style
    mutating func push(_ style: RenderedPassageTextStyle?) {
        styles.append(style)
    }

    /// Call on every </span>
    mutating func pop() {
        if !styles.isEmpty {
            _ = styles.removeLast()
        }
    }
}

// MARK: - Footnote text

/// Collects footnote text across XMLParser's streamed character callbacks
nonisolated struct FootnoteTextBuffer {

    private(set) var text: String = ""

    /// Text with leading/trailing whitespace removed, for `Footnote.text`
    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Append text, collapsing runs of whitespace to one space
    mutating func append(_ string: String) {
        let collapsedText = string.replacingOccurrences(of: "\\s+",
                                                        with: " ",
                                                        options: .regularExpression)

        guard !collapsedText.isEmpty else {
            return
        }

        if collapsedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if !text.isEmpty,
               !text.hasSuffix(" ") {
                text.append(" ")
            }
        } else {
            text.append(collapsedText)
        }
    }

    mutating func reset() {
        text = ""
    }
}

// MARK: - Paragraph styles

nonisolated extension Array where Element == RenderedParagraph {

    /// If every paragraph is indented, treat the passage as regular body text
    func normalizingIndentation() -> [RenderedParagraph] {
        let hasBodyParagraph = contains { $0.style == .paragraph }

        guard !hasBodyParagraph else {
            return self
        }

        return map { paragraph in
            RenderedParagraph(style: .paragraph, runs: paragraph.runs)
        }
    }
}

// MARK: - Passage text runs

nonisolated extension RenderedParagraph {

    /// Append passage text as a `.text` or `.styledText` run
    ///
    /// Leading closing punctuation (`,.;:!?)”’`) is moved onto the previous text run,
    /// so the renderer does not insert a space before it.
    mutating func appendText(_ text: String,
                             style: RenderedPassageTextStyle,
                             verseRange: RenderedVerseRange?) {
        var textToAppend = text

        if shouldAttachToPreviousRun(textToAppend),
           let lastIndex = runs.indices.last,
           let splitText = splitLeadingPunctuation(from: textToAppend) {
            var didAttachLeadingPunctuation = false

            switch runs[lastIndex] {
            case .text(let previousText, verseRange: let previousVerseRange):
                runs[lastIndex] = .text(previousText + splitText.leadingPunctuation,
                                        verseRange: previousVerseRange)
                didAttachLeadingPunctuation = true
            case .styledText(let previousText,
                             style: let previousStyle,
                             verseRange: let previousVerseRange):
                runs[lastIndex] = .styledText(previousText + splitText.leadingPunctuation,
                                              style: previousStyle,
                                              verseRange: previousVerseRange)
                didAttachLeadingPunctuation = true
            case .verseLabel, .footnoteMarker:
                break
            }

            if didAttachLeadingPunctuation {
                textToAppend = splitText.remainder
            }
        }

        guard !textToAppend.isEmpty else {
            return
        }

        if style.isEmpty {
            runs.append(.text(textToAppend,
                              verseRange: verseRange))
        } else {
            runs.append(.styledText(textToAppend,
                                    style: style,
                                    verseRange: verseRange))
        }
    }

    /// Should this attach to the previous run (i.e. does this start w/ punctuation)?
    private func shouldAttachToPreviousRun(_ text: String) -> Bool {
        guard let firstCharacter = text.first else {
            return false
        }

        return ",.;:!?)”’".contains(firstCharacter)
    }

    private func splitLeadingPunctuation(from text: String) -> (leadingPunctuation: String, remainder: String)? {
        let punctuationCharacters = CharacterSet(charactersIn: ",.;:!?)”’")
        let leadingPunctuation = text.prefix { character in
            String(character).rangeOfCharacter(from: punctuationCharacters.inverted) == nil
        }

        guard !leadingPunctuation.isEmpty else {
            return nil
        }

        let remainderStartIndex = text.index(text.startIndex,
                                             offsetBy: leadingPunctuation.count)
        let remainder = text[remainderStartIndex...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (String(leadingPunctuation), remainder)
    }
}
