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

    /// Creates both annotations when nothing existed (assert content round-trips)
    @Test func emptyRepoCreatesNewAnnotations() throws {
        let noteContent1 = "Note content"
        let tags = ["Tag 1", "Tag 2"]

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
        annotationEditor.noteText = noteContent1
        annotationEditor.tags = tags
        annotationEditor.save()

        let annotations = try repository.allAnnotations()

        #expect(annotations.count == 2)

        let noteAnnotation = try #require(annotations.first { $0.content.type == .note })
        #expect(noteAnnotation.content == .note(noteContent1))

        let tagAnnotation = try #require(annotations.first { $0.content.type == .tags })
        #expect(tagAnnotation.content == .tags(tags))
    }

    /// Updates without duplicating: load an existing note, change the text, save;
    /// still exactly one .note annotation for that range, with the new text.
    @Test func updatesWithoutDuplicating() throws {
        let repository = InMemoryLibraryRepository()

        let reference = try #require(ScriptureReference(translationID: 123,
                                                        bookCode: "GEN",
                                                        chapter: 1,
                                                        startVerse: 1,
                                                        endVerse: 3))

        let annotation1 = try #require(VerseAnnotation(reference: reference,
                                                       selectedVerses: 1...3,
                                                       content: .note("Note content")))

        try repository.save(annotation1)

        let annotationEditor = AnnotationEditor(reference: reference,
                                                selectedVerses: 1...3,
                                                libraryRepository: repository)

        annotationEditor.load()
        annotationEditor.noteText = "Updated note content"
        annotationEditor.save()

        let annotations = try repository.allAnnotations()

        #expect(annotations.count == 1)

        let noteAnnotation = try #require(annotations.first { $0.content.type == .note })
        #expect(noteAnnotation.content == .note("Updated note content"))
    }

    /// Delete on clear: existing note + tags, set noteText = "", save;
    /// the note annotation is gone, tags remain.
    @Test func deletesOnClear() throws {
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
        annotationEditor.noteText = ""
        annotationEditor.save()

        let annotations = try repository.allAnnotations()

        let tagAnnotation = try #require(annotations.first { $0.content.type == .tags })
        #expect(tagAnnotation.content == .tags(tags))
    }

    /// Whitespace-only note creates nothing
    @Test func whitespaceOnlyCreatesNothing() throws {
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
        annotationEditor.noteText = " "
        annotationEditor.save()

        let annotations = try repository.allAnnotations()

        #expect(annotations.count == 0)
    }

    /// Double save() produces one note annotation, not two (the id write-back)
    @Test func twoSavesProduceOneNote() throws {
        let repository = InMemoryLibraryRepository()

        let reference = try #require(ScriptureReference(translationID: 123,
                                                        bookCode: "GEN",
                                                        chapter: 1,
                                                        startVerse: 1,
                                                        endVerse: 3))

        let annotation1 = try #require(VerseAnnotation(reference: reference,
                                                       selectedVerses: 1...3,
                                                       content: .note("Note content")))

        try repository.save(annotation1)

        let annotationEditor = AnnotationEditor(reference: reference,
                                                selectedVerses: 1...3,
                                                libraryRepository: repository)

        annotationEditor.load()
        annotationEditor.save()
        annotationEditor.save()

        var annotations = try repository.allAnnotations()

        annotations = try repository.allAnnotations()

        #expect(annotations.count == 1)
    }

    /// Seed annotations on different verse ranges with overlapping tags
    ///  say "Faith" three times, "Creation" once, "creation" once
    ///  then load() and assert:
    ///  tagVocabulary starts with "Faith" (highest count),
    ///     contains no case-duplicate of Creation,
    ///     and has exactly 2 entries
    @Test func tagVocabularyPopulatesAsExpected() throws {
        let repository = InMemoryLibraryRepository()

        let reference = try #require(ScriptureReference(translationID: 123,
                                                        bookCode: "GEN",
                                                        chapter: 1,
                                                        startVerse: 1,
                                                        endVerse: 3))

        let annotation1 = try #require(VerseAnnotation(reference: reference,
                                                       selectedVerses: 1...3,
                                                       content: .tags(["Faith"])))

        // Faith appears 3 times (across different ranges) → highest count.
        let annotation2 = try #require(VerseAnnotation(reference: reference,
                                                       selectedVerses: 5...7,
                                                       content: .tags(["Faith"])))
        let annotation3 = try #require(VerseAnnotation(reference: reference,
                                                       selectedVerses: 9...11,
                                                       content: .tags(["Faith"])))

        // "Creation" and "creation" normalize to the same key → one entry, count 2.
        // "Creation" is saved first, so its display spelling wins.
        let annotation4 = try #require(VerseAnnotation(reference: reference,
                                                       selectedVerses: 13...13,
                                                       content: .tags(["Creation"])))
        let annotation5 = try #require(VerseAnnotation(reference: reference,
                                                       selectedVerses: 15...15,
                                                       content: .tags(["creation"])))

        try repository.save(annotation1)
        try repository.save(annotation2)
        try repository.save(annotation3)
        try repository.save(annotation4)
        try repository.save(annotation5)

        let annotationEditor = AnnotationEditor(reference: reference,
                                                selectedVerses: 1...3,
                                                libraryRepository: repository)

        annotationEditor.load()

        #expect(annotationEditor.tagVocabulary[0] == "Faith")
        #expect(!annotationEditor.tagVocabulary.contains { $0 == "creation" })
        #expect(annotationEditor.tagVocabulary.count == 2)
    }

    /// Tag selection normalizes identity while preserving display spelling
    @Test func tagSubscriptNormalizesAndRemoves() throws {
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

        annotationEditor[tagIsSelected: " Faith "] = true
        #expect(annotationEditor.tags == ["Faith"])
        #expect(annotationEditor[tagIsSelected: "faith"] == true)

        annotationEditor[tagIsSelected: "FAITH"] = true
        #expect(annotationEditor.tags == ["Faith"])
        #expect(annotationEditor[tagIsSelected: "faith"] == true)

        annotationEditor[tagIsSelected: " faith "] = false
        #expect(annotationEditor.tags.isEmpty)

        annotationEditor[tagIsSelected: " "] = true
        #expect(annotationEditor.tags.isEmpty)
    }
}
