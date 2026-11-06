//
//  TyndalePassageParser.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-05.
//

import Foundation

/// Handles parsing of Tyndale API passage HTML (NLT, KJV) into a RenderedPassage
nonisolated struct TyndalePassageParser {

    /// Parse a full Tyndale /api/passages response
    func parse(html: String) throws -> RenderedPassage {
        let markup = try TyndaleMarkupCleaner().clean(html: html)

        let delegate = TyndalePassageParserDelegate()

        let xmlParser = XMLParser(data: Data(markup.utf8))
        xmlParser.delegate = delegate

        guard xmlParser.parse() else {
            throw PassageHTMLParserError.parsingError
        }

        return .init(paragraphs: delegate.paragraphs.normalizingIndentation(),
                     footnotes: delegate.footnotes)
    }
}

/// XMLParser delegate for TyndaleMarkupCleaner output
///
/// Markup observed in NLT and KJV responses:
///
/// Paragraph-level (`<p class="...">`); a class is a base name plus spacing suffixes
/// (`-vn`, `-sp`, `-hd`, `-ch`) and an optional `ext-` prefix, which do not change the style:
/// - `body`, `hanging` -> `RenderedParagraphStyle.paragraph`
/// - `poet1` -> `RenderedParagraphStyle.quoteLine`
/// - `poet2`, `poet3`, ... -> `RenderedParagraphStyle.indentedLine`
/// - any other class -> `RenderedParagraphStyle.paragraph`, so Scripture text is never dropped
///
/// Skipped with everything inside them:
/// - `h1`-`h6` (`bk_ch_vs_header`, `chapter-number`, `subhead`)
/// - `chapter-number`, `subhead`, `psa-title`, `section-head`, `subhead-group` on any element
/// - `<a class="a-tn">*</a>` (the visible footnote marker character)
///
/// Inline:
/// - `<span class="vn">3</span>` -> `RenderedPassageRun.verseLabel`; sets the current verse
/// - `<span class="tn">` -> `RenderedPassageRun.footnoteMarker` plus a `Footnote`;
///   `tn-ref` inside it is skipped
/// - `red` -> `.wordsOfJesus`, `ital` and `<em>` -> `.italic`, `sc` -> `.divineName`;
///   combined classes (`red-ital`, `red-sc`) apply both
private nonisolated final class TyndalePassageParserDelegate: NSObject, XMLParserDelegate {

    // MARK: Properties

    /// finished output
    var paragraphs: [RenderedParagraph] = []
    var footnotes: [Footnote] = []

    /// paragraph we're currently building
    private var currentParagraph: RenderedParagraph?

    /// set by each <span class="vn">
    private var currentVerseRange: RenderedVerseRange?

    /// true between <span class="vn"> and its </span>
    private var isInsideVerseLabel: Bool = false
    private var currentVerseLabelText: String = ""

    /// increments inside a heading or other skipped element
    private var skippedDepth: Int = 0

    /// increments inside <span class="tn">
    private var footnoteDepth: Int = 0

    /// increments inside <span class="tn-ref"> within a footnote
    private var ignoredFootnoteReferenceDepth: Int = 0

    private var currentFootnoteID: Footnote.ID?
    private var nextFootnoteID: Footnote.ID = 0
    private var footnoteText = FootnoteTextBuffer()

    /// inline styles of the open <span>/<em> elements
    private var inlineStyles = TextStyleStack()

    /// Text received since the last tag
    ///
    /// XMLParser can split one text node across several foundCharacters calls
    /// (e.g. "John’" + "s"), so text is appended once per node, at the next tag.
    private var pendingText: String = ""

    private static let skippedClasses: Set<Substring> = [
        "chapter-number",
        "subhead",
        "psa-title",
        "section-head",
        "subhead-group"
    ]

    private static let headingElements: Set<String> = ["h1", "h2", "h3", "h4", "h5", "h6"]

    private static let inlineStyleElements: Set<String> = ["span", "em", "i"]

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

        // inside a footnote; keep tracking depth
        if footnoteDepth > 0 {
            footnoteDepth += 1

            if ignoredFootnoteReferenceDepth > 0 {
                ignoredFootnoteReferenceDepth += 1
            } else if HTMLClassList.contains("tn-ref", in: attributeDict) {
                ignoredFootnoteReferenceDepth = 1
            }

            return
        }

        // Headings, footnote marker character: <h3 class="subhead">, <a class="a-tn">
        if isSkipped(elementName: elementName, attributes: attributeDict) {
            skippedDepth = 1
            return
        }

        // Footnote: <span class="tn">
        if elementName == "span",
           HTMLClassList.contains("tn", in: attributeDict) {
            startFootnote()
            return
        }

        // New paragraph: <p class="body">, <p class="poet1-vn">, etc.
        if elementName == "p" {
            currentParagraph = .init(style: paragraphStyle(for: attributeDict),
                                     runs: [])
        }

        // Verse label: <span class="vn">
        if elementName == "span",
           HTMLClassList.contains("vn", in: attributeDict) {
            isInsideVerseLabel = true
            currentVerseLabelText = ""
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

        if footnoteDepth > 0 {
            if ignoredFootnoteReferenceDepth == 0 {
                footnoteText.append(string)
            }
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

        if footnoteDepth > 0 {
            footnoteDepth -= 1

            if ignoredFootnoteReferenceDepth > 0 {
                ignoredFootnoteReferenceDepth -= 1
            }

            if footnoteDepth == 0 {
                finishFootnote()
            }

            return
        }

        // Verse label ended: </span>
        if elementName == "span",
           isInsideVerseLabel {
            finishVerseLabel()
        }

        if Self.inlineStyleElements.contains(elementName) {
            inlineStyles.pop()
        }

        // Paragraph ended: </p>
        if elementName == "p",
           let finishedParagraph = currentParagraph {
            if !finishedParagraph.runs.isEmpty {
                paragraphs.append(finishedParagraph)
            }
            currentParagraph = nil
        }
    }

    // MARK: Functions (Private)

    /// Append the text node collected since the last tag
    private func flushPendingText() {
        let trimmedText = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingText = ""

        guard !trimmedText.isEmpty else {
            return
        }

        if isInsideVerseLabel {
            currentVerseLabelText.append(trimmedText)
            return
        }

        guard var paragraph = currentParagraph else {
            return
        }

        paragraph.appendText(trimmedText,
                             style: inlineStyles.current,
                             verseRange: currentVerseRange)
        currentParagraph = paragraph
    }

    private func isSkipped(elementName: String,
                           attributes: [String: String]) -> Bool {
        if Self.headingElements.contains(elementName) {
            return true
        }

        if elementName == "a",
           HTMLClassList.contains("a-tn", in: attributes) {
            return true
        }

        return HTMLClassList.names(in: attributes).contains { Self.skippedClasses.contains($0) }
    }

    /// Drop a marker at this spot and start collecting footnote text
    ///
    /// A footnote outside a paragraph or before the first verse has nowhere to attach,
    /// so it is skipped instead.
    private func startFootnote() {
        guard let currentVerseRange,
              var paragraph = currentParagraph else {
            skippedDepth = 1
            return
        }

        footnoteDepth = 1
        ignoredFootnoteReferenceDepth = 0
        footnoteText.reset()

        let footnoteID = nextFootnoteID
        nextFootnoteID += 1
        currentFootnoteID = footnoteID

        paragraph.runs.append(.footnoteMarker(footnoteID,
                                              verseRange: currentVerseRange))
        currentParagraph = paragraph
    }

    private func finishFootnote() {
        if let currentFootnoteID,
           let currentVerseRange {
            footnotes.append(Footnote(id: currentFootnoteID,
                                      verseRange: currentVerseRange,
                                      text: footnoteText.trimmedText))
        }

        currentFootnoteID = nil
        footnoteText.reset()
    }

    /// Set the current verse from the label text ("3", "16-17") and append the label run
    private func finishVerseLabel() {
        isInsideVerseLabel = false

        currentVerseRange = verseRange(fromLabel: currentVerseLabelText)

        if var paragraph = currentParagraph {
            paragraph.runs.append(.verseLabel(displayText: currentVerseLabelText,
                                              verseRange: currentVerseRange))
            currentParagraph = paragraph
        }

        currentVerseLabelText = ""
    }

    private func verseRange(fromLabel label: String) -> RenderedVerseRange? {
        let bounds = label.split(whereSeparator: { "-–".contains($0) })
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }

        switch bounds.count {
        case 1:
            return .init(startVerse: bounds[0])
        case 2:
            return .init(startVerse: bounds[0], endVerse: bounds[1])
        default:
            return nil
        }
    }

    /// Map a paragraph class to a style: "ext-poet1-vn-sp" -> base "poet1" -> .quoteLine
    private func paragraphStyle(for attributes: [String: String]) -> RenderedParagraphStyle {
        for className in HTMLClassList.names(in: attributes) {
            let parts = className.split(separator: "-")

            guard let base = parts.first(where: { $0 != "ext" }) else {
                continue
            }

            if base == "body" || base == "hanging" {
                return .paragraph
            }

            if let poetryLevel = HTMLClassList.numberedLevel(of: base, prefix: "poet") {
                return poetryLevel == 1 ? .quoteLine : .indentedLine
            }
        }

        return .paragraph
    }

    /// Map an inline element to text styles; class parts combine ("red-sc")
    private func textStyle(elementName: String,
                           attributes: [String: String]) -> RenderedPassageTextStyle? {
        var style: RenderedPassageTextStyle = []

        if elementName == "em" || elementName == "i" {
            style.insert(.italic)
        }

        for className in HTMLClassList.names(in: attributes) {
            for part in className.split(separator: "-") {
                switch part {
                case "red":
                    style.insert(.wordsOfJesus)
                case "ital":
                    style.insert(.italic)
                case "sc":
                    style.insert(.divineName)
                default:
                    break
                }
            }
        }

        return style.isEmpty ? nil : style
    }
}
