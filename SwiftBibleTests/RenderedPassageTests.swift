//
//  RenderedPassageTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-09-16.
//

import Testing
@testable import SwiftBible

struct RenderedPassageTests {

    /// A single-verse request returns a run tagged with that same verse
    @Test func singleVerseRequestMatchesSingleVerseRun() {
        let matchingRun = RenderedPassageRun.text(
            "Verse two",
            verseRange: RenderedVerseRange(startVerse: 2)
        )
        let passage = makePassage(runs: [
            .text("Verse one", verseRange: RenderedVerseRange(startVerse: 1)),
            matchingRun,
            .text("Verse three", verseRange: RenderedVerseRange(startVerse: 3))
        ])

        let result = passage.runs(for: RenderedVerseRange(startVerse: 2))

        #expect(result == [matchingRun])
    }

    /// A multi-verse request collects runs individually tagged with every requested verse
    @Test func multiVerseRequestCollectsIndividuallyTaggedRuns() {
        let firstRun = RenderedPassageRun.text(
            "Verse one",
            verseRange: RenderedVerseRange(startVerse: 1)
        )
        let secondRun = RenderedPassageRun.text(
            "Verse two",
            verseRange: RenderedVerseRange(startVerse: 2)
        )
        let thirdRun = RenderedPassageRun.text(
            "Verse three",
            verseRange: RenderedVerseRange(startVerse: 3)
        )
        let passage = makePassage(runs: [
            firstRun,
            secondRun,
            thirdRun,
            .text("Verse four", verseRange: RenderedVerseRange(startVerse: 4))
        ])

        let result = passage.runs(
            for: RenderedVerseRange(startVerse: 1, endVerse: 3)
        )

        #expect(result == [firstRun, secondRun, thirdRun])
    }

    /// A run is included when its verse range partially overlaps the requested range
    @Test func partiallyOverlappingRangesMatch() {
        let overlappingRun = RenderedPassageRun.text(
            "Verses two through four",
            verseRange: RenderedVerseRange(startVerse: 2, endVerse: 4)
        )
        let passage = makePassage(runs: [
            .text("Verse one", verseRange: RenderedVerseRange(startVerse: 1)),
            overlappingRun
        ])

        let result = passage.runs(
            for: RenderedVerseRange(startVerse: 3, endVerse: 5)
        )

        #expect(result == [overlappingRun])
    }

    /// Ranges that meet at one inclusive boundary verse are treated as overlapping
    @Test func boundaryVerseOverlapMatches() {
        let boundaryRun = RenderedPassageRun.text(
            "Verses one and two",
            verseRange: RenderedVerseRange(startVerse: 1, endVerse: 2)
        )
        let passage = makePassage(runs: [boundaryRun])

        let result = passage.runs(
            for: RenderedVerseRange(startVerse: 2, endVerse: 3)
        )

        #expect(result == [boundaryRun])
    }

    /// A run is excluded when its verse range does not overlap the requested range
    @Test func nonOverlappingRangesDoNotMatch() {
        let passage = makePassage(runs: [
            .text(
                "Verses one and two",
                verseRange: RenderedVerseRange(startVerse: 1, endVerse: 2)
            )
        ])

        let result = passage.runs(
            for: RenderedVerseRange(startVerse: 3, endVerse: 4)
        )

        #expect(result.isEmpty)
    }

    /// Runs without verse metadata are excluded even when surrounded by matching runs
    @Test func runsWithoutVerseMetadataAreExcluded() {
        let firstMatchingRun = RenderedPassageRun.text(
            "Verse one",
            verseRange: RenderedVerseRange(startVerse: 1)
        )
        let secondMatchingRun = RenderedPassageRun.verseLabel(
            displayText: "1",
            verseRange: RenderedVerseRange(startVerse: 1)
        )
        let passage = makePassage(runs: [
            firstMatchingRun,
            .text("Untitled introduction", verseRange: nil),
            secondMatchingRun
        ])

        let result = passage.runs(for: RenderedVerseRange(startVerse: 1))

        #expect(result == [firstMatchingRun, secondMatchingRun])
    }

    /// Matching runs retain their original order across paragraph boundaries
    @Test func matchingRunsPreserveOutputOrder() {
        let firstRun = RenderedPassageRun.verseLabel(
            displayText: "1–3",
            verseRange: RenderedVerseRange(startVerse: 1, endVerse: 3)
        )
        let secondRun = RenderedPassageRun.text(
            "First paragraph",
            verseRange: RenderedVerseRange(startVerse: 1, endVerse: 3)
        )
        let thirdRun = RenderedPassageRun.text(
            "Second paragraph",
            verseRange: RenderedVerseRange(startVerse: 1, endVerse: 3)
        )
        let passage = RenderedPassage(
            paragraphs: [
                RenderedParagraph(runs: [firstRun, secondRun]),
                RenderedParagraph(runs: [thirdRun])
            ],
            footnotes: []
        )

        let result = passage.runs(
            for: RenderedVerseRange(startVerse: 1, endVerse: 3)
        )

        #expect(result == [firstRun, secondRun, thirdRun])
    }

    private func makePassage(runs: [RenderedPassageRun]) -> RenderedPassage {
        RenderedPassage(
            paragraphs: [RenderedParagraph(runs: runs)],
            footnotes: []
        )
    }
}
