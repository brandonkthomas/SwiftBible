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
    @Test func singleVerseStoresProperly() throws {
        let reference = try #require(ScriptureReference(translationID: 123,
                                                        bookCode: "GEN",
                                                        chapter: 1,
                                                        startVerse: 16,
                                                        endVerse: nil))
        let verseRange = try #require(reference.verseRange)
        let annotation = try #require(VerseAnnotation(reference: reference,
                                                      selectedVerses: verseRange,
                                                      content: .note("Note content")))

        #expect(annotation.startVerse == 16)
        #expect(annotation.endVerse == nil)
    }

    /// range 16...17 stores startVerse == 16 and endVerse == 17
    @Test func twoVersesStoreProperly() throws {
        let reference = try #require(ScriptureReference(translationID: 123,
                                                        bookCode: "GEN",
                                                        chapter: 1,
                                                        startVerse: 16,
                                                        endVerse: 17))
        let verseRange = try #require(reference.verseRange)
        let annotation = try #require(VerseAnnotation(reference: reference,
                                                      selectedVerses: verseRange,
                                                      content: .note("Note content")))

        #expect(annotation.startVerse == 16)
        #expect(annotation.endVerse == 17)
    }

    /// reference fields copy through from ScriptureReference
    @Test func referenceFieldsStoreProperly() throws {
        let reference = try #require(ScriptureReference(translationID: 123,
                                                        bookCode: "GEN",
                                                        chapter: 1,
                                                        startVerse: 16,
                                                        endVerse: 17))
        let verseRange = try #require(reference.verseRange)
        let annotation = try #require(VerseAnnotation(reference: reference,
                                                      selectedVerses: verseRange,
                                                      content: .note("Note content")))

        #expect(annotation.translationID == 123)
        #expect(annotation.bookCode == "GEN")
        #expect(annotation.chapter == 1)
    }

    /// updatedAt starts as nil
    @Test func updatedAtDefaultsToNil() throws {
        let reference = try #require(ScriptureReference(translationID: 123,
                                                        bookCode: "GEN",
                                                        chapter: 1,
                                                        startVerse: 16,
                                                        endVerse: 17))
        let verseRange = try #require(reference.verseRange)
        let annotation = try #require(VerseAnnotation(reference: reference,
                                                      selectedVerses: verseRange,
                                                      content: .note("Note content")))

        #expect(annotation.updatedAt == nil)
    }

    /// injected id and createdAt are retained, so tests don't depend on random UUID/time
    @Test func idAndDatePersist() throws {
        let id = UUID()
        let createdAt = Date()

        let reference = try #require(ScriptureReference(translationID: 123,
                                                        bookCode: "GEN",
                                                        chapter: 1,
                                                        startVerse: 16,
                                                        endVerse: 17))
        let verseRange = try #require(reference.verseRange)
        let annotation = try #require(VerseAnnotation(id: id,
                                                      reference: reference,
                                                      selectedVerses: verseRange,
                                                      content: .note("Note content"),
                                                      createdAt: createdAt))

        #expect(annotation.id == id)
        #expect(annotation.createdAt == createdAt)
    }

    /// if the provided content is empty, init should fail + return nil
    @Test func noProvidedDataIsRejected() throws {
        let id = UUID()
        let createdAt = Date()

        let reference = try #require(ScriptureReference(translationID: 123,
                                                        bookCode: "GEN",
                                                        chapter: 1,
                                                        startVerse: 16,
                                                        endVerse: 17))
        let verseRange = try #require(reference.verseRange)
        let annotation = VerseAnnotation(id: id,
                                         reference: reference,
                                         selectedVerses: verseRange,
                                         content: .note(""),
                                         createdAt: createdAt)

        #expect(annotation == nil)
    }

    /// whitespace-only note/tag values are treated as missing data
    @Test func whitespaceOnlyDataIsRejected() throws {
        let reference = try #require(ScriptureReference(translationID: 123,
                                                        bookCode: "GEN",
                                                        chapter: 1,
                                                        startVerse: 16,
                                                        endVerse: 17))
        let verseRange = try #require(reference.verseRange)

        let noteAnnotation = VerseAnnotation(reference: reference,
                                             selectedVerses: verseRange,
                                             content: .note("\n\t"))
        let tagAnnotation = VerseAnnotation(reference: reference,
                                            selectedVerses: verseRange,
                                            content: .tags(["", "   "]))

        #expect(noteAnnotation == nil)
        #expect(tagAnnotation == nil)
    }

    /// at least one meaningful tag is enough to create an annotation
    @Test func meaningfulTagIsAccepted() throws {
        let reference = try #require(ScriptureReference(translationID: 123,
                                                        bookCode: "GEN",
                                                        chapter: 1,
                                                        startVerse: 16,
                                                        endVerse: 17))
        let verseRange = try #require(reference.verseRange)

        let annotation = try #require(VerseAnnotation(reference: reference,
                                                      selectedVerses: verseRange,
                                                      content: .tags(["", "memory"])))

        #expect(annotation.content == .tags(["", "memory"]))
    }
}
