//
//  LibraryStoreTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-09-16.
//

import Foundation
import Testing
@testable import SwiftBible

@MainActor
struct LibraryStoreTests {

    /// Multiple annotations in the same translation, book, and chapter cause one repository request
    @Test func loadPassageLoadsOnePassageForAnnotationsInSameChapter() async throws {
        let libraryRepository = InMemoryLibraryRepository()
        let passageRepository = LibraryPassageCountingRepository()
        let passageStore = BiblePassageStore(repository: passageRepository,
                                             passageCache: InMemoryPassageCache())
        let libraryStore = LibraryStore(libraryRepository: libraryRepository,
                                        passageStore: passageStore)
        let firstAnnotation = makeAnnotation(translationID: 1234,
                                             startVerse: 1,
                                             content: .note("First note"))
        let secondAnnotation = makeAnnotation(translationID: 1234,
                                              startVerse: 2,
                                              content: .tags(["Second tag"]))

        try libraryRepository.save(firstAnnotation)
        try libraryRepository.save(secondAnnotation)
        libraryStore.load()
        await libraryStore.loadPassage(for: firstAnnotation)
        await libraryStore.loadPassage(for: secondAnnotation)

        #expect(passageRepository.passageRequestCount == 1)
        #expect(passageRepository.requestedKeys == [
            BiblePassageKey(translationID: 1234,
                            bookCode: "GEN",
                            chapter: 1)
        ])
        #expect(libraryStore.loadedPassages.count == 1)
    }

    /// Annotations with different passage identities load independently
    @Test func loadPassagesLoadsDistinctTranslationChapterKeys() async throws {
        let libraryRepository = InMemoryLibraryRepository()
        let passageRepository = LibraryPassageCountingRepository()
        let passageStore = BiblePassageStore(repository: passageRepository,
                                             passageCache: InMemoryPassageCache())
        let libraryStore = LibraryStore(libraryRepository: libraryRepository,
                                        passageStore: passageStore)
        let firstTranslationAnnotation = makeAnnotation(translationID: 1234,
                                                        startVerse: 1,
                                                        content: .note("First translation"))
        let secondTranslationAnnotation = makeAnnotation(translationID: 1849,
                                                         startVerse: 1,
                                                         content: .note("Second translation"))

        try libraryRepository.save(firstTranslationAnnotation)
        try libraryRepository.save(secondTranslationAnnotation)
        libraryStore.load()
        await libraryStore.loadPassage(for: firstTranslationAnnotation)
        await libraryStore.loadPassage(for: secondTranslationAnnotation)

        // Set returns a random order every time
        let expectedKeys: Set<BiblePassageKey> = [
            BiblePassageKey(translationID: 1234,
                            bookCode: "GEN",
                            chapter: 1),
            BiblePassageKey(translationID: 1849,
                            bookCode: "GEN",
                            chapter: 1)
        ]

        #expect(passageRepository.passageRequestCount == 2)
        #expect(Set(passageRepository.requestedKeys) == expectedKeys)
        #expect(Set(libraryStore.loadedPassages.keys) == expectedKeys)
    }

    /// A loaded passage can be retrieved using its annotation
    @Test func loadedPassageResolvesUsingAnnotationIdentity() async throws {
        let libraryRepository = InMemoryLibraryRepository()
        let passageRepository = LibraryPassageCountingRepository()
        let passageStore = BiblePassageStore(repository: passageRepository,
                                             passageCache: InMemoryPassageCache())
        let libraryStore = LibraryStore(libraryRepository: libraryRepository,
                                        passageStore: passageStore)
        let firstAnnotation = makeAnnotation(translationID: 1234,
                                             startVerse: 1,
                                             content: .note("First translation"))
        let secondAnnotation = makeAnnotation(translationID: 1849,
                                              startVerse: 1,
                                              content: .note("Second translation"))
        let firstExpectedPassage = try #require(
            FakeBibleRepository.defaultPassages.first {
                $0.translationID == firstAnnotation.translationID
            }?.passage
        )
        let secondExpectedPassage = try #require(
            FakeBibleRepository.defaultPassages.first {
                $0.translationID == secondAnnotation.translationID
            }?.passage
        )

        try libraryRepository.save(firstAnnotation)
        try libraryRepository.save(secondAnnotation)
        libraryStore.load()
        await libraryStore.loadPassage(for: firstAnnotation)
        await libraryStore.loadPassage(for: secondAnnotation)

        #expect(libraryStore.passage(for: firstAnnotation)?.passage == firstExpectedPassage)
        #expect(libraryStore.passage(for: secondAnnotation)?.passage == secondExpectedPassage)
    }

    /// Loading a single annotation's passage publishes it through `passage(for:)`
    @Test func loadPassageMakesPassageAvailableForAnnotation() async throws {
        let libraryRepository = InMemoryLibraryRepository()
        let passageRepository = LibraryPassageCountingRepository()
        let passageStore = BiblePassageStore(repository: passageRepository,
                                             passageCache: InMemoryPassageCache())
        let libraryStore = LibraryStore(libraryRepository: libraryRepository,
                                        passageStore: passageStore)
        let annotation = makeAnnotation(translationID: 1234,
                                        startVerse: 1,
                                        content: .note("First note"))
        let expectedPassage = try #require(
            FakeBibleRepository.defaultPassages.first {
                $0.translationID == annotation.translationID
            }?.passage
        )

        try libraryRepository.save(annotation)
        libraryStore.load()
        await libraryStore.loadPassage(for: annotation)

        #expect(passageRepository.passageRequestCount == 1)
        #expect(passageRepository.requestedKeys == [
            BiblePassageKey(translationID: 1234,
                            bookCode: "GEN",
                            chapter: 1)
        ])
        #expect(libraryStore.passage(for: annotation)?.passage == expectedPassage)
    }

    /// delete(_:) reports success and removes the annotation from `annotations`
    @Test func deleteReportsSuccessAndRemovesAnnotation() throws {
        let libraryRepository = InMemoryLibraryRepository()
        let passageStore = BiblePassageStore(repository: LibraryPassageCountingRepository(),
                                             passageCache: InMemoryPassageCache())
        let libraryStore = LibraryStore(libraryRepository: libraryRepository,
                                        passageStore: passageStore)
        let deletedAnnotation = makeAnnotation(translationID: 1234,
                                               startVerse: 1,
                                               content: .highlight(.yellow))
        let keptAnnotation = makeAnnotation(translationID: 1234,
                                            startVerse: 2,
                                            content: .note("Kept note"))

        try libraryRepository.save(deletedAnnotation)
        try libraryRepository.save(keptAnnotation)
        libraryStore.load()
        #expect(libraryStore.annotations.count == 2)

        let didDelete = libraryStore.delete(deletedAnnotation.id)

        #expect(didDelete)
        #expect(!libraryStore.annotations.contains { $0.id == deletedAnnotation.id })
        #expect(libraryStore.annotations == [keptAnnotation])
    }

    /// annotationEditor(for:) builds an editor that loads the note and tags saved for the same verse range
    @Test func annotationEditorLoadsNoteAndTagsForSameVerseRange() throws {
        let libraryRepository = InMemoryLibraryRepository()
        let passageStore = BiblePassageStore(repository: LibraryPassageCountingRepository(),
                                             passageCache: InMemoryPassageCache())
        let libraryStore = LibraryStore(libraryRepository: libraryRepository,
                                        passageStore: passageStore)
        let noteAnnotation = makeAnnotation(translationID: 1234,
                                            startVerse: 1,
                                            endVerse: 3,
                                            content: .note("Range note"))
        let tagsAnnotation = makeAnnotation(translationID: 1234,
                                            startVerse: 1,
                                            endVerse: 3,
                                            content: .tags(["Creation", "Light"]))
        // Same chapter, different range; must not leak into the editor
        let otherRangeAnnotation = makeAnnotation(translationID: 1234,
                                                  startVerse: 4,
                                                  content: .note("Other range note"))

        try libraryRepository.save(noteAnnotation)
        try libraryRepository.save(tagsAnnotation)
        try libraryRepository.save(otherRangeAnnotation)
        libraryStore.load()

        let editor = try #require(libraryStore.annotationEditor(for: noteAnnotation))
        editor.load()

        #expect(editor.selectedVerses == 1...3)
        #expect(editor.noteText == "Range note")
        #expect(editor.tags == ["Creation", "Light"])
    }

    /// Genesis 2 is absent from the default fixtures; tests needing a second chapter add it
    private static let secondChapterPassage = FakeBibleRepository.PassageFixture(
        translationID: 1234,
        passage: Passage(id: "GEN.2",
                         reference: "Genesis 2",
                         htmlContent: """
                         <div>
                             <div class="p">
                                 <span class="yv-v" v="1"></span><span class="yv-vlbl">1</span>Thus the heavens and the earth were completed.
                             </div>
                         </div>
                         """)
    )

    private func makeAnnotation(
        translationID: Translation.ID,
        chapter: Int = 1,
        startVerse: Int,
        endVerse: Int? = nil,
        content: AnnotationContent
    ) -> VerseAnnotation {
        VerseAnnotation(id: UUID(),
                        translationID: translationID,
                        bookCode: "GEN",
                        chapter: chapter,
                        startVerse: startVerse,
                        endVerse: endVerse,
                        content: content,
                        createdAt: .now)
    }
}

@MainActor
private final class LibraryPassageCountingRepository: BibleRepository {
    private let repository: FakeBibleRepository

    private(set) var requestedKeys: [BiblePassageKey] = []

    init(passages: [FakeBibleRepository.PassageFixture]? = nil) {
        if let passages {
            repository = FakeBibleRepository(passages: passages)
        } else {
            repository = FakeBibleRepository()
        }
    }

    var passageRequestCount: Int {
        requestedKeys.count
    }

    func translations(languageTag: String?) async throws -> [Translation] {
        try await repository.translations(languageTag: languageTag)
    }

    func books(for translationID: Translation.ID) async throws -> [Book] {
        try await repository.books(for: translationID)
    }

    func passage(for reference: ScriptureReference) async throws -> Passage {
        requestedKeys.append(
            BiblePassageKey(translationID: reference.translationID,
                            bookCode: reference.bookCode,
                            chapter: reference.chapter)
        )
        return try await repository.passage(for: reference)
    }
}
