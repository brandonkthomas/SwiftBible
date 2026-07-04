//
//  PassageHTMLParserTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 7/2/26.
//

import Testing
@testable import SwiftBible

struct PassageHTMLParserTests {

    @Test func parserSucceedsWithOneVerse() async throws {
        let html = """
            <div class="p">
            <span class="yv-v" v="1"></span>
            <span class="yv-vlbl">1</span>
            In the beginning God created the heavens and the earth.
            </div>
            """

        let parser = PassageHTMLParser()
        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs.count == 1)

        #expect(passage.paragraphs[0].runs.count == 2)
        #expect(passage.paragraphs[0].runs[0] == .verseLabel(displayText: "1",
                                                             verseRange: .init(startVerse: 1)))
        #expect(passage.paragraphs[0].runs[1] == .text("In the beginning God created the heavens and the earth.",
                                                       verseRange: .init(startVerse: 1)))
    }

    @Test func parserSucceedsWithOneVerseAndQ1Class() async throws {
        let html = """
            <div class="q1">
            <span class="yv-v" v="1"></span>
            <span class="yv-vlbl">1</span>
            In the beginning God created the heavens and the earth.
            </div>
            """

        let parser = PassageHTMLParser()
        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs.count == 1)

        #expect(passage.paragraphs[0].runs.count == 2)
        #expect(passage.paragraphs[0].runs[0] == .verseLabel(displayText: "1",
                                                             verseRange: .init(startVerse: 1)))
        #expect(passage.paragraphs[0].runs[1] == .text("In the beginning God created the heavens and the earth.",
                                                       verseRange: .init(startVerse: 1)))
    }

    @Test func parserSucceedsWithTwoVerses() async throws {
        let html = """
            <div class="p">
            <span class="yv-v" v="1"></span>
            <span class="yv-vlbl">1</span>
            In the beginning God created the heavens and the earth. 
            <span class="yv-v" v="2"></span>
            <span class="yv-vlbl">2</span>
            Now the earth was formless and empty.
            </div>
            """

        let parser = PassageHTMLParser()
        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs.count == 1)

        #expect(passage.paragraphs[0].runs.count == 4)
        #expect(passage.paragraphs[0].runs[0] == .verseLabel(displayText: "1",
                                                             verseRange: .init(startVerse: 1)))
        #expect(passage.paragraphs[0].runs[1] == .text("In the beginning God created the heavens and the earth.",
                                                       verseRange: .init(startVerse: 1)))
        #expect(passage.paragraphs[0].runs[2] == .verseLabel(displayText: "2",
                                                             verseRange: .init(startVerse: 2)))
        #expect(passage.paragraphs[0].runs[3] == .text("Now the earth was formless and empty.",
                                                       verseRange: .init(startVerse: 2)))
    }

    @Test func parserSucceedsWithTwoParagraphs() async throws {
        let html = """
            <div class="p">
            <span class="yv-v" v="1"></span>
            <span class="yv-vlbl">1</span>
            First paragraph text.
            </div>
            <div class="p">
            <span class="yv-v" v="2"></span>
            <span class="yv-vlbl">2</span>
            Second paragraph text.
            </div>
            """

        let parser = PassageHTMLParser()
        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs.count == 2)

        #expect(passage.paragraphs[0].runs.count == 2)
        #expect(passage.paragraphs[0].runs[0] == .verseLabel(displayText: "1",
                                                             verseRange: .init(startVerse: 1)))
        #expect(passage.paragraphs[0].runs[1] == .text("First paragraph text.",
                                                       verseRange: .init(startVerse: 1)))

        #expect(passage.paragraphs[1].runs.count == 2)
        #expect(passage.paragraphs[1].runs[0] == .verseLabel(displayText: "2",
                                                             verseRange: .init(startVerse: 2)))
        #expect(passage.paragraphs[1].runs[1] == .text("Second paragraph text.",
                                                       verseRange: .init(startVerse: 2)))
    }

    @Test func parserIgnoresEmptyMarkers() async throws {
        let html = """
            <div class="p">
            <span class="yv-v" v="1"></span>
            <span class="yv-vlbl">1</span>
            Visible text only.
            </div>
            """

        let parser = PassageHTMLParser()
        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs.count == 1)

        #expect(passage.paragraphs[0].runs.count == 2)
        #expect(passage.paragraphs[0].runs[0] == .verseLabel(displayText: "1",
                                                             verseRange: .init(startVerse: 1)))
        #expect(passage.paragraphs[0].runs[1] == .text("Visible text only.",
                                                       verseRange: .init(startVerse: 1)))
    }

    @Test func parserHandlesFootnotes() async throws {
        let html = """
            <div class="p">
            <span class="yv-v" v="1"></span>
            <span class="yv-vlbl">1</span>
            In the beginning 
            <span class="yv-n f">
                <span class="fr">1:1</span>
                <span class="ft">Footnote body should not render inline.</span>
            </span>
            <span class="yv-n f">
                <span class="fr">1:2</span>
                <span class="ft">Second footnote.</span>
            </span>
            the Living Expression was already there.
            </div>
            """

        let parser = PassageHTMLParser()
        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs[0].runs.count == 5)
        #expect(passage.paragraphs[0].runs[0] == .verseLabel(displayText: "1",
                                                             verseRange: .init(startVerse: 1)))
        #expect(passage.paragraphs[0].runs[1] == .text("In the beginning",
                                                       verseRange: .init(startVerse: 1)))
        #expect(passage.paragraphs[0].runs[2] == .footnoteMarker(passage.footnotes[0].id,
                                                                 verseRange: .init(startVerse: 1)))
        #expect(passage.paragraphs[0].runs[3] == .footnoteMarker(passage.footnotes[1].id,
                                                                 verseRange: .init(startVerse: 1)))
        #expect(passage.paragraphs[0].runs[4] == .text("the Living Expression was already there.",
                                                       verseRange: .init(startVerse: 1)))

        #expect(passage.footnotes.count == 2)
        #expect(passage.footnotes[0].id == 0)
        #expect(passage.footnotes[0].text == "Footnote body should not render inline.")
        #expect(passage.footnotes[1].id == 1)
        #expect(passage.footnotes[1].text == "Second footnote.")
    }

    @Test func parserHandlesMultiVerseLabels() async throws {
        let html = """
            <div class="p">
            <span class="yv-v" ev="27" v="26"></span>
            <span class="yv-vlbl">26-27</span>
            Multi-verse label text.
            </div>
            """

        let parser = PassageHTMLParser()
        let passage = try parser.parse(html: html)

        let verseRange = RenderedVerseRange(startVerse: 26, endVerse: 27)

        #expect(passage.paragraphs.count == 1)
        #expect(passage.paragraphs[0].runs.count == 2)
        #expect(passage.paragraphs[0].runs[0] == .verseLabel(displayText: "26-27",
                                                             verseRange: verseRange))
        #expect(passage.paragraphs[0].runs[1] == .text("Multi-verse label text.",
                                                       verseRange: verseRange))
    }
}
