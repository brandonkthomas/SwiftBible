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
        // <div class="p"> encountered; set currentParagraph to new empty item
        if elementName == "div",
           attributeDict["class"] == "p" {
            currentParagraph = .init(runs: [])
        }

        // <span class="yv-vlbl"> encountered; this is verse content
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
        // </span> encountered; this is end of verse content
        if elementName == "span" {
            isInsideVerseLabel = false
        }

        // </div> encountered; set currentParagraph to new empty item
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
