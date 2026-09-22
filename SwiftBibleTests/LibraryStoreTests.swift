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
    @Test func loadPassagesLoadsOnePassageForAnnotationsInSameChapter() async throws {
        let libraryRepository = InMemoryLibraryRepository()
        let passageRepository = LibraryPassageCountingRepository()
        let passageStore = BiblePassageStore(repository: passageRepository)
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
        await libraryStore.loadAllPassages()

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
        let passageStore = BiblePassageStore(repository: passageRepository)
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
        await libraryStore.loadAllPassages()

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
        let passageStore = BiblePassageStore(repository: passageRepository)
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
        await libraryStore.loadAllPassages()

        #expect(libraryStore.passage(for: firstAnnotation)?.passage == firstExpectedPassage)
        #expect(libraryStore.passage(for: secondAnnotation)?.passage == secondExpectedPassage)
    }

    /// Loading a single annotation's passage publishes it through `passage(for:)`
    @Test func loadPassageMakesPassageAvailableForAnnotation() async throws {
        let libraryRepository = InMemoryLibraryRepository()
        let passageRepository = LibraryPassageCountingRepository()
        let passageStore = BiblePassageStore(repository: passageRepository)
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

    /// A second annotation in an already-loaded chapter reuses the loaded passage
    @Test func loadPassageSkipsRequestForAlreadyLoadedChapter() async throws {
        let libraryRepository = InMemoryLibraryRepository()
        let passageRepository = LibraryPassageCountingRepository()
        let passageStore = BiblePassageStore(repository: passageRepository)
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
        #expect(libraryStore.loadedPassages.count == 1)
        #expect(libraryStore.passage(for: secondAnnotation)?.passage
                == libraryStore.passage(for: firstAnnotation)?.passage)
    }

    /// An already-loaded chapter does not block the remaining chapters from loading
    @Test func loadAllPassagesLoadsRemainingChaptersWhenOneIsAlreadyLoaded() async throws {
        let libraryRepository = InMemoryLibraryRepository()
        let passageRepository = LibraryPassageCountingRepository(
            passages: FakeBibleRepository.defaultPassages + [Self.secondChapterPassage]
        )
        let passageStore = BiblePassageStore(repository: passageRepository)
        let libraryStore = LibraryStore(libraryRepository: libraryRepository,
                                        passageStore: passageStore)
        let firstChapterAnnotation = makeAnnotation(translationID: 1234,
                                                    chapter: 1,
                                                    startVerse: 1,
                                                    content: .note("First chapter"))
        let secondChapterAnnotation = makeAnnotation(translationID: 1234,
                                                     chapter: 2,
                                                     startVerse: 1,
                                                     content: .note("Second chapter"))
        let firstChapterKey = BiblePassageKey(translationID: 1234,
                                              bookCode: "GEN",
                                              chapter: 1)
        let secondChapterKey = BiblePassageKey(translationID: 1234,
                                               bookCode: "GEN",
                                               chapter: 2)

        try libraryRepository.save(firstChapterAnnotation)
        try libraryRepository.save(secondChapterAnnotation)
        libraryStore.load()
        await libraryStore.loadPassage(for: firstChapterAnnotation)
        await libraryStore.loadAllPassages()

        // the pre-loaded chapter is requested once; the remaining chapter still loads
        #expect(passageRepository.passageRequestCount == 2)
        #expect(passageRepository.requestedKeys.filter { $0 == firstChapterKey }.count == 1)
        #expect(passageRepository.requestedKeys.contains(secondChapterKey))
        #expect(Set(libraryStore.loadedPassages.keys) == [firstChapterKey, secondChapterKey])
        #expect(libraryStore.passage(for: secondChapterAnnotation)?.passage
                == Self.secondChapterPassage.passage)
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
        content: AnnotationContent
    ) -> VerseAnnotation {
        VerseAnnotation(id: UUID(),
                        translationID: translationID,
                        bookCode: "GEN",
                        chapter: chapter,
                        startVerse: startVerse,
                        endVerse: nil,
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
