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
        
        let reference = try #require(ScriptureReference(translationID: 123,
                                                        bookCode: "GEN",
                                                        chapter: 1,
                                                        startVerse: 16,
                                                        endVerse: nil))
        
        let verseRange = try #require(reference.verseRange)
        
        let annotation = try #require(VerseAnnotation(reference: reference,
                                                      selectedVerses: verseRange,
                                                      content: .note("Note content")))

        try repository.save(annotation)
        let results = try repository.annotations(for: reference)

        #expect(results == [annotation])
    }

    /// different chapter does not return it
    @Test func differentChaptersAreNotReturned() throws {
        let repository = InMemoryLibraryRepository()
        
        let reference1 = try #require(ScriptureReference(translationID: 123,
                                                         bookCode: "GEN",
                                                         chapter: 1,
                                                         startVerse: 16,
                                                         endVerse: nil))
        let verseRange1 = try #require(reference1.verseRange)
    
        let reference2 = try #require(ScriptureReference(translationID: 123,
                                                         bookCode: "GEN",
                                                         chapter: 2,
                                                         startVerse: 16,
                                                         endVerse: nil))
        let verseRange2 = try #require(reference2.verseRange)
        
        let annotation1 = try #require(VerseAnnotation(reference: reference1,
                                                       selectedVerses: verseRange1,
                                                       content: .note("Note content 1")))
        let annotation2 = try #require(VerseAnnotation(reference: reference2,
                                                       selectedVerses: verseRange2,
                                                       content: .note("Note content 2")))

        try repository.save(annotation1)
        try repository.save(annotation2)
        let results = try repository.annotations(for: reference1)

        #expect(results == [annotation1])
    }

    /// different translation does not return it
    @Test func differentTranslationsAreNotReturned() throws {
        let repository = InMemoryLibraryRepository()
        let reference1 = try #require(ScriptureReference(translationID: 123,
                                                         bookCode: "GEN",
                                                         chapter: 1,
                                                         startVerse: 16,
                                                         endVerse: nil))
        let verseRange1 = try #require(reference1.verseRange)

        let reference2 = try #require(ScriptureReference(translationID: 456,
                                                         bookCode: "GEN",
                                                         chapter: 1,
                                                         startVerse: 16,
                                                         endVerse: nil))
        let verseRange2 = try #require(reference2.verseRange)

        let annotation1 = try #require(VerseAnnotation(reference: reference1,
                                                       selectedVerses: verseRange1,
                                                       content: .note("Note content 1")))
        let annotation2 = try #require(VerseAnnotation(reference: reference2,
                                                       selectedVerses: verseRange2,
                                                       content: .note("Note content 2")))

        try repository.save(annotation1)
        try repository.save(annotation2)

        let results = try repository.annotations(for: reference1)

        #expect(results == [annotation1])
    }

    /// no matches returns [], not an error
    @Test func noMatchesReturnsEmpty() throws {
        let repository = InMemoryLibraryRepository()
        
        let reference1 = try #require(ScriptureReference(translationID: 123,
                                                         bookCode: "GEN",
                                                         chapter: 1,
                                                         startVerse: 16,
                                                         endVerse: nil))
        let verseRange1 = try #require(reference1.verseRange)

        let reference2 = try #require(ScriptureReference(translationID: 456,
                                                         bookCode: "GEN",
                                                         chapter: 1,
                                                         startVerse: 16,
                                                         endVerse: nil))
        
        let annotation1 = try #require(VerseAnnotation(reference: reference1,
                                                       selectedVerses: verseRange1,
                                                       content: .note("Note content")))

        try repository.save(annotation1)

        let results = try repository.annotations(for: reference2)

        #expect(results == [])
    }
}
