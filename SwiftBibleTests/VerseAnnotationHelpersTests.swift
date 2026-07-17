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
