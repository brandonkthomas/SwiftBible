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
        // would be quoteLine but the parser now collapses fully-quoted passages to para runs
        #expect(passage.paragraphs[0].style == .paragraph)

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

    @Test func parserPreservesStyledPassageRuns() async throws {
        let html = """
            <div class="p">
            <span class="yv-v" v="1"></span>
            <span class="yv-vlbl">1</span>
            Jesus said, <span class="wj">follow <span class="it">me</span></span> and worship <span class="nd">Yahweh</span>.
            </div>
            """

        let parser = PassageHTMLParser()
        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs.count == 1)
        #expect(passage.paragraphs[0].runs.count == 6)
        #expect(passage.paragraphs[0].runs[0] == .verseLabel(displayText: "1",
                                                             verseRange: .init(startVerse: 1)))
        #expect(passage.paragraphs[0].runs[1] == .text("Jesus said,",
                                                       verseRange: .init(startVerse: 1)))
        #expect(passage.paragraphs[0].runs[2] == .styledText("follow",
                                                             style: .wordsOfJesus,
                                                             verseRange: .init(startVerse: 1)))
        #expect(passage.paragraphs[0].runs[3] == .styledText("me",
                                                             style: [.italic, .wordsOfJesus],
                                                             verseRange: .init(startVerse: 1)))
        #expect(passage.paragraphs[0].runs[4] == .text("and worship",
                                                       verseRange: .init(startVerse: 1)))
        #expect(passage.paragraphs[0].runs[5] == .styledText("Yahweh.",
                                                             style: .divineName,
                                                             verseRange: .init(startVerse: 1)))
    }

    @Test func parserPreservesIndentedPoetryBlocksAfterVerseLabel() async throws {
        let html = """
            <div class="p">
            <span class="yv-v" v="16"></span>
            <span class="yv-vlbl">16</span>
            For
            </div>
            <div class="mi">Who has ever known the mind of the Lord <span class="nd">Yahweh</span>?</div>
            <div class="m"><span class="it">Christ has</span>, and we possess Christ's perceptions.</div>
            """

        let parser = PassageHTMLParser()
        let passage = try parser.parse(html: html)

        let verseRange = RenderedVerseRange(startVerse: 16)

        #expect(passage.paragraphs.count == 3)
        #expect(passage.paragraphs[0].style == .paragraph)
        #expect(passage.paragraphs[1].style == .indentedLine)
        #expect(passage.paragraphs[2].style == .paragraph)

        #expect(passage.paragraphs[0].runs[0] == .verseLabel(displayText: "16",
                                                             verseRange: verseRange))
        #expect(passage.paragraphs[0].runs[1] == .text("For",
                                                       verseRange: verseRange))
        #expect(passage.paragraphs[1].runs[0] == .text("Who has ever known the mind of the Lord",
                                                       verseRange: verseRange))
        #expect(passage.paragraphs[1].runs[1] == .styledText("Yahweh?",
                                                             style: .divineName,
                                                             verseRange: verseRange))
        #expect(passage.paragraphs[2].runs[0] == .styledText("Christ has,",
                                                             style: .italic,
                                                             verseRange: verseRange))
        #expect(passage.paragraphs[2].runs[1] == .text("and we possess Christ's perceptions.",
                                                       verseRange: verseRange))
    }

    @Test func parserPreservesMixedFootnoteBodyRuns() async throws {
        let html = """
            <div class="p">
            <span class="yv-v" v="1"></span>
            <span class="yv-vlbl">1</span>
            In the beginning
            <span class="yv-n f">
                <span class="fr">1:1</span>
                <span class="ft">The Greek is</span><span class="ft"> </span><span class="it">logos</span><span class="ft">; see</span><span class="ft"> </span><span class="ref" usfm="JHN.1.1">John 1:1</span><span class="ft"> and </span><span class="nd">Yahweh</span><span class="ft">.</span>
            </span>
            was already there.
            </div>
            """

        let parser = PassageHTMLParser()
        let passage = try parser.parse(html: html)

        #expect(passage.footnotes.count == 1)
        #expect(passage.footnotes[0].text == "The Greek is logos; see John 1:1 and Yahweh.")
    }

    @Test func parserSplitsLeadingPunctuationFromRemainder() async throws {
        let html = """
            <div class="p">
            <span class="yv-v" v="1"></span>
            <span class="yv-vlbl">1</span>
            <span class="it">Christ has</span>, and we possess Christ's perceptions.
            </div>
            """

        let parser = PassageHTMLParser()
        let passage = try parser.parse(html: html)

        let verseRange = RenderedVerseRange(startVerse: 1)

        #expect(passage.paragraphs[0].runs.count == 3)
        #expect(passage.paragraphs[0].runs[0] == .verseLabel(displayText: "1",
                                                             verseRange: verseRange))
        #expect(passage.paragraphs[0].runs[1] == .styledText("Christ has,",
                                                             style: .italic,
                                                             verseRange: verseRange))
        #expect(passage.paragraphs[0].runs[2] == .text("and we possess Christ's perceptions.",
                                                       verseRange: verseRange))
    }

    @Test func parserKeepsLeadingPunctuationWhenPreviousRunCannotMerge() async throws {
        let html = """
            <div class="p">
            <span class="yv-v" v="1"></span>
            <span class="yv-vlbl">1</span>
            . Opening punctuation stays visible.
            </div>
            """

        let parser = PassageHTMLParser()
        let passage = try parser.parse(html: html)

        let verseRange = RenderedVerseRange(startVerse: 1)

        #expect(passage.paragraphs[0].runs.count == 2)
        #expect(passage.paragraphs[0].runs[0] == .verseLabel(displayText: "1",
                                                             verseRange: verseRange))
        #expect(passage.paragraphs[0].runs[1] == .text(". Opening punctuation stays visible.",
                                                       verseRange: verseRange))
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

    /// XMLParser splits some text nodes at a curly apostrophe ("John’" + "s")
    @Test func parserKeepsTextNodeSplitByXMLParserAsOneRun() async throws {
        let html = """
            <div class="p">
            <span class="yv-v" v="1"></span>
            <span class="yv-vlbl">1</span>
            John’s disciples didn’t go.
            </div>
            """

        let parser = PassageHTMLParser()
        let passage = try parser.parse(html: html)

        let verseRange = RenderedVerseRange(startVerse: 1)

        #expect(passage.paragraphs[0].runs.count == 2)
        #expect(passage.paragraphs[0].runs[1] == .text("John’s disciples didn’t go.",
                                                       verseRange: verseRange))
    }

    /// NIV John 17 (trimmed): verse 1 is in `p`, the prayer that follows is in `pm` (USFM embedded text paragraph)
    @Test func parserKeepsVersesInsideEmbeddedTextParagraphs() async throws {
        let html = """
            <div class="p"><span class="yv-v" v="1"></span><span class="yv-vlbl">1</span>After Jesus said this, he looked toward heaven and prayed:</div>\
            <div class="pm"><span class="wj">“Father, the hour has come.</span> <span class="yv-v" v="2"></span><span class="yv-vlbl">2</span><span class="wj">For you granted him authority.</span></div>\
            <div class="pm"><span class="yv-v" v="6"></span><span class="yv-vlbl">6</span> <span class="wj">“I have revealed you</span> <span class="yv-n f"><span class="fr">17:6 </span><span class="ft">Greek </span><span class="fqa">your name</span></span><span class="wj">to those whom you gave me.</span></div>
            """

        let parser = PassageHTMLParser()
        let passage = try parser.parse(html: html)

        let verse1 = RenderedVerseRange(startVerse: 1)
        let verse2 = RenderedVerseRange(startVerse: 2)
        let verse6 = RenderedVerseRange(startVerse: 6)

        #expect(passage.paragraphs.count == 3)
        #expect(passage.paragraphs.allSatisfy { $0.style == .paragraph })

        #expect(passage.paragraphs[1].runs.count == 3)
        #expect(passage.paragraphs[1].runs[0] == .styledText("“Father, the hour has come.",
                                                             style: .wordsOfJesus,
                                                             verseRange: verse1))
        #expect(passage.paragraphs[1].runs[1] == .verseLabel(displayText: "2",
                                                             verseRange: verse2))
        #expect(passage.paragraphs[1].runs[2] == .styledText("For you granted him authority.",
                                                             style: .wordsOfJesus,
                                                             verseRange: verse2))

        #expect(passage.paragraphs[2].runs.count == 4)
        #expect(passage.paragraphs[2].runs[0] == .verseLabel(displayText: "6",
                                                             verseRange: verse6))
        #expect(passage.paragraphs[2].runs[2] == .footnoteMarker(0,
                                                                 verseRange: verse6))

        #expect(passage.footnotes.count == 1)
    }

    /// USFM embedded text family: \pm, \pmo (opening), \pmc (closing), \pmr (refrain)
    @Test(arguments: ["pm", "pmo", "pmc", "pmr"])
    func parserTreatsEmbeddedTextClassesAsParagraphs(className: String) async throws {
        let html = """
            <div class="p"><span class="yv-v" v="1"></span><span class="yv-vlbl">1</span>Narrative text.</div>
            <div class="\(className)"><span class="yv-v" v="2"></span><span class="yv-vlbl">2</span>Embedded text.</div>
            """

        let parser = PassageHTMLParser()
        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs.count == 2)
        #expect(passage.paragraphs[1].style == .paragraph)
        #expect(passage.paragraphs[1].runs == [
            .verseLabel(displayText: "2", verseRange: .init(startVerse: 2)),
            .text("Embedded text.", verseRange: .init(startVerse: 2))
        ])
    }

    /// A paragraph class the parser doesn't recognize falls back to `.paragraph` instead of dropping its text
    @Test func parserKeepsTextInsideUnknownParagraphClass() async throws {
        let html = """
            <div class="p"><span class="yv-v" v="1"></span><span class="yv-vlbl">1</span>Known paragraph.</div>
            <div class="zz-unknown"><span class="yv-v" v="2"></span><span class="yv-vlbl">2</span>Unknown paragraph.</div>
            """

        let parser = PassageHTMLParser()
        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs.count == 2)
        #expect(passage.paragraphs[1].style == .paragraph)
        #expect(passage.paragraphs[1].runs == [
            .verseLabel(displayText: "2", verseRange: .init(startVerse: 2)),
            .text("Unknown paragraph.", verseRange: .init(startVerse: 2))
        ])
    }

    /// YouVersion wraps `content` in a classless `<div>`; it must not become its own paragraph
    @Test func parserDoesNotTreatClasslessWrapperDivAsParagraph() async throws {
        let html = """
            <div><div class="p"><span class="yv-v" v="1"></span><span class="yv-vlbl">1</span>First.</div>\
            <div class="p"><span class="yv-v" v="2"></span><span class="yv-vlbl">2</span>Second.</div></div>
            """

        let parser = PassageHTMLParser()
        let passage = try parser.parse(html: html)

        #expect(passage.paragraphs.count == 2)
        #expect(passage.paragraphs[0].runs.last == .text("First.", verseRange: .init(startVerse: 1)))
        #expect(passage.paragraphs[1].runs.last == .text("Second.", verseRange: .init(startVerse: 2)))
    }
}
