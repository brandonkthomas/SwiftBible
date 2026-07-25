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
// and ReaderStore is observable UI state; use @MainActor to run these on UI actor
@MainActor
struct AnnotationEditorTests {

    /// noteText and tags are populated when loading AnnotationEditor
    @Test func readsFromRepository() async throws {
        let repository = InMemoryLibraryRepository()

        let reference = try #require(ScriptureReference(translationID: 123,
                                                        bookCode: "GEN",
                                                        chapter: 1,
                                                        startVerse: 1,
                                                        endVerse: 3))

        let annotation1 = try #require(VerseAnnotation(reference: reference,
                                                       selectedVerses: 1...3,
                                                       content: .note("Note content")))
        let annotation2 = try #require(VerseAnnotation(reference: reference,
                                                       selectedVerses: 1...3,
                                                       content: .tags(["Tag 1", "Tag 2"])))

        try repository.save(annotation1)
        try repository.save(annotation2)

        let annotationEditor = AnnotationEditor(reference: reference,
                                                selectedVerses: 1...3,
                                                libraryRepository: repository)

        annotationEditor.load()

        #expect(annotationEditor.noteText.isEmpty == false)
        #expect(annotationEditor.tags.isEmpty == false)
    }

    /// a range with nothing saved loads to empty noteText and []
    @Test func loadsEmptyWhenNothingIsSaved() async throws {
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

        #expect(annotationEditor.noteText.isEmpty == true)
        #expect(annotationEditor.tags.isEmpty == true)
    }
}
