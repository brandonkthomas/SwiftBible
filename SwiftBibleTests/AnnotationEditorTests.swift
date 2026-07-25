//
//  AnnotationEditorTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-07-25.
//

import Foundation
import Testing
@testable import SwiftBible

// for testing only; Swift warns about main-actor default isolation,
// and AnnotationEditor is observable UI state; use @MainActor to run these on UI actor
@MainActor
struct AnnotationEditorTests {

    /// noteText and tags are populated when loading AnnotationEditor
    @Test func readsFromRepository() throws {
        let noteContent1 = "Note content"
        let tags = ["Tag 1", "Tag 2"]

        let repository = InMemoryLibraryRepository()

        let reference = try #require(ScriptureReference(translationID: 123,
                                                        bookCode: "GEN",
                                                        chapter: 1,
                                                        startVerse: 1,
                                                        endVerse: 3))

        let annotation1 = try #require(VerseAnnotation(reference: reference,
                                                       selectedVerses: 1...3,
                                                       content: .note(noteContent1)))
        let annotation2 = try #require(VerseAnnotation(reference: reference,
                                                       selectedVerses: 1...3,
                                                       content: .tags(tags)))

        try repository.save(annotation1)
        try repository.save(annotation2)

        let annotationEditor = AnnotationEditor(reference: reference,
                                                selectedVerses: 1...3,
                                                libraryRepository: repository)

        annotationEditor.load()

        #expect(annotationEditor.noteText == noteContent1)
        #expect(annotationEditor.tags == tags)
    }

    /// annotations outside selected range are ignored
    @Test func rangeIsNarrowed() throws {
        let noteContent1 = "Note content"
        let tags = ["Tag 1", "Tag 2"]

        let repository = InMemoryLibraryRepository()

        let reference = try #require(ScriptureReference(translationID: 123,
                                                        bookCode: "GEN",
                                                        chapter: 1,
                                                        startVerse: 1,
                                                        endVerse: 3))

        let annotation1 = try #require(VerseAnnotation(reference: reference,
                                                       selectedVerses: 5...7,
                                                       content: .note(noteContent1)))

        try repository.save(annotation1)

        let annotationEditor = AnnotationEditor(reference: reference,
                                                selectedVerses: 1...3,
                                                libraryRepository: repository)

        annotationEditor.load()

        #expect(annotationEditor.noteText.isEmpty)
    }

    /// a range with nothing saved loads to empty noteText and []
    @Test func loadsEmptyWhenNothingIsSaved() throws {
        let repository = InMemoryLibraryRepository()

        let reference = try #require(ScriptureReference(translationID: 123,
                                                        bookCode: "GEN",
                                                        chapter: 1,
                                                        startVerse: 1,
                                                        endVerse: 3))

        let annotationEditor = AnnotationEditor(reference: reference,
                                                selectedVerses: 1...3,
                                                libraryRepository: repository)

        annotationEditor.load()

        #expect(annotationEditor.noteText.isEmpty)
        #expect(annotationEditor.tags.isEmpty)
    }
}
