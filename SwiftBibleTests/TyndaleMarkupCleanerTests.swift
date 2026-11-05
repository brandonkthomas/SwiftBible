//
//  TyndaleMarkupCleanerTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-04.
//

import Foundation
import Testing
@testable import SwiftBible

struct TyndaleMarkupCleanerTests {

    private let cleaner = TyndaleMarkupCleaner()

    // MARK: Fixtures (made-up text)

    /// Unclosed <p> crossing verse_export tags, as in NLT prose
    private let prose = """
        <section><h2 class="subhead">Sample heading</h2>\
        <verse_export orig="x_1_1" vn="1"><p class="body"><span class="vn">1</span>Alpha text.</verse_export>\
        <verse_export orig="x_1_2" vn="2"><span class="vn">2</span>Beta text.\
        <p class="body"><span class="vn">3</span>Gamma text.</p></verse_export>\
        <verse_export orig="x_1_3" vn="4"><p class="body"><span class="vn">4</span>Delta text.</verse_export></section>
        """

    /// Well-formed poetry: no verse_export, no implied closes
    private let poetry = """
        <section><h2>Sample</h2><p class="poet1"><span class="vn">1</span>Alpha line,</p>\
        <p class="poet2">beta line.</p><p class="poet1"><span class="vn">2</span>Gamma line.</p></section>
        """

    // MARK: Section

    @Test func outputIsOnlyTheSection() throws {
        let html = """
            <!DOCTYPE html><html><head><title>Sample</title><link rel="stylesheet" href="x"/></head>\
            <body><div id="bibletext"><section><p class="body">Alpha.</p></section></div></body></html>
            """

        #expect(try cleaner.clean(html: html) == #"<section><p class="body">Alpha.</p></section>"#)
    }

    @Test(arguments: [
        "<html><body><div>Sample</div></body></html>",
        "<section><p class=\"body\">Alpha.</p>",
        "</section><section>",
        ""
    ])
    func missingSectionThrows(html: String) {
        #expect(throws: TyndaleMarkupCleanerError.noPassageContent) {
            try cleaner.clean(html: html)
        }
    }

    // MARK: Well-formed output

    @Test func proseWithUnclosedParagraphsParses() throws {
        let output = try cleaner.clean(html: prose)

        #expect(XMLParser(data: Data(output.utf8)).parse())
        #expect(!output.contains("verse_export"))
    }

    @Test func bareParagraphBeforeHeadingParses() throws {
        let html = #"<section><p class="body">Alpha.</p><p><h3>Sample</h3><p class="body">Beta.</section>"#

        let output = try cleaner.clean(html: html)

        #expect(XMLParser(data: Data(output.utf8)).parse())
        #expect(output == #"<section><p class="body">Alpha.</p><h3>Sample</h3><p class="body">Beta.</p></section>"#)
    }

    @Test func wellFormedPoetryIsUnchanged() throws {
        #expect(try cleaner.clean(html: poetry) == poetry)
    }

    // MARK: Tag rules

    @Test func verseNumberSpanCountIsUnchanged() throws {
        let output = try cleaner.clean(html: prose)

        #expect(spanCount(in: output) == spanCount(in: prose))
        #expect(spanCount(in: output) == 4)
    }

    @Test func closeWithNoOpenParagraphIsDropped() throws {
        let html = #"<section></p><p class="body">Alpha.</p></p>Beta.</section>"#

        #expect(try cleaner.clean(html: html) == #"<section><p class="body">Alpha.</p>Beta.</section>"#)
    }

    @Test(arguments: ["<h1>", "<h2 class=\"x\">", "<h6>", "<div>", "<div class=\"x\">"])
    func openBlockClosesParagraph(block: String) throws {
        let html = "<section><p class=\"body\">Alpha.\(block)"

        let output = try cleaner.clean(html: html + "</section>")

        #expect(output == "<section><p class=\"body\">Alpha.</p>\(block)</section>")
    }

    @Test func closingDivClosesParagraph() throws {
        let html = #"<section><div><p class="body">Alpha.</div></section>"#

        #expect(try cleaner.clean(html: html) == #"<section><div><p class="body">Alpha.</p></div></section>"#)
    }

    /// Similar names must not be treated as p, h1-h6, or div
    @Test func otherTagsAreUnchanged() throws {
        let html = #"<section><p class="body">Alpha<pre>x</pre><header>y</header><em>z</em><br/></p></section>"#

        #expect(try cleaner.clean(html: html) == html)
    }

    // MARK: Helpers

    private func spanCount(in markup: String) -> Int {
        markup.ranges(of: #"<span class="vn">"#).count
    }
}
