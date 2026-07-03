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
        return .init(paragraphs: delegate.paragraphs)
    }
}

/// Specialized delegate implementation for PassageHTMLParser's XMLParser
private nonisolated final class PassageHTMLParserDelegate: NSObject, XMLParserDelegate {

    // MARK: Properties

    /// finished output
    var paragraphs: [RenderedParagraph] = []

    /// paragrph we're currently viewing
    private var currentParagraph: RenderedParagraph?

    /// true after <span class="yv-vlbl">
    private var isInsideVerseLabel: Bool = false

    /// increments after <span class="yv-n f">
    private var footnoteDepth: Int = 0

    // MARK: Functions (Delegate)

    /// Sent by parser when it encounters a start tag for a given element
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
            return
        } else if elementName == "span",
                  attributeDict["class"] == "yv-n f" {
            // we're opening a new footnote; start tracking depth + short-circuit
            footnoteDepth = 1
            return
        }

        // New paragraph: <div class="p">
        if elementName == "div",
           (attributeDict["class"] == "p" || attributeDict["class"] == "q1") {
            currentParagraph = .init(runs: [])
        }

        // Verse: <span class="yv-vlbl">
        if elementName == "span",
           attributeDict["class"] == "yv-vlbl" {
            isInsideVerseLabel = true
        }
    }

    /// Sent by parser when it encounters a specific character
    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
        // we should not append footnotes
        guard footnoteDepth == 0 else {
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
            currentParagraph.runs.append(.verseLabel(trimmedCharacters))
        } else {
            currentParagraph.runs.append(.text(trimmedCharacters))
        }

        // Assign locally-unwrapped copy back to parent
        self.currentParagraph = currentParagraph
    }

    /// Sent by parser when it encounters an end tag for a given element
    ///
    /// Inherited from XMLParserDelegate
    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if footnoteDepth > 0 {
            // we're already inside a footnote; keep tracking depth + short-circuit
            footnoteDepth -= 1
            return
        }

        // Verse ended: </span>
        if elementName == "span",
           isInsideVerseLabel {
            isInsideVerseLabel = false
        }

        // Paragraph ended: </div>
        if elementName == "div" {
            if let finishedParagraph = self.currentParagraph {
                paragraphs.append(finishedParagraph)
                self.currentParagraph = nil
            }
        }
    }
}
/// PassageHTMLParser error definitions
enum PassageHTMLParserError: Error {
    case invalidHTML
    case parsingError
    case internalError(String)
}
