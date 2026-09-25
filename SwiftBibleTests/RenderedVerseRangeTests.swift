//
//  RenderedVerseRangeTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-09-24.
//

import Testing
@testable import SwiftBible

struct RenderedVerseRangeTests {

    /// A range with no endVerse displays just the start verse number
    @Test func singleVerseDisplaysStartVerseOnly() {
        let range = RenderedVerseRange(startVerse: 1)

        #expect(range.endVerse == nil)
        #expect(range.displayText == "1")
    }

    /// A range with an endVerse displays both bounds joined by an en dash
    @Test func multiVerseDisplaysRangeWithEnDash() {
        let range = RenderedVerseRange(startVerse: 1, endVerse: 3)

        #expect(range.endVerse == 3)
        #expect(range.displayText == "1–3")
    }

    /// A ClosedRange with equal bounds collapses to a nil endVerse, displaying one number
    @Test func singleVerseClosedRangeCollapsesEndVerse() {
        let range = RenderedVerseRange(range: 1...1)

        #expect(range.endVerse == nil)
        #expect(range.displayText == "1")
    }

    /// A ClosedRange with distinct bounds keeps its endVerse, displaying the full range
    @Test func multiVerseClosedRangeDisplaysRangeWithEnDash() {
        let range = RenderedVerseRange(range: 1...3)

        #expect(range.startVerse == 1)
        #expect(range.endVerse == 3)
        #expect(range.displayText == "1–3")
    }
}
