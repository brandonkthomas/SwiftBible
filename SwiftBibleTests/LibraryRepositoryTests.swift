//
//  LibraryRepositoryTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-07-10.
//

import Testing
@testable import SwiftBible

struct LibraryRepositoryTests {

    /// saving one annotation returns it for the same chapter reference
    @Test func oneAnnotationSaves() throws {
        let repository = InMemoryLibraryRepository()
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

        guard let annotation else {
            #expect(Bool(false)); return
        }

        try repository.save(annotation)
        let results = try repository.annotations(for: reference)

        #expect(results == [annotation])
    }

    /// different chapter does not return it
    @Test func differentChaptersAreNotReturned() throws {
        let repository = InMemoryLibraryRepository()
        let reference1 = ScriptureReference(translationID: 123,
                                            bookCode: "GEN",
                                            chapter: 1,
                                            startVerse: 16,
                                            endVerse: nil)!
        let reference2 = ScriptureReference(translationID: 123,
                                            bookCode: "GEN",
                                            chapter: 2,
                                            startVerse: 16,
                                            endVerse: nil)!
        let annotation1 = VerseAnnotation(reference: reference1,
                                          selectedVerses: reference1.verseRange!,
                                          highlightColor: nil,
                                          note: "Note content",
                                          tags: nil)
        let annotation2 = VerseAnnotation(reference: reference2,
                                          selectedVerses: reference2.verseRange!,
                                          highlightColor: nil,
                                          note: "Note content",
                                          tags: nil)

        guard let annotation1,
              let annotation2 else {
            #expect(Bool(false)); return
        }

        try repository.save(annotation1)
        try repository.save(annotation2)
        let results = try repository.annotations(for: reference1)

        #expect(results == [annotation1])
    }

    /// different translation does not return it
    @Test func differentTranslationsAreNotReturned() throws {
        let repository = InMemoryLibraryRepository()
        let reference1 = ScriptureReference(translationID: 123,
                                            bookCode: "GEN",
                                            chapter: 1,
                                            startVerse: 16,
                                            endVerse: nil)!
        let reference2 = ScriptureReference(translationID: 456,
                                            bookCode: "GEN",
                                            chapter: 1,
                                            startVerse: 16,
                                            endVerse: nil)!
        let annotation1 = VerseAnnotation(reference: reference1,
                                          selectedVerses: reference1.verseRange!,
                                          highlightColor: nil,
                                          note: "Note content",
                                          tags: nil)
        let annotation2 = VerseAnnotation(reference: reference2,
                                          selectedVerses: reference2.verseRange!,
                                          highlightColor: nil,
                                          note: "Note content",
                                          tags: nil)

        guard let annotation1,
              let annotation2 else {
            #expect(Bool(false)); return
        }

        try repository.save(annotation1)
        try repository.save(annotation2)

        let results = try repository.annotations(for: reference1)

        #expect(results == [annotation1])
    }

    /// no matches returns [], not an error
    @Test func noMatchesReturnsEmpty() throws {
        let repository = InMemoryLibraryRepository()
        let reference1 = ScriptureReference(translationID: 123,
                                            bookCode: "GEN",
                                            chapter: 1,
                                            startVerse: 16,
                                            endVerse: nil)!
        let reference2 = ScriptureReference(translationID: 456,
                                            bookCode: "GEN",
                                            chapter: 1,
                                            startVerse: 16,
                                            endVerse: nil)!
        let annotation1 = VerseAnnotation(reference: reference1,
                                          selectedVerses: reference1.verseRange!,
                                          highlightColor: nil,
                                          note: "Note content",
                                          tags: nil)

        guard let annotation1 else {
            #expect(Bool(false)); return
        }

        try repository.save(annotation1)

        let results = try repository.annotations(for: reference2)

        #expect(results == [])
    }

}
