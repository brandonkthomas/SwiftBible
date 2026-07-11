//
//  PassageHTMLParser.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 7/2/26.
//

import Foundation

/// Handles parsing/rendering of YouVersion API's passage HTML responses into usable SwiftUI
nonisolated struct PassageHTMLParser {

    /// Parse / render a single passage
    func parse(html: String) throws -> RenderedPassage {

        // ensure 1 root element
        let htmlComplete = "<div>\(html)</div>"

        // configure parser + handler delegate
        guard let data = htmlComplete.data(using: .utf8) else {
            throw PassageHTMLParserError.invalidHTML
        }

        let delegate = PassageHTMLParserDelegate()

        let xmlParser: XMLParser = XMLParser(data: data)
        xmlParser.delegate = delegate

        // try to parse
        guard xmlParser.parse() else {
            throw PassageHTMLParserError.parsingError
        }

        // return parser/delegate results
        return .init(paragraphs: delegate.paragraphs,
                     footnotes: delegate.footnotes)
    }
}

/// Specialized delegate implementation for PassageHTMLParser's XMLParser
private nonisolated final class PassageHTMLParserDelegate: NSObject, XMLParserDelegate {

    // MARK: Properties

    /// finished output
    var paragraphs: [RenderedParagraph] = []
    var footnotes: [Footnote] = []

    /// paragrph we're currently viewing
    private var currentParagraph: RenderedParagraph?

    /// footnote we're currently rendering
    private var currentFootnoteID: Footnote.ID?
    private var nextFootnoteID: Footnote.ID = 0

    /// buffer for footnote text we're currently rendering (XMLParser is streaming)
    private var currentFootnoteText: String = ""

    /// Which verse range are we currently rendering?
    private var currentVerseRange: RenderedVerseRange?

    /// buffer for current verse label text we're currently rendering (XMLParser is streaming)
    private var currentVerseLabelText: String = ""

    /// true after <span class="yv-vlbl">
    private var isInsideVerseLabel: Bool = false

    /// increments after <span class="yv-n f">
    private var footnoteDepth: Int = 0

    /// increments after <span class="fr"> inside a footnote
    private var ignoredFootnoteReferenceDepth: Int = 0

    /// Tracks inline span styles that apply to passage text.
    private var spanStyleStack: [RenderedPassageTextStyle?] = []

    // MARK: Functions (Delegate)

    /// Sent by parser when it encounters a start tags for a given element
    ///
    /// Inherited from XMLParserDelegate
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        if footnoteDepth > 0 {
            // we're already inside a footnote; keep tracking depth + short-circuit
            footnoteDepth += 1

            // footnote tracking logic
            if ignoredFootnoteReferenceDepth > 0 {
                ignoredFootnoteReferenceDepth += 1
            } else if elementName == "span",
                      hasClass("fr", in: attributeDict) {
                ignoredFootnoteReferenceDepth = 1
            }

            return
        } else if elementName == "span",
                  attributeDict["class"] == "yv-n f",
                  let currentVerseRange, // TODO: this will silently skip footnotes appearing BEFORE a verse (!)
                  var paragraph = self.currentParagraph {
            // we're opening a new footnote; start tracking depth + short-circuit
            footnoteDepth = 1
            ignoredFootnoteReferenceDepth = 0
            currentFootnoteText = ""

            let footnoteID = nextFootnoteID
            nextFootnoteID += 1
            currentFootnoteID = footnoteID

            // drop a marker at this exact spot
            paragraph.runs.append(.footnoteMarker(footnoteID,
                                                  verseRange: currentVerseRange))

            // Assign locally-unwrapped copy back to parent
            self.currentParagraph = paragraph

            return
        }

        // New paragraph: <div class="p">, <div class="q1">, etc.
        if elementName == "div",
           let paragraphStyle = paragraphStyle(for: attributeDict) {
            currentParagraph = .init(style: paragraphStyle,
                                     runs: [])
        }

        // Verse metadata: <span class="yv-v" v="26" ev="27">
        if elementName == "span",
           hasClass("yv-v", in: attributeDict) {
            if let startVerseText = attributeDict["v"],
               let startVerse = Int(startVerseText) {
                let endVerse = attributeDict["ev"].flatMap { Int($0) }
                currentVerseRange = .init(startVerse: startVerse,
                                          endVerse: endVerse)
            } else {
                currentVerseRange = nil
            }
        }

        // Verse: <span class="yv-vlbl">
        if elementName == "span",
           hasClass("yv-vlbl", in: attributeDict) {
            isInsideVerseLabel = true
            currentVerseLabelText = ""
        }

        if elementName == "span" {
            spanStyleStack.append(textStyle(for: attributeDict))
        }
    }

    /// Sent by parser when it encounters a specific character
    ///
    /// Inherited from XMLParserDelegate
    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
        if footnoteDepth > 0 {
            guard ignoredFootnoteReferenceDepth == 0 else {
                return
            }

            appendFootnoteText(string)
            return
        }

        // Clean up input
        let trimmedCharacters = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validation
        guard !trimmedCharacters.isEmpty,
              var currentParagraph else {
            return
        }

        // Append results
        if isInsideVerseLabel {
            // Verse Label
            currentVerseLabelText.append(trimmedCharacters)
        } else {
            // Text (Verse Content)
            appendPassageText(trimmedCharacters,
                              style: currentTextStyle,
                              to: &currentParagraph)
        }

        // Assign locally-unwrapped copy back to parent
        self.currentParagraph = currentParagraph
    }

    /// Sent by parser when it encounters an end tags for a given element
    ///
    /// Inherited from XMLParserDelegate
    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        // we're already inside a footnote; keep tracking depth + short-circuit
        if footnoteDepth > 0 {
            footnoteDepth -= 1

            if ignoredFootnoteReferenceDepth > 0 {
                ignoredFootnoteReferenceDepth -= 1
            }

            // we just closed a footnote; wrap up our tracking
            if footnoteDepth == 0,
               let currentFootnoteID,
               let currentVerseRange {
                let footnote = Footnote(id: currentFootnoteID,
                                        verseRange: currentVerseRange,
                                        text: currentFootnoteText.trimmingCharacters(in: .whitespacesAndNewlines))

                footnotes.append(footnote)

                self.currentFootnoteID = nil
                self.currentFootnoteText = ""
            }

            // we're done here
            return
        }

        // Verse ended: </span>
        if elementName == "span",
           isInsideVerseLabel,
           var paragraph = self.currentParagraph {
            isInsideVerseLabel = false

            paragraph.runs.append(.verseLabel(displayText: currentVerseLabelText,
                                              verseRange: currentVerseRange))

            self.currentParagraph = paragraph
            self.currentVerseLabelText = ""
        }

        if elementName == "span",
           !spanStyleStack.isEmpty {
            _ = spanStyleStack.removeLast()
        }

        // Paragraph ended: </div>
        if elementName == "div",
           let finishedParagraph = self.currentParagraph {
            paragraphs.append(finishedParagraph)
            self.currentParagraph = nil
        }
    }

    // MARK: Functions (Private)

    private var currentTextStyle: RenderedPassageTextStyle {
        spanStyleStack.reduce(into: []) { style, activeStyle in
            if let activeStyle {
                style.formUnion(activeStyle)
            }
        }
    }

    /// Parse YouVersion HTML classes into corresponding paragraph styles (indented line, quote line, paragraph)
    private func paragraphStyle(for attributes: [String: String]) -> RenderedParagraphStyle? {
        if hasClass("mi", in: attributes) {
            return .indentedLine
        } else if hasClass("q1", in: attributes) {
            return .quoteLine
        } else if hasClass("p", in: attributes) || hasClass("m", in: attributes) {
            return .paragraph
        } else {
            return nil
        }
    }

    /// Parse YouVersion HTML classes into corresponding text styles (italic, words of Jesus, divine name)
    private func textStyle(for attributes: [String: String]) -> RenderedPassageTextStyle? {
        var style: RenderedPassageTextStyle = []

        if hasClass("it", in: attributes) {
            style.insert(.italic)
        }

        if hasClass("wj", in: attributes) {
            style.insert(.wordsOfJesus)
        }

        if hasClass("nd", in: attributes) {
            style.insert(.divineName)
        }

        return style.isEmpty ? nil : style
    }

    /// Check an attribute dict for an expected class
    private func hasClass(_ expectedClass: String,
                          in attributes: [String: String]) -> Bool {
        guard let classValue = attributes["class"] else {
            return false
        }

        return classValue
            .split(separator: " ")
            .contains(Substring(expectedClass))
    }

    /// Append passage text
    private func appendPassageText(_ text: String,
                                   style: RenderedPassageTextStyle,
                                   to paragraph: inout RenderedParagraph) {
        if shouldAttachToPreviousRun(text),
           let lastIndex = paragraph.runs.indices.last {
            switch paragraph.runs[lastIndex] {
            case .text(let previousText, verseRange: let verseRange):
                paragraph.runs[lastIndex] = .text(previousText + text,
                                                  verseRange: verseRange)
                return
            case .styledText(let previousText,
                             style: let previousStyle,
                             verseRange: let verseRange):
                paragraph.runs[lastIndex] = .styledText(previousText + text,
                                                        style: previousStyle,
                                                        verseRange: verseRange)
                return
            case .verseLabel, .footnoteMarker:
                break
            }
        }

        if style.isEmpty {
            paragraph.runs.append(.text(text,
                                        verseRange: currentVerseRange))
        } else {
            paragraph.runs.append(.styledText(text,
                                              style: style,
                                              verseRange: currentVerseRange))
        }
    }

    /// Append footnote text
    private func appendFootnoteText(_ text: String) {
        let collapsedText = text.replacingOccurrences(of: "\\s+",
                                                      with: " ",
                                                      options: .regularExpression)

        guard !collapsedText.isEmpty else {
            return
        }

        if collapsedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if !currentFootnoteText.isEmpty,
               !currentFootnoteText.hasSuffix(" ") {
                currentFootnoteText.append(" ")
            }
        } else {
            currentFootnoteText.append(collapsedText)
        }
    }

    /// Should this attach to the previous run?
    private func shouldAttachToPreviousRun(_ text: String) -> Bool {
        guard let firstCharacter = text.first else {
            return false
        }

        return ",.;:!?)”’".contains(firstCharacter)
    }
}
/// PassageHTMLParser error definitions
enum PassageHTMLParserError: Error {
    case invalidHTML
    case parsingError
    case internalError(String)
}
