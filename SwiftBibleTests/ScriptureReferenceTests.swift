//
//  ScriptureReferenceTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 6/26/26.
//

import Testing
@testable import SwiftBible

struct ScriptureReferenceTests {

    /// Chapter-only ScriptureReference parses and does not store verses
    @Test func chapterOnlyIsValid() {
        let scriptureReference = ScriptureReference(translationID: 123,
                                                    bookCode: "GEN",
                                                    chapter: 1,
                                                    startVerse: nil,
                                                    endVerse: nil)

        #expect(scriptureReference?.startVerse == nil)
        #expect(scriptureReference?.endVerse == nil)
    }

    /// Single-verse-only ScriptureReference parses and does not store endVerse
    @Test func singleVerseIsValid() {
        let scriptureReference = ScriptureReference(translationID: 123,
                                                    bookCode: "GEN",
                                                    chapter: 1,
                                                    startVerse: 1,
                                                    endVerse: nil)

        #expect(scriptureReference?.startVerse == 1)
        #expect(scriptureReference?.endVerse == nil)
    }

    /// Verse range ScriptureReference parses and stores both verses
    @Test func verseRangeIsValid() {
        let scriptureReference = ScriptureReference(translationID: 123,
                                                    bookCode: "GEN",
                                                    chapter: 1,
                                                    startVerse: 1,
                                                    endVerse: 3)

        #expect(scriptureReference?.startVerse == 1)
        #expect(scriptureReference?.endVerse == 3)
    }

    /// Chapter 0 returns nil
    @Test func chapterZeroFails() {
        let scriptureReference = ScriptureReference(translationID: 123,
                                                    bookCode: "GEN",
                                                    chapter: 0,
                                                    startVerse: 1,
                                                    endVerse: 3)

        #expect(scriptureReference == nil)
    }

    /// startVerse 0 returns nil
    @Test func startVerseZeroFails() {
        let scriptureReference = ScriptureReference(translationID: 123,
                                                    bookCode: "GEN",
                                                    chapter: 1,
                                                    startVerse: 0,
                                                    endVerse: 3)

        #expect(scriptureReference == nil)
    }

    /// endVerse 0 returns nil
    @Test func endVerseZeroFails() {
        let scriptureReference = ScriptureReference(translationID: 123,
                                                    bookCode: "GEN",
                                                    chapter: 1,
                                                    startVerse: 1,
                                                    endVerse: 0)

        #expect(scriptureReference == nil)
    }

    /// endVerse before startVerse fails
    @Test func reverseRangeFails() {
        let scriptureReference = ScriptureReference(translationID: 123,
                                                    bookCode: "GEN",
                                                    chapter: 1,
                                                    startVerse: 3,
                                                    endVerse: 1)

        #expect(scriptureReference == nil)
    }

    /// endVerse w/o startVerse fails
    @Test func endVerseWithoutStartVerseFails() {
        let scriptureReference = ScriptureReference(translationID: 123,
                                                    bookCode: "GEN",
                                                    chapter: 1,
                                                    startVerse: nil,
                                                    endVerse: 1)

        #expect(scriptureReference == nil)
    }

    /// startVerse == endVerse is valid
    @Test func sameStartAndEndVerseIsValid() {
        let scriptureReference = ScriptureReference(translationID: 123,
                                                    bookCode: "GEN",
                                                    chapter: 1,
                                                    startVerse: 1,
                                                    endVerse: 1)

        #expect(scriptureReference?.startVerse == 1)
        #expect(scriptureReference?.endVerse == 1)
    }
}
