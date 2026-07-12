//
//  VerseAnnotationTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 7/9/26.
//

import Foundation
import Testing
@testable import SwiftBible

struct VerseAnnotationTests {

    /// single selected verse 16...16 stores startVerse == 16 and endVerse == nil
    @Test func singleVerseStoresProperly() {
        let reference = ScriptureReference(translationID: 123,
                                           bookCode: "GEN",
                                           chapter: 1,
                                           startVerse: 16,
                                           endVerse: nil)!
        let annotation = VerseAnnotation(reference: reference,
                                         selectedVerses: reference.verseRange!,
                                         highlightColor: nil,
                                         note: "Note content",
                                         tags: nil)

        #expect(annotation?.startVerse == 16)
        #expect(annotation?.endVerse == nil)
    }

    /// range 16...17 stores startVerse == 16 and endVerse == 17
    @Test func twoVersesStoreProperly() {
        let reference = ScriptureReference(translationID: 123,
                                           bookCode: "GEN",
                                           chapter: 1,
                                           startVerse: 16,
                                           endVerse: 17)!
        let annotation = VerseAnnotation(reference: reference,
                                         selectedVerses: reference.verseRange!,
                                         highlightColor: nil,
                                         note: "Note content",
                                         tags: nil)

        #expect(annotation?.startVerse == 16)
        #expect(annotation?.endVerse == 17)
    }

    /// reference fields copy through from ScriptureReference
    @Test func referenceFieldsStoreProperly() {
        let reference = ScriptureReference(translationID: 123,
                                           bookCode: "GEN",
                                           chapter: 1,
                                           startVerse: 16,
                                           endVerse: 17)!
        let annotation = VerseAnnotation(reference: reference,
                                         selectedVerses: reference.verseRange!,
                                         highlightColor: nil,
                                         note: "Note content",
                                         tags: nil)

        #expect(annotation?.translationID == 123)
        #expect(annotation?.bookCode == "GEN")
        #expect(annotation?.chapter == 1)
    }

    /// updatedAt starts as nil
    @Test func updatedAtDefaultsToNil() {
        let reference = ScriptureReference(translationID: 123,
                                           bookCode: "GEN",
                                           chapter: 1,
                                           startVerse: 16,
                                           endVerse: 17)!
        let annotation = VerseAnnotation(reference: reference,
                                         selectedVerses: reference.verseRange!,
                                         highlightColor: nil,
                                         note: "Note content",
                                         tags: nil)

        #expect(annotation?.updatedAt == nil)
    }

    /// injected id and createdAt are retained, so tests don’t depend on random UUID/time
    @Test func idAndDatePersist() {
        let id = UUID()
        let createdAt = Date()

        let reference = ScriptureReference(translationID: 123,
                                           bookCode: "GEN",
                                           chapter: 1,
                                           startVerse: 16,
                                           endVerse: 17)!
        let annotation = VerseAnnotation(id: id,
                                         reference: reference,
                                         selectedVerses: reference.verseRange!,
                                         highlightColor: nil,
                                         note: "Note content",
                                         tags: nil,
                                         createdAt: createdAt)

        #expect(annotation?.id == id)
        #expect(annotation?.createdAt == createdAt)
    }

    /// if none of highlight/tags/note are provided, init should fail + return nil
    @Test func noProvidedDataIsRejected() {
        let id = UUID()
        let createdAt = Date()

        let reference = ScriptureReference(translationID: 123,
                                           bookCode: "GEN",
                                           chapter: 1,
                                           startVerse: 16,
                                           endVerse: 17)!
        let annotation = VerseAnnotation(id: id,
                                         reference: reference,
                                         selectedVerses: reference.verseRange!,
                                         highlightColor: nil,
                                         note: nil,
                                         tags: nil,
                                         createdAt: createdAt)

        #expect(annotation == nil)
    }

    /// whitespace-only highlight/note/tag values are treated as missing data
    @Test func whitespaceOnlyDataIsRejected() {
        let reference = ScriptureReference(translationID: 123,
                                           bookCode: "GEN",
                                           chapter: 1,
                                           startVerse: 16,
                                           endVerse: 17)!

        let annotation = VerseAnnotation(reference: reference,
                                         selectedVerses: reference.verseRange!,
                                         highlightColor: nil,
                                         note: "\n\t",
                                         tags: ["", "   "])

        #expect(annotation == nil)
    }

    /// at least one meaningful tag is enough to create an annotation
    @Test func meaningfulTagIsAccepted() {
        let reference = ScriptureReference(translationID: 123,
                                           bookCode: "GEN",
                                           chapter: 1,
                                           startVerse: 16,
                                           endVerse: 17)!

        let annotation = VerseAnnotation(reference: reference,
                                         selectedVerses: reference.verseRange!,
                                         highlightColor: nil,
                                         note: nil,
                                         tags: ["", "memory"])

        #expect(annotation?.tags == ["", "memory"])
    }
}
