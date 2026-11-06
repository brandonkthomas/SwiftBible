//
//  TyndalePassageParserTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-05.
//

import Testing
@testable import SwiftBible

struct TyndalePassageParserTests {

    private let parser = TyndalePassageParser()

    // MARK: Fixtures (made-up text, real NLT/KJV markup shapes)

    /// Wrap section content the way /api/passages returns it
    private func document(_ sectionContent: String) -> String {
        """
        <!DOCTYPE html><html lang="en-US"><head><title>NLT API</title>\
        <link rel="stylesheet" href="x"/></head><body>\
        <div id="bibletext"><section>\(sectionContent)</section></div></body></html>
        """
    }

    // MARK: Verses and paragraphs

    /// NLT prose: an unclosed <p> continues across verse_export tags
    @Test func proseVersesShareOneParagraph() throws {
        let html = document("""
            <h2 class="bk_ch_vs_header">Sample 1:1-2, NLT</h2><verse_export orig="x_1_1" vn="1">
            <h2 class="chapter-number"><span class="cw">Sample</span> <span class="cw_ch">1</span></h2>
            <h3 class="subhead">Sample heading</h3>
            <p class="body-ch-hd"><span class="vn">1</span>Alpha text. </verse_export>\
            <verse_export orig="x_1_2" vn="2"><span class="vn">2</span>Beta text.<p>
            </verse_export>
            """)

        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs.count == 1)
        #expect(passage.paragraphs[0].runs == [
            .verseLabel(displayText: "1", verseRange: .init(startVerse: 1)),
            .text("Alpha text.", verseRange: .init(startVerse: 1)),
            .verseLabel(displayText: "2", verseRange: .init(startVerse: 2)),
            .text("Beta text.", verseRange: .init(startVerse: 2))
        ])
    }

    /// KJV headings: section-head divs, subhead paragraphs, psalm titles
    @Test func headingsAndPsalmTitlesAreSkipped() throws {
        let html = document("""
            <h2 class="bk_ch_vs_header">Sample 1:1, KJV</h2>\
            <div class="section-head"><p class="chapter-number">1</p></div>
            <p class="psa-title">A sample title.</p>
            <div class="section-head"><div class="kjv subhead-group"><p class="subhead">Sample heading</p></div></div>
            <p class="body"><span class="vn">1</span>Alpha text.</p>
            """)

        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs.count == 1)
        #expect(passage.paragraphs[0].runs == [
            .verseLabel(displayText: "1", verseRange: .init(startVerse: 1)),
            .text("Alpha text.", verseRange: .init(startVerse: 1))
        ])
    }

    @Test func combinedVerseLabelSetsRange() throws {
        let html = document(#"<p class="body"><span class="vn">16-17</span>Alpha text.</p>"#)

        let passage = try parser.parse(html: html)
        let verseRange = RenderedVerseRange(startVerse: 16, endVerse: 17)

        #expect(passage.paragraphs[0].runs == [
            .verseLabel(displayText: "16-17", verseRange: verseRange),
            .text("Alpha text.", verseRange: verseRange)
        ])
    }

    /// XMLParser splits some text nodes at a curly apostrophe ("Alpha’" + "s")
    @Test func textNodeSplitByXMLParserStaysOneRun() throws {
        let html = document(#"<p class="body"><span class="vn">1</span>Alpha’s beta didn’t gamma.</p>"#)

        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs[0].runs == [
            .verseLabel(displayText: "1", verseRange: .init(startVerse: 1)),
            .text("Alpha’s beta didn’t gamma.", verseRange: .init(startVerse: 1))
        ])
    }

    // MARK: Paragraph styles

    @Test func poetryClassesMapToIndentStyles() throws {
        let html = document("""
            <p class="body"><span class="vn">1</span>Alpha.</p>
            <p class="poet1-vn"><span class="vn">2</span>Beta line,</p>
            <p class="poet2">gamma line.</p>
            <p class="ext-poet1-vn-sp"><span class="vn">3</span>Delta line.</p>
            <p class="ext-hanging-sp">Epsilon.</p>
            """)

        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs.map(\.style) == [
            .paragraph,
            .quoteLine,
            .indentedLine,
            .quoteLine,
            .paragraph
        ])
    }

    /// Same rule as PassageHTMLParser: a passage with no body paragraph renders flush
    @Test func allPoetryPassageIsNormalizedToParagraphs() throws {
        let html = document("""
            <p class="poet1-vn-sp"><span class="vn">1</span>Alpha line,</p>
            <p class="poet2">beta line.</p>
            """)

        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs.map(\.style) == [.paragraph, .paragraph])
    }

    // MARK: Inline styles

    @Test(arguments: zip(
        ["red", "sc", "ital", "red-ital", "red-sc"],
        [
            RenderedPassageTextStyle.wordsOfJesus,
            .divineName,
            .italic,
            [.wordsOfJesus, .italic],
            [.wordsOfJesus, .divineName]
        ]
    ))
    func spanClassMapsToTextStyle(className: String,
                                  expectedStyle: RenderedPassageTextStyle) throws {
        let html = document(#"<p class="body"><span class="vn">1</span>Alpha <span class="\#(className)">beta</span> gamma.</p>"#)

        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs[0].runs == [
            .verseLabel(displayText: "1", verseRange: .init(startVerse: 1)),
            .text("Alpha", verseRange: .init(startVerse: 1)),
            .styledText("beta", style: expectedStyle, verseRange: .init(startVerse: 1)),
            .text("gamma.", verseRange: .init(startVerse: 1))
        ])
    }

    @Test func emIsItalic() throws {
        let html = document(#"<p class="body"><span class="vn">1</span>Alpha <em>beta</em> gamma.</p>"#)

        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs[0].runs[2] == .styledText("beta",
                                                             style: .italic,
                                                             verseRange: .init(startVerse: 1)))
    }

    // MARK: Footnotes

    /// Footnote inside words of Jesus: marker in place, tn-ref and "*" left out
    @Test func footnoteAddsMarkerAndText() throws {
        let html = document("""
            <p class="body"><span class="vn">3</span>Alpha said, <span class="red">“Beta gamma,\
            <a class="a-tn">*</a><span class="tn"><span class="tn-ref">1:3</span> Or <em>delta epsilon;</em> \
            also in 1:7.</span> zeta eta.”</span></p>
            """)

        let passage = try parser.parse(html: html)
        let verse3 = RenderedVerseRange(startVerse: 3)

        #expect(passage.paragraphs[0].runs == [
            .verseLabel(displayText: "3", verseRange: verse3),
            .text("Alpha said,", verseRange: verse3),
            .styledText("“Beta gamma,", style: .wordsOfJesus, verseRange: verse3),
            .footnoteMarker(0, verseRange: verse3),
            .styledText("zeta eta.”", style: .wordsOfJesus, verseRange: verse3)
        ])

        #expect(passage.footnotes.count == 1)
        #expect(passage.footnotes.first?.id == 0)
        #expect(passage.footnotes.first?.verseRange == verse3)
        #expect(passage.footnotes.first?.text == "Or delta epsilon; also in 1:7.")
    }

    @Test func footnoteBeforeFirstVerseIsSkipped() throws {
        let html = document(#"<p class="body">Alpha.<a class="a-tn">*</a><span class="tn">Note text.</span></p>"#)

        let passage = try parser.parse(html: html)

        #expect(passage.footnotes.isEmpty)
        #expect(passage.paragraphs[0].runs == [.text("Alpha.", verseRange: nil)])
    }

    // MARK: Errors

    @Test func missingSectionThrows() {
        #expect(throws: TyndaleMarkupCleanerError.noPassageContent) {
            try parser.parse(html: "<html><body><div>Sample</div></body></html>")
        }
    }
}
