//
//  LoadedBiblePassageTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-09-02.
//

import Testing
@testable import SwiftBible

struct LoadedBiblePassageTests {

    @Test func storageSucceeds() async throws {
        let passage = Passage(id: "GEN.1",
                              reference: "Genesis 1",
                              htmlContent: """
                              <div>
                                  <div class="p">
                                      <span class="yv-v" v="1"></span><span class="yv-vlbl">1</span>In the beginning the Living Expression was already there.
                                  </div>
                                  <div class="p">
                                      <span class="yv-v" v="2"></span><span class="yv-vlbl">2</span>They were together in the very beginning.
                                  </div>
                              </div>
                              """)

        let run = RenderedPassageRun.text("In the beginning the Living Expression was already there.",
                                          verseRange: RenderedVerseRange(startVerse: 1))

        let paragraph = RenderedParagraph(runs: [run])

        let loadedBiblePassage = LoadedBiblePassage(passage: passage,
                                                    renderedPassage: RenderedPassage(paragraphs: [paragraph],
                                                                                     footnotes: []))

        #expect(loadedBiblePassage.passage == passage)
        #expect(loadedBiblePassage.renderedPassage.paragraphs.count == 1)
    }

}
