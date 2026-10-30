//
//  VerseAnnotationHelpersTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-07-13.
//

import Foundation
import Testing
@testable import SwiftBible

struct VerseAnnotationHelpersTests {

    /// A single 3-verse highlight expands into three per-verse color entries
    @Test func threeVerseRangeProducesThreeEntries() throws {
        let annotation = makeAnnotation(start: 16,
                                        end: 18,
                                        color: .yellow,
                                        translationID: 123,
                                        createdAt: .now)

        // Whole-chapter reference (startVerse: nil), matching what ReaderStore supplies
        let passageReference = try #require(ScriptureReference(translationID: 123,
                                                               bookCode: "GEN",
                                                               chapter: 1))

        let result = VerseAnnotationHelpers.getPassageHighlightColors(for: [annotation],
                                                                      reference: passageReference)

        #expect(result.count == 3)
        #expect(result[16] == .yellow)
        #expect(result[17] == .yellow)
        #expect(result[18] == .yellow)
    }

    /// 1 stored object expands to 3 drawn entries without mutating the source
    @Test func sourceStaysOneRange() throws {
        let annotation = makeAnnotation(start: 16,
                                        end: 18,
                                        color: .yellow,
                                        translationID: 123,
                                        createdAt: .now)

        let passageReference = try #require(ScriptureReference(translationID: 123,
                                                               bookCode: "GEN",
                                                               chapter: 1))

        let annotations = [annotation]
        let result = VerseAnnotationHelpers.getPassageHighlightColors(for: annotations,
                                                                      reference: passageReference)

        #expect(annotations.count == 1)

        #expect(result.count == 3)
        #expect(result[16] == .yellow)
        #expect(result[17] == .yellow)
        #expect(result[18] == .yellow)
    }

    /// Translations isolate their annotations
    @Test func annotationsForTranslationsAreIsolated() throws {
        let annotation1 = makeAnnotation(start: 16,
                                         end: 18,
                                         color: .yellow,
                                         translationID: 123,
                                         createdAt: .now)

        let passageReference = try #require(ScriptureReference(translationID: 456,
                                                               bookCode: "GEN",
                                                               chapter: 1))

        let annotations = [annotation1]
        let result = VerseAnnotationHelpers.getPassageHighlightColors(for: annotations,
                                                                      reference: passageReference)

        #expect(result.isEmpty)
    }

    /// Most recent annotations on overlapping verse ranges take precidence in UI over older annotations
    @Test func recentAnnotationsOnSameRangeTakePrecidence() throws {
        let annotation1 = makeAnnotation(start: 16,
                                         end: 17,
                                         color: .yellow,
                                         translationID: 123,
                                         createdAt: .distantPast)
        let annotation2 = makeAnnotation(start: 17,
                                         end: 18,
                                         color: .pink,
                                         translationID: 123,
                                         createdAt: .now)

        let passageReference = try #require(ScriptureReference(translationID: 123,
                                                               bookCode: "GEN",
                                                               chapter: 1))

        let annotations = [annotation1,annotation2]
        let result = VerseAnnotationHelpers.getPassageHighlightColors(for: annotations,
                                                                      reference: passageReference)

        #expect(result.count == 3)
        #expect(result[16] == .yellow)
        #expect(result[17] == .pink)
        #expect(result[18] == .pink)
    }

    /// Note/tag annotations do not return any colors from getPassageHighlightColors()
    @Test func nonHighlightAnnotationsDoNotContribute() throws {
        let annotation1 = makeAnnotation(start: 16,
                                         end: 17,
                                         color: nil,
                                         note: "Hello",
                                         translationID: 123,
                                         createdAt: .now)

        let passageReference = try #require(ScriptureReference(translationID: 123,
                                                               bookCode: "GEN",
                                                               chapter: 1))

        let annotations = [annotation1]
        let result = VerseAnnotationHelpers.getPassageHighlightColors(for: annotations,
                                                                      reference: passageReference)

        #expect(result.isEmpty)
    }

    // MARK: getPassageVersesWithTextAnnotations

    /// A note on a single verse marks only that verse
    @Test func singleVerseNoteMarksThatVerse() throws {
        let annotation = makeTextAnnotation(start: 7, end: nil, content: .note("Hello"))

        let passageReference = try #require(ScriptureReference(translationID: 123,
                                                               bookCode: "GEN",
                                                               chapter: 1))

        let result = VerseAnnotationHelpers.getPassageVersesWithTextAnnotations(for: [annotation],
                                                                                reference: passageReference)

        #expect(result == [7])
    }

    /// Tags on a verse range mark every verse in that range
    @Test func tagsOnVerseRangeMarkEveryVerse() throws {
        let annotation = makeTextAnnotation(start: 3, end: 5, content: .tags(["faith"]))

        let passageReference = try #require(ScriptureReference(translationID: 123,
                                                               bookCode: "GEN",
                                                               chapter: 1))

        let result = VerseAnnotationHelpers.getPassageVersesWithTextAnnotations(for: [annotation],
                                                                                reference: passageReference)

        #expect(result == [3, 4, 5])
    }

    /// Highlights are excluded from text annotation markers
    @Test func highlightAloneMarksNothing() throws {
        let annotation = makeTextAnnotation(start: 3, end: 5, content: .highlight(.yellow))

        let passageReference = try #require(ScriptureReference(translationID: 123,
                                                               bookCode: "GEN",
                                                               chapter: 1))

        let result = VerseAnnotationHelpers.getPassageVersesWithTextAnnotations(for: [annotation],
                                                                                reference: passageReference)

        #expect(result.isEmpty)
    }

    /// Annotations from a different chapter don't mark verses in this chapter
    @Test func annotationFromOtherChapterMarksNothing() throws {
        let annotation = makeTextAnnotation(start: 3, end: nil, chapter: 2, content: .note("Hello"))

        let passageReference = try #require(ScriptureReference(translationID: 123,
                                                               bookCode: "GEN",
                                                               chapter: 1))

        let result = VerseAnnotationHelpers.getPassageVersesWithTextAnnotations(for: [annotation],
                                                                                reference: passageReference)

        #expect(result.isEmpty)
    }

    // MARK: getTextAnnotation

    /// Tapping a single-verse note returns that verse
    @Test func tappedSingleVerseNoteReturnsThatVerse() throws {
        let annotation = makeTextAnnotation(start: 7, end: nil, content: .note("Hello"))

        let passageReference = try #require(ScriptureReference(translationID: 123,
                                                               bookCode: "GEN",
                                                               chapter: 1))

        let result = VerseAnnotationHelpers.getTextAnnotation(for: [annotation],
                                                              reference: passageReference,
                                                              verse: 7)

        #expect(result?.verseRange == 7...7)
    }

    /// Tapping any verse inside a ranged tag annotation returns the full range
    @Test func tappedVerseInsideTagRangeReturnsFullRange() throws {
        let annotation = makeTextAnnotation(start: 3, end: 5, content: .tags(["faith"]))

        let passageReference = try #require(ScriptureReference(translationID: 123,
                                                               bookCode: "GEN",
                                                               chapter: 1))

        let result = VerseAnnotationHelpers.getTextAnnotation(for: [annotation],
                                                              reference: passageReference,
                                                              verse: 4)

        #expect(result?.verseRange == 3...5)
    }

    /// Overlapping note/tag annotations resolve to the most recently updated one
    @Test func tappedOverlappingAnnotationsReturnsNewest() throws {
        let note = makeTextAnnotation(start: 3,
                                      end: 5,
                                      content: .note("Hello"),
                                      createdAt: .distantPast,
                                      updatedAt: .distantPast.addingTimeInterval(60))
        let tags = makeTextAnnotation(start: 4,
                                      end: nil,
                                      content: .tags(["faith"]),
                                      createdAt: .now)

        let passageReference = try #require(ScriptureReference(translationID: 123,
                                                               bookCode: "GEN",
                                                               chapter: 1))

        let result = VerseAnnotationHelpers.getTextAnnotation(for: [note, tags],
                                                              reference: passageReference,
                                                              verse: 4)

        #expect(result?.verseRange == 4...4)
    }

    /// Highlights never resolve to an editable text annotation
    @Test func tappedHighlightOnlyReturnsNil() throws {
        let annotation = makeTextAnnotation(start: 3, end: 5, content: .highlight(.yellow))

        let passageReference = try #require(ScriptureReference(translationID: 123,
                                                               bookCode: "GEN",
                                                               chapter: 1))

        let result = VerseAnnotationHelpers.getTextAnnotation(for: [annotation],
                                                              reference: passageReference,
                                                              verse: 4)

        #expect(result == nil)
    }

    /// Annotations from a different chapter don't resolve
    @Test func tappedVerseWithAnnotationInOtherChapterReturnsNil() throws {
        let annotation = makeTextAnnotation(start: 3, end: nil, chapter: 2, content: .note("Hello"))

        let passageReference = try #require(ScriptureReference(translationID: 123,
                                                               bookCode: "GEN",
                                                               chapter: 1))

        let result = VerseAnnotationHelpers.getTextAnnotation(for: [annotation],
                                                              reference: passageReference,
                                                              verse: 3)

        #expect(result == nil)
    }

    private func makeTextAnnotation(
        start: Int,
        end: Int?,
        chapter: Int = 1,
        content: AnnotationContent,
        createdAt: Date = .now,
        updatedAt: Date? = nil)
    -> VerseAnnotation {
        .init(
            id: UUID(),
            translationID: 123,
            bookCode: "GEN",
            chapter: chapter,
            startVerse: start,
            endVerse: end,
            content: content,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func makeAnnotation(
        start: Int,
        end: Int?,
        color: VerseAnnotationHighlightColor?,
        note: String? = nil,
        translationID: Int,
        createdAt: Date)
    -> VerseAnnotation {
        let content: AnnotationContent = if let color {
            .highlight(color)
        } else {
            .note(note ?? "")
        }

        return .init(
            id: UUID(),
            translationID: translationID,
            bookCode: "GEN",
            chapter: 1,
            startVerse: start,
            endVerse: end,
            content: content,
            createdAt: createdAt
        )
    }
}
