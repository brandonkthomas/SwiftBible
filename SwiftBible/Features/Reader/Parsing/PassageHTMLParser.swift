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

    /// true after <span class="ft">
    private var isInsideFootnoteText: Bool = false

    /// increments after <span class="yv-n f">
    private var footnoteDepth: Int = 0

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
            
            if elementName == "span",
               attributeDict["class"] == "ft" {
                isInsideFootnoteText = true
            }

            return
        } else if elementName == "span",
                  attributeDict["class"] == "yv-n f",
                  let currentVerseRange, // TODO: this will silently skip footnotes appearing BEFORE a verse (!)
                  var paragraph = self.currentParagraph {
            // we're opening a new footnote; start tracking depth + short-circuit
            footnoteDepth = 1
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

        // New paragraph: <div class="p">
        if elementName == "div",
           (attributeDict["class"] == "p" || attributeDict["class"] == "q1") {
            currentParagraph = .init(runs: [])
        }

        // Verse metadata: <span class="yv-v" v="26" ev="27">
        if elementName == "span",
           attributeDict["class"] == "yv-v" {
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
           attributeDict["class"] == "yv-vlbl" {
            isInsideVerseLabel = true
            currentVerseLabelText = ""
        }
    }

    /// Sent by parser when it encounters a specific character
    ///
    /// Inherited from XMLParserDelegate
    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
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
        } else if footnoteDepth > 0 {
            // Footnote
            // Ignore non-text footnote items (i.e. "1:1")
            if isInsideFootnoteText {
                currentFootnoteText.append(trimmedCharacters)
            } else {
                return
            }
        } else {
            // Text (Verse Content)
            currentParagraph.runs.append(.text(trimmedCharacters,
                                               verseRange: currentVerseRange))
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

            if elementName == "span",
               isInsideFootnoteText {
                isInsideFootnoteText = false
            }

            // we just closed a footnote; wrap up our tracking
            if footnoteDepth == 0,
               let currentFootnoteID,
               let currentVerseRange {
                let footnote = Footnote(id: currentFootnoteID,
                                        verseRange: currentVerseRange,
                                        text: currentFootnoteText)

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

        // Paragraph ended: </div>
        if elementName == "div",
           let finishedParagraph = self.currentParagraph {
            paragraphs.append(finishedParagraph)
            self.currentParagraph = nil
        }
    }
}
/// PassageHTMLParser error definitions
enum PassageHTMLParserError: Error {
    case invalidHTML
    case parsingError
    case internalError(String)
}
