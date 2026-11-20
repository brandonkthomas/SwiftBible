//
//  PassageHTMLParser.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 7/2/26.
//

import Foundation
import OSLog

// MARK: PassageHTMLParser
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
        return .init(paragraphs: delegate.paragraphs.normalizingIndentation(),
                     footnotes: delegate.footnotes)
    }
}

// MARK: PassageHTMLParserDelegate
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
    private var footnoteText = FootnoteTextBuffer()

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
    private var spanStyles = TextStyleStack()

    /// Text received since the last tag
    ///
    /// XMLParser can split one text node across several foundCharacters calls
    /// (e.g. "John’" + "s"), so text is appended once per node, at the next tag.
    private var pendingText: String = ""

    /// Used for Title tracking
    private var paragraphTextStyle: RenderedPassageTextStyle = []

    // MARK: Properties (Private, Static)

    private static let logger = Logger(subsystem: "SwiftBible", category: "PassageHTMLParserDelegate")

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
        let currentStyle = spanStyles.current.union(paragraphTextStyle)
        flushPendingText(currentStyle: currentStyle)

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
                  (hasClass("yv-n", in: attributeDict) && hasClass("f", in: attributeDict)),
                  let currentVerseRange, // TODO: this will silently skip footnotes appearing BEFORE a verse (!)
                  var paragraph = self.currentParagraph {
            // we're opening a new footnote; start tracking depth + short-circuit
            footnoteDepth = 1
            ignoredFootnoteReferenceDepth = 0
            footnoteText.reset()

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
            // Every new paragraph should set this style + track titles
            if hasClass("d", in: attributeDict) {
                self.paragraphTextStyle = .title
            } else {
                self.paragraphTextStyle = []
            }

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
            spanStyles.push(textStyle(for: attributeDict))
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

            footnoteText.append(string)
            return
        }

        pendingText.append(string)
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
        let currentStyle = spanStyles.current.union(paragraphTextStyle)
        flushPendingText(currentStyle: currentStyle)

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
                                        text: footnoteText.trimmedText)

                footnotes.append(footnote)

                self.currentFootnoteID = nil
                self.footnoteText.reset()
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

        if elementName == "span" {
            spanStyles.pop()
        }

        // Paragraph ended: </div>
        if elementName == "div",
           let finishedParagraph = self.currentParagraph {
            paragraphs.append(finishedParagraph)
            self.currentParagraph = nil
            self.paragraphTextStyle = []
        }
    }

    // MARK: Functions (Private)

    /// Append the text node collected since the last tag
    private func flushPendingText(currentStyle: RenderedPassageTextStyle) {
        let trimmedText = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingText = ""

        guard !trimmedText.isEmpty,
              var currentParagraph else {
            return
        }

        if isInsideVerseLabel {
            // Verse Label
            currentVerseLabelText.append(trimmedText)
        } else {
            // Text (Verse Content)
            currentParagraph.appendText(trimmedText,
                                        style: currentStyle,
                                        verseRange: currentVerseRange)
        }

        // Assign locally-unwrapped copy back to parent
        self.currentParagraph = currentParagraph
    }

    /// Map YouVersion passage HTML classes to SwiftBible render elements.
    ///
    /// YouVersion documents `Passage.content` as either text or HTML, but does not publish
    /// a complete class-name schema. The classes below are observed in API HTML and align
    /// with USFM marker names:
    ///
    /// Paragraph-level classes:
    /// - `p` (`\\p`, normal paragraph) -> `RenderedParagraphStyle.paragraph`
    /// - `m` (`\\m`, margin/continuation paragraph) -> `RenderedParagraphStyle.paragraph`
    /// - `pi`, `pi1`, `pi2` (`\\pi#`, indented paragraph) -> `RenderedParagraphStyle.indentedLine`
    /// - `mi` (`\\mi`, flush-left indented paragraph) -> `RenderedParagraphStyle.indentedLine`
    /// - `q`, `q1` (`\\q#`, first-level poetic line) -> `RenderedParagraphStyle.quoteLine`
    /// - `q2`, `q3`, `q4` (`\\q#`, deeper poetic line) -> `RenderedParagraphStyle.indentedLine`
    /// - `li`, `li1`, `li2` (`\\li#`, list entry) -> `RenderedParagraphStyle.indentedLine`
    ///
    /// Inline classes handled elsewhere in this parser:
    /// - `yv-v` -> verse milestone; updates `RenderedVerseRange` from `v` / `ev` attributes
    /// - `yv-vlbl` -> `RenderedPassageRun.verseLabel`
    /// - `yv-n f` -> `RenderedPassageRun.footnoteMarker` plus a `Footnote`
    /// - `fr` -> footnote origin reference; skipped from displayed footnote text
    /// - `ft`, `fqa`, `fq`, `fk`, `fv` -> footnote body/quote/key/verse text; folded into `Footnote.text`
    /// - `it` -> `RenderedPassageTextStyle.italic`
    /// - `wj` -> `RenderedPassageTextStyle.wordsOfJesus`
    /// - `nd` -> `RenderedPassageTextStyle.divineName`
    private func paragraphStyle(
        for attributes: [String: String]
    ) -> RenderedParagraphStyle? {
        let classes = HTMLClassList.names(in: attributes)

        // unknown... do not append this
        guard !classes.isEmpty else {
            Self.logger.debug("paragraphStyle: no classes for \(attributes); skipping")
            return nil
        }

        for className in classes {
            switch className {
            case "p", "m",
                "pm", "pmo", "pmc", "pmr", // prayer
                "d": // titles (Psalm)
                return .paragraph

            case "q", "q1":
                return .quoteLine

            case "pi", "mi", "li":
                return .indentedLine

            default:
                if isNumberedClass(className, prefix: "pi") ||
                    isNumberedClass(className, prefix: "li") {
                    return .indentedLine
                }

                if let quoteLevel = HTMLClassList.numberedLevel(
                    of: className,
                    prefix: "q"
                ) {
                    return quoteLevel == 1
                        ? .quoteLine
                        : .indentedLine
                }
            }
        }

        // else, we dont know what this is; append it as a paragraph rather than dropping it
        Self.logger.warning("paragraphStyle: no match for classnames \(classes); returning para")
        return .paragraph
    }

    private func isNumberedClass(
        _ className: Substring,
        prefix: String
    ) -> Bool {
        HTMLClassList.numberedLevel(of: className, prefix: prefix) != nil
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

    /// Check an attribute dictionary for an expected class
    private func hasClass(
        _ expectedClass: String,
        in attributes: [String: String]
    ) -> Bool {
        HTMLClassList.contains(expectedClass, in: attributes)
    }
}

// MARK: PassageHTMLParserError
/// PassageHTMLParser error definitions
enum PassageHTMLParserError: Error {
    case invalidHTML
    case parsingError
    case internalError(String)
}
