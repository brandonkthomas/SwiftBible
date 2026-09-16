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
        await libraryStore.loadPassages()

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
        await libraryStore.loadPassages()

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
        await libraryStore.loadPassages()

        #expect(libraryStore.passage(for: firstAnnotation)?.passage == firstExpectedPassage)
        #expect(libraryStore.passage(for: secondAnnotation)?.passage == secondExpectedPassage)
    }

    private func makeAnnotation(
        translationID: Translation.ID,
        startVerse: Int,
        content: AnnotationContent
    ) -> VerseAnnotation {
        VerseAnnotation(id: UUID(),
                        translationID: translationID,
                        bookCode: "GEN",
                        chapter: 1,
                        startVerse: startVerse,
                        endVerse: nil,
                        content: content,
                        createdAt: .now)
    }
}

@MainActor
private final class LibraryPassageCountingRepository: BibleRepository {
    private let repository = FakeBibleRepository()

    private(set) var requestedKeys: [BiblePassageKey] = []

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
