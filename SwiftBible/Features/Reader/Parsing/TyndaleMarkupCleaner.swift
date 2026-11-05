//
//  TyndaleMarkupCleaner.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-04.
//

/// Turns the raw HTML from Tyndale's passages API into markup that XMLParser accepts
///
/// NLT prose relies on HTML's implied paragraph closing: verse_export tags cross
/// paragraph boundaries, and a new block closes the previous paragraph without a </p>.
nonisolated struct TyndaleMarkupCleaner {

    /// Return only the <section>...</section> content, with every paragraph closed explicitly
    func clean(html: String) throws -> String {
        let section = try sectionMarkup(in: html)

        // Project builds in Swift 5 mode, where only the #/.../# literal form is enabled
        let tag = #/<(?<slash>/?)(?<name>[A-Za-z][A-Za-z0-9_-]*)(?<rest>[^>]*)>/#

        var output = ""
        var copiedUpTo = section.startIndex
        var isParagraphOpen = false

        for match in section.matches(of: tag) {
            // Text between tags is copied unchanged
            output += section[copiedUpTo..<match.range.lowerBound]
            copiedUpTo = match.range.upperBound

            let isClosingTag = !match.slash.isEmpty
            let name = match.name
            let rest = match.rest

            if name == "verse_export" {
                continue
            }

            if name == "p" {
                if isClosingTag {
                    // A </p> with no open paragraph is dropped
                    guard isParagraphOpen else { continue }
                    isParagraphOpen = false
                } else {
                    // A bare <p> is dropped
                    guard rest.contains(where: { !$0.isWhitespace }) else { continue }

                    if isParagraphOpen {
                        output += "</p>"
                    }
                    isParagraphOpen = !rest.hasSuffix("/")
                }
            } else if isParagraphOpen, closesOpenParagraph(name: name, isClosingTag: isClosingTag) {
                output += "</p>"
                isParagraphOpen = false
            }

            output += section[match.range]
        }

        output += section[copiedUpTo...]

        return output
    }

    // MARK: Functions (Private Helpers)

    /// Slice from the first <section> through the last </section>
    private func sectionMarkup(in html: String) throws -> Substring {
        guard let open = html.firstMatch(of: #/<section[\s>]/#),
              let close = html.ranges(of: "</section>").last,
              open.range.lowerBound < close.lowerBound else {
            throw TyndaleMarkupCleanerError.noPassageContent
        }

        return html[open.range.lowerBound..<close.upperBound]
    }

    /// Tags that end an open paragraph, other than <p> itself
    private func closesOpenParagraph(name: Substring, isClosingTag: Bool) -> Bool {
        if isClosingTag {
            return name == "div" || name == "section"
        }

        return name == "div" || ["h1", "h2", "h3", "h4", "h5", "h6"].contains(name)
    }
}

nonisolated enum TyndaleMarkupCleanerError: Error {
    /// The response has no <section>...</section>
    case noPassageContent
}
