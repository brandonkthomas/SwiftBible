//
//  LibraryFilterTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-07-19.
//

import Foundation
import Testing
@testable import SwiftBible

struct LibraryFilterTests {

    /// a default LibraryFilter() matches every annotation
    @Test func emptyFilterMatchesEverything() throws {
        let annotations = try sampleAnnotations()
        let filter = LibraryFilter()

        let results = annotations.filter { filter.matches($0) }

        #expect(results == annotations)
    }

    /// each filter dimension alone keeps only the annotations matching that value
    @Test func individualFiltersKeepTheRightSubset() throws {
        let annotations = try sampleAnnotations()

        let genesisResults = annotations.filter { LibraryFilter(bookCode: "GEN").matches($0) }
        let translationResults = annotations.filter { LibraryFilter(translationID: 456).matches($0) }
        let noteResults = annotations.filter { LibraryFilter(contentType: .note).matches($0) }
        let yellowResults = annotations.filter { LibraryFilter(highlightColor: .yellow).matches($0) }
        let tagResults = annotations.filter { LibraryFilter(tag: "memory").matches($0) }

        #expect(genesisResults == [annotations[0], annotations[1], annotations[2]])
        #expect(translationResults == [annotations[3]])
        #expect(noteResults == [annotations[1]])
        #expect(yellowResults == [annotations[0]])
        #expect(tagResults == [annotations[2]])
    }

    /// two criteria together require both values to match
    @Test func combinedFiltersRequireEveryCriterion() throws {
        let annotations = try sampleAnnotations()
        let filter = LibraryFilter(bookCode: "GEN", contentType: .highlight)

        let results = annotations.filter { filter.matches($0) }

        #expect(results == [annotations[0]])
    }

    /// mutually exclusive content filters return no matches instead of leaking partial matches
    @Test func mutuallyExclusiveContentFiltersReturnEmpty() throws {
        let annotations = try sampleAnnotations()
        let filter = LibraryFilter(contentType: .highlight, tag: "memory")

        let results = annotations.filter { filter.matches($0) }

        #expect(results == [])
    }

    private func sampleAnnotations() throws -> [VerseAnnotation] {
        [
            try makeAnnotation(translationID: 123,
                               bookCode: "GEN",
                               chapter: 1,
                               verse: 1,
                               content: .highlight(.yellow)),
            try makeAnnotation(translationID: 123,
                               bookCode: "GEN",
                               chapter: 1,
                               verse: 2,
                               content: .note("Creation note")),
            try makeAnnotation(translationID: 123,
                               bookCode: "GEN",
                               chapter: 1,
                               verse: 3,
                               content: .tags(["memory", "creation"])),
            try makeAnnotation(translationID: 456,
                               bookCode: "EXO",
                               chapter: 2,
                               verse: 1,
                               content: .highlight(.green))
        ]
    }

    private func makeAnnotation(translationID: Translation.ID,
                                bookCode: String,
                                chapter: Int,
                                verse: Int,
                                content: AnnotationContent) throws -> VerseAnnotation {
        let reference = try #require(ScriptureReference(translationID: translationID,
                                                        bookCode: bookCode,
                                                        chapter: chapter,
                                                        startVerse: verse,
                                                        endVerse: nil))
        let verseRange = try #require(reference.verseRange)

        return try #require(VerseAnnotation(reference: reference,
                                            selectedVerses: verseRange,
                                            content: content))
    }
}
