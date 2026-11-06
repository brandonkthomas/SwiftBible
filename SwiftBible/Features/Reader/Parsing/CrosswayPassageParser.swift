//
//  CrosswayPassageParser.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-05.
//

import Foundation

/// Handles parsing of ESV API passage HTML (`passages[0]` from /v3/passage/html/)
nonisolated struct CrosswayPassageParser {

    func parse(html: String) throws -> RenderedPassage {
        // XMLParser only knows XML's five entities; ESV uses &nbsp; after verse numbers
        // and as poetry indent padding. A plain space is trimmed like any other.
        let markup = "<div>\(html.replacingOccurrences(of: "&nbsp;", with: " "))</div>"

        let delegate = CrosswayPassageParserDelegate()

        let xmlParser = XMLParser(data: Data(markup.utf8))
        xmlParser.delegate = delegate

        guard xmlParser.parse() else {
            throw PassageHTMLParserError.parsingError
        }

        return .init(paragraphs: delegate.paragraphs.normalizingIndentation(),
                     footnotes: delegate.footnotes)
    }
}

/// XMLParser delegate for ESV passage HTML
///
/// Markup observed in ESV responses:
///
/// Paragraph-level:
/// - `<p>` (any class: `starts-chapter`, `virtual`, none) -> `RenderedParagraphStyle.paragraph`
/// - `<span class="line">` inside `<p class="block-indent">` -> `RenderedParagraphStyle.quoteLine`
/// - `<span class="indent line">` -> `RenderedParagraphStyle.indentedLine`
///
/// Skipped with everything inside them:
/// - `h1`-`h6` (section headings, `psalm-title`)
/// - `<div class="footnotes">` (footnote bodies are read from each marker's `title` instead)
/// - `<a class="copyright">` and the "(ESV)" paragraph around it
///
/// Inline:
/// - `<b class="verse-num" id="v43003002-1">` and `<b class="chapter-num">` ->
///   `RenderedPassageRun.verseLabel`; the verse number comes from the id (book/chapter/verse
///   packed as BBCCCVVV), so "3:1" chapter labels display as "1"
/// - `<sup class="footnote"><a class="fn" title="...">` -> `RenderedPassageRun.footnoteMarker`
///   plus a `Footnote`; `title` holds the note as escaped HTML
/// - `woc` -> `.wordsOfJesus`, `divine-name` -> `.divineName`, `<i>`/`<em>` -> `.italic`
private nonisolated final class CrosswayPassageParserDelegate: NSObject, XMLParserDelegate {

    // MARK: Properties

    /// finished output
    var paragraphs: [RenderedParagraph] = []
    var footnotes: [Footnote] = []

    /// paragraph (or poetry line) we're currently building
    private var currentParagraph: RenderedParagraph?

    /// set by each verse/chapter number
    private var currentVerseRange: RenderedVerseRange?

    /// increments inside a heading or other skipped element
    private var skippedDepth: Int = 0

    private var nextFootnoteID: Footnote.ID = 0

    /// inline styles of the open <span>/<i>/<em> elements
    private var inlineStyles = TextStyleStack()

    /// one entry per open <span>: true for a poetry line
    private var openSpanIsLine: [Bool] = []

    /// Text received since the last tag
    ///
    /// XMLParser can split one text node across several foundCharacters calls
    /// (e.g. "John’" + "s"), so text is appended once per node, at the next tag.
    private var pendingText: String = ""

    private static let headingElements: Set<String> = ["h1", "h2", "h3", "h4", "h5", "h6"]

    private static let inlineStyleElements: Set<String> = ["span", "i", "em"]

    // MARK: Functions (Delegate)

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        flushPendingText()

        // inside a skipped element; keep tracking depth
        if skippedDepth > 0 {
            skippedDepth += 1
            return
        }

        // Copyright line: <p>(<a class="copyright">ESV</a>)</p>; discard its paragraph,
        // so the "(" before it and the ")" after it are dropped too
        if elementName == "a",
           HTMLClassList.contains("copyright", in: attributeDict) {
            currentParagraph = nil
            skippedDepth = 1
            return
        }

        // Headings, footnote list
        if isSkipped(elementName: elementName, attributes: attributeDict) {
            skippedDepth = 1
            return
        }

        // Footnote marker: <a class="fn" title="<note>...</note>">1</a>; its "1" is skipped
        if elementName == "a",
           HTMLClassList.contains("fn", in: attributeDict) {
            appendFootnote(noteMarkup: attributeDict["title"] ?? "")
            skippedDepth = 1
            return
        }

        // Verse number: <b class="verse-num" id="v43003002-1">2 </b>; its text is skipped
        if elementName == "b",
           HTMLClassList.contains("verse-num", in: attributeDict)
            || HTMLClassList.contains("chapter-num", in: attributeDict) {
            appendVerseLabel(elementID: attributeDict["id"])
            skippedDepth = 1
            return
        }

        // New paragraph: <p>, <p class="starts-chapter">, <p class="block-indent">
        if elementName == "p" {
            finishParagraph()
            currentParagraph = .init(style: .paragraph, runs: [])
        }

        if elementName == "span" {
            let isLine = HTMLClassList.contains("line", in: attributeDict)
            openSpanIsLine.append(isLine)

            // Poetry line: <span class="line">, <span class="indent line">
            if isLine {
                finishParagraph()
                currentParagraph = .init(style: lineStyle(for: attributeDict), runs: [])
            }
        }

        if Self.inlineStyleElements.contains(elementName) {
            inlineStyles.push(textStyle(elementName: elementName,
                                        attributes: attributeDict))
        }
    }

    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
        if skippedDepth > 0 {
            return
        }

        pendingText.append(string)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        flushPendingText()

        if skippedDepth > 0 {
            skippedDepth -= 1
            return
        }

        if Self.inlineStyleElements.contains(elementName) {
            inlineStyles.pop()
        }

        // Poetry line ended: </span>; text after it in the same <p> continues as body text
        if elementName == "span",
           let isLine = openSpanIsLine.popLast(),
           isLine {
            finishParagraph()
            currentParagraph = .init(style: .paragraph, runs: [])
        }

        // Paragraph ended: </p>
        if elementName == "p" {
            finishParagraph()
        }
    }

    // MARK: Functions (Private)

    /// Append the text node collected since the last tag
    private func flushPendingText() {
        let trimmedText = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingText = ""

        guard !trimmedText.isEmpty,
              var paragraph = currentParagraph else {
            return
        }

        paragraph.appendText(trimmedText,
                             style: inlineStyles.current,
                             verseRange: currentVerseRange)
        currentParagraph = paragraph
    }

    /// Keep the open paragraph unless it is empty (e.g. between poetry lines)
    private func finishParagraph() {
        if let finishedParagraph = currentParagraph,
           !finishedParagraph.runs.isEmpty {
            paragraphs.append(finishedParagraph)
        }

        currentParagraph = nil
    }

    private func isSkipped(elementName: String,
                           attributes: [String: String]) -> Bool {
        if Self.headingElements.contains(elementName) {
            return true
        }

        return elementName == "div"
            && HTMLClassList.contains("footnotes", in: attributes)
    }

    /// Set the current verse from "v43003002-1" (BBCCCVVV) and append its label
    private func appendVerseLabel(elementID: String?) {
        guard let elementID,
              let packedReference = Int(elementID.dropFirst().prefix { $0.isNumber }) else {
            return
        }

        let verseRange = RenderedVerseRange(startVerse: packedReference % 1000)
        currentVerseRange = verseRange

        currentParagraph?.runs.append(.verseLabel(displayText: String(verseRange.startVerse),
                                                  verseRange: verseRange))
    }

    /// Drop a marker at this spot; the note text comes from the marker's title attribute
    ///
    /// A footnote outside a paragraph or before the first verse has nowhere to attach,
    /// so it is skipped.
    private func appendFootnote(noteMarkup: String) {
        guard let currentVerseRange,
              currentParagraph != nil else {
            return
        }

        let footnoteID = nextFootnoteID
        nextFootnoteID += 1

        // XMLParser already decoded the attribute's &lt;/&gt;, so the note is plain markup.
        // A note quoting across verses has "<verse-num>16</verse-num>Let"; keep "16 Let".
        let noteMarkupWithSpacedVerses = noteMarkup.replacingOccurrences(of: "</verse-num>",
                                                                          with: " ")
        var noteText = FootnoteTextBuffer()
        noteText.append(noteMarkupWithSpacedVerses.replacing(#/<[^>]+>/#, with: ""))

        currentParagraph?.runs.append(.footnoteMarker(footnoteID,
                                                      verseRange: currentVerseRange))
        footnotes.append(Footnote(id: footnoteID,
                                  verseRange: currentVerseRange,
                                  text: noteText.trimmedText))
    }

    /// "line" -> .quoteLine; "indent line", "indent-2 line" -> .indentedLine
    private func lineStyle(for attributes: [String: String]) -> RenderedParagraphStyle {
        let isIndented = HTMLClassList.names(in: attributes).contains { $0.hasPrefix("indent") }
        return isIndented ? .indentedLine : .quoteLine
    }

    private func textStyle(elementName: String,
                           attributes: [String: String]) -> RenderedPassageTextStyle? {
        var style: RenderedPassageTextStyle = []

        if elementName == "i" || elementName == "em" {
            style.insert(.italic)
        }

        if HTMLClassList.contains("woc", in: attributes) {
            style.insert(.wordsOfJesus)
        }

        if HTMLClassList.contains("divine-name", in: attributes) {
            style.insert(.divineName)
        }

        return style.isEmpty ? nil : style
    }
}
