//
//  CrosswayPassageParserTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-05.
//

import Testing
@testable import SwiftBible

struct CrosswayPassageParserTests {

    private let parser = CrosswayPassageParser()

    // MARK: Fixtures (made-up text, real ESV markup shapes)

    /// Footnote marker as ESV sends it: the note is escaped HTML in the title attribute
    private func footnoteMarker(number: Int, escapedNote: String) -> String {
        // ## delimiters, because the markup itself contains "#
        ##"<sup class="footnote"><a class="fn" href="#f\##(number)-1" id="fb\##(number)-1" title="\##(escapedNote)">\##(number)</a></sup>"##
    }

    // MARK: Verses and paragraphs

    /// The verse number comes from the id; "1:1" chapter labels display as "1"
    @Test func verseLabelsComeFromElementIDs() throws {
        let html = """
            <p id="p01001001_01-1" class="starts-chapter"><b class="chapter-num" id="v01001001-1">1:1&nbsp;</b>Alpha text. \
            <b class="verse-num" id="v01001002-1">2&nbsp;</b>Beta text.</p>
            """

        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs.count == 1)
        #expect(passage.paragraphs[0].runs == [
            .verseLabel(displayText: "1", verseRange: .init(startVerse: 1)),
            .text("Alpha text.", verseRange: .init(startVerse: 1)),
            .verseLabel(displayText: "2", verseRange: .init(startVerse: 2)),
            .text("Beta text.", verseRange: .init(startVerse: 2))
        ])
    }

    /// Section headings, Psalm 119's acrostic letters, the footnote list and the copyright are
    /// dropped (`psalm-title` is not; see `psalmTitleIsTitleParagraphWithoutVerse`)
    @Test func headingsFootnoteListAndCopyrightAreSkipped() throws {
        let html = """
            <h3 id="p01001001_01-1">Sample Heading</h3>
            <h4 id="p01001001_09-1" class="psalm-acrostic-title">Aleph</h4>
            <p id="p01001001_06-1"><b class="verse-num" id="v01001001-1">1&nbsp;</b>Alpha text.</p>
            <div class="footnotes extra_text">
            <h3>Footnotes</h3>
            <p><span class="footnote"><a href="#fb1-1" id="f1-1">[1]</a></span> <span class="footnote-ref">1:1</span> <note class="alternative">Or <i>gamma</i></note>
            </p>
            </div>
            <p>(<a href="http://www.esv.org" class="copyright">ESV</a>)</p>
            """

        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs.count == 1)
        #expect(passage.paragraphs[0].runs == [
            .verseLabel(displayText: "1", verseRange: .init(startVerse: 1)),
            .text("Alpha text.", verseRange: .init(startVerse: 1))
        ])
        #expect(passage.footnotes.isEmpty)
    }

    /// ESV sends a Psalm's title as `<h4 class="psalm-title">` before verse 1, even with
    /// `include-headings=false` (markup from ESV Psalm 3, text made up). It becomes its own
    /// paragraph of title-styled text with no verse; verse 1 after it is plain text
    @Test func psalmTitleIsTitleParagraphWithoutVerse() throws {
        let html = """
            <h4 id="p19003001_06-1" class="psalm-title">A Psalm of Alpha, when he fled.</h4>
            <p class="block-indent"><span class="begin-line-group"></span>
            <span id="p19003001_06-1" class="line"><b class="chapter-num" id="v19003001-1">3:1&nbsp;</b>&nbsp;&nbsp;Beta line,</span><br /></p>
            """

        let passage = try parser.parse(html: html)

        // require, not expect: a failed count would crash on the index below
        try #require(passage.paragraphs.count == 2)
        #expect(passage.paragraphs[0].style == .paragraph)
        #expect(passage.paragraphs[0].runs == [
            .styledText("A Psalm of Alpha, when he fled.", style: .title, verseRange: nil)
        ])
        #expect(passage.paragraphs[1].style == .quoteLine)
        #expect(passage.paragraphs[1].runs == [
            .verseLabel(displayText: "1", verseRange: .init(startVerse: 1)),
            .text("Beta line,", verseRange: .init(startVerse: 1))
        ])
    }

    /// XMLParser splits some text nodes at a curly apostrophe ("Alpha’" + "s")
    @Test func textNodeSplitByXMLParserStaysOneRun() throws {
        let html = #"<p><b class="verse-num" id="v01001001-1">1&nbsp;</b>Alpha’s beta didn’t gamma.</p>"#

        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs[0].runs[1] == .text("Alpha’s beta didn’t gamma.",
                                                       verseRange: .init(startVerse: 1)))
    }

    // MARK: Poetry

    /// Each line span becomes its own paragraph; &nbsp; indent padding is trimmed
    @Test func poetryLinesMapToIndentStyles() throws {
        let html = """
            <p><b class="verse-num" id="v01001001-1">1&nbsp;</b>Alpha prose.</p>
            <p class="block-indent"><span class="begin-line-group"></span>
            <span class="line"><b class="verse-num inline" id="v01001002-1">2&nbsp;</b>&nbsp;&nbsp;Beta line,</span><br />\
            <span class="indent line">&nbsp;&nbsp;&nbsp;&nbsp;gamma line.</span><br />\
            <span class="end-line-group"></span></p>
            """

        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs.map(\.style) == [.paragraph, .quoteLine, .indentedLine])
        #expect(passage.paragraphs[1].runs == [
            .verseLabel(displayText: "2", verseRange: .init(startVerse: 2)),
            .text("Beta line,", verseRange: .init(startVerse: 2))
        ])
        #expect(passage.paragraphs[2].runs == [.text("gamma line.", verseRange: .init(startVerse: 2))])
    }

    /// Same rule as PassageHTMLParser: a passage with no body paragraph renders flush
    @Test func allPoetryPassageIsNormalizedToParagraphs() throws {
        let html = """
            <p class="block-indent"><span class="line"><b class="chapter-num" id="v19001001-1">1:1&nbsp;</b>Alpha line,</span><br />\
            <span class="indent line">beta line.</span><br /></p>
            """

        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs.map(\.style) == [.paragraph, .paragraph])
    }

    // MARK: Inline styles

    @Test func inlineClassesMapToTextStyles() throws {
        let html = """
            <p><b class="verse-num" id="v01001001-1">1&nbsp;</b>Alpha <span class="woc">beta</span> \
            the <span class="divine-name">Lord</span> <i>gamma</i>.</p>
            """

        let passage = try parser.parse(html: html)
        let verse1 = RenderedVerseRange(startVerse: 1)

        #expect(passage.paragraphs[0].runs == [
            .verseLabel(displayText: "1", verseRange: verse1),
            .text("Alpha", verseRange: verse1),
            .styledText("beta", style: .wordsOfJesus, verseRange: verse1),
            .text("the", verseRange: verse1),
            .styledText("Lord", style: .divineName, verseRange: verse1),
            .styledText("gamma.", style: .italic, verseRange: verse1)
        ])
    }

    // MARK: Footnotes

    /// Marker in place inside words of Jesus; note text from the title, tags removed
    @Test func footnoteTextComesFromTitle() throws {
        let marker = footnoteMarker(
            number: 1,
            escapedNote: "&lt;note class=&quot;alternative&quot;&gt;Or &lt;i&gt;&lt;span class=&quot;catch-word&quot;&gt;delta&lt;/span&gt; epsilon&lt;/i&gt;&lt;/note&gt;"
        )
        let html = """
            <p><b class="verse-num woc" id="v01001003-1">3&nbsp;</b><span class="woc">Alpha beta\(marker) gamma.</span></p>
            """

        let passage = try parser.parse(html: html)
        let verse3 = RenderedVerseRange(startVerse: 3)

        #expect(passage.paragraphs[0].runs == [
            .verseLabel(displayText: "3", verseRange: verse3),
            .styledText("Alpha beta", style: .wordsOfJesus, verseRange: verse3),
            .footnoteMarker(0, verseRange: verse3),
            .styledText("gamma.", style: .wordsOfJesus, verseRange: verse3)
        ])

        #expect(passage.footnotes.count == 1)
        #expect(passage.footnotes.first?.id == 0)
        #expect(passage.footnotes.first?.verseRange == verse3)
        #expect(passage.footnotes.first?.text == "Or delta epsilon")
    }

    /// A note quoting across verses keeps a space after the inner verse number
    @Test func footnoteVerseNumberIsSpaced() throws {
        let marker = footnoteMarker(
            number: 1,
            escapedNote: "&lt;note class=&quot;alternative&quot;&gt;Or &lt;i&gt;alpha. &lt;verse-num&gt;16&lt;/verse-num&gt;Beta&lt;/i&gt;&lt;/note&gt;"
        )
        let html = #"<p><b class="verse-num" id="v40005015-1">15&nbsp;</b>Gamma\#(marker) delta.</p>"#

        let passage = try parser.parse(html: html)

        #expect(passage.footnotes.first?.text == "Or alpha. 16 Beta")
    }

    // MARK: Entities

    /// Expected characters are spelled out here, not read from the parser's table
    @Test(arguments: [
        ("nbsp", " "),
        ("mdash", "\u{2014}"),
        ("ndash", "\u{2013}"),
        ("lsquo", "\u{2018}"),
        ("rsquo", "\u{2019}"),
        ("ldquo", "\u{201C}"),
        ("rdquo", "\u{201D}"),
        ("hellip", "\u{2026}"),
        ("thinsp", "\u{2009}")
    ])
    func namedEntityDecodesInVerseText(name: String, character: String) throws {
        let html = #"<p><b class="verse-num" id="v01001001-1">1&nbsp;</b>Alpha&\#(name);beta.</p>"#

        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs[0].runs[1] == .text("Alpha\(character)beta.",
                                                       verseRange: .init(startVerse: 1)))
    }

    /// XMLParser decodes XML's own entities; decoding them first would decode twice
    /// ("&amp;mdash;" would become an em dash, "&lt;" would open a tag)
    @Test func xmlEntitiesDecodeExactlyOnce() throws {
        let html = #"<p><b class="verse-num" id="v01001001-1">1&nbsp;</b>Alpha &amp;mdash; beta &lt;gamma&gt; &quot;delta&quot; epsilon&apos;s.</p>"#

        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs[0].runs == [
            .verseLabel(displayText: "1", verseRange: .init(startVerse: 1)),
            .text(#"Alpha &mdash; beta <gamma> "delta" epsilon's."#, verseRange: .init(startVerse: 1))
        ])
    }

    @Test func numericReferencesDecode() throws {
        let html = #"<p><b class="verse-num" id="v01001001-1">1&nbsp;</b>Alpha&#8212;beta&#x2014;gamma.</p>"#

        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs[0].runs[1] == .text("Alpha\u{2014}beta\u{2014}gamma.",
                                                       verseRange: .init(startVerse: 1)))
    }

    /// Entities are replaced before XMLParser runs, so attribute values are covered too
    @Test func namedEntityInFootnoteTitleDecodes() throws {
        let marker = footnoteMarker(
            number: 1,
            escapedNote: "&lt;note class=&quot;alternative&quot;&gt;Or alpha&hellip;beta&lt;/note&gt;"
        )
        let html = #"<p><b class="verse-num" id="v01001001-1">1&nbsp;</b>Gamma\#(marker) delta.</p>"#

        let passage = try parser.parse(html: html)

        #expect(passage.footnotes.first?.text == "Or alpha\u{2026}beta")
    }

    /// Unknown and wrong-case names reach XMLParser unchanged, so the parse fails
    @Test(arguments: ["notanentity", "Mdash"])
    func unknownEntityThrows(name: String) {
        #expect(throws: PassageHTMLParserError.self) {
            try parser.parse(html: #"<p><b class="verse-num" id="v01001001-1">1&nbsp;</b>Alpha&\#(name);beta.</p>"#)
        }
    }

    // MARK: Errors

    @Test func malformedMarkupThrows() {
        #expect(throws: PassageHTMLParserError.self) {
            try parser.parse(html: "<p>unclosed")
        }
    }
}
