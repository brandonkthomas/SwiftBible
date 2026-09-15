//
//  BiblePassageStoreTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-09-13.
//

import Testing
@testable import SwiftBible

@MainActor
struct BiblePassageStoreTests {

    @Test func cacheMissFetchesParsesAndStores() async throws {
        let repository = PassageCountingBibleRepository()
        let store = BiblePassageStore(repository: repository)
        let key = BiblePassageKey(translationID: 1234,
                                  bookCode: "GEN",
                                  chapter: 1)
        let expectedPassage = try #require(
            FakeBibleRepository.defaultPassages.first {
                $0.translationID == key.translationID
            }?.passage
        )

        let loadedPassage = try await store.passage(for: key)

        #expect(loadedPassage.passage == expectedPassage)
        #expect(loadedPassage.renderedPassage.paragraphs.count == 2)
        #expect(loadedPassage.renderedPassage.paragraphs[0].runs == [
            .verseLabel(displayText: "1",
                        verseRange: RenderedVerseRange(startVerse: 1)),
            .text("In the beginning God created the heavens and the earth.",
                  verseRange: RenderedVerseRange(startVerse: 1))
        ])
        #expect(try await store.passage(for: key).passage == expectedPassage)
        #expect(repository.passageRequestCount == 1)
    }

    @Test func cacheHitAvoidsAnotherRequest() async throws {
        let repository = PassageCountingBibleRepository()
        let store = BiblePassageStore(repository: repository)
        let key = BiblePassageKey(translationID: 1234,
                                  bookCode: "GEN",
                                  chapter: 1)
        let expectedPassage = try #require(
            FakeBibleRepository.defaultPassages.first {
                $0.translationID == key.translationID
            }?.passage
        )

        let firstResult = try await store.passage(for: key)
        let secondResult = try await store.passage(for: key)

        #expect(firstResult.passage == expectedPassage)
        #expect(secondResult.passage == expectedPassage)
        #expect(repository.passageRequestCount == 1)
    }

    @Test func translationIdentityIsolatesCacheEntries() async throws {
        let repository = PassageCountingBibleRepository()
        let store = BiblePassageStore(repository: repository)
        let firstKey = BiblePassageKey(translationID: 1234,
                                       bookCode: "GEN",
                                       chapter: 1)
        let secondKey = BiblePassageKey(translationID: 1849,
                                        bookCode: "GEN",
                                        chapter: 1)
        let firstExpectedPassage = try #require(
            FakeBibleRepository.defaultPassages.first {
                $0.translationID == firstKey.translationID
            }?.passage
        )
        let secondExpectedPassage = try #require(
            FakeBibleRepository.defaultPassages.first {
                $0.translationID == secondKey.translationID
            }?.passage
        )

        _ = try await store.passage(for: firstKey)
        _ = try await store.passage(for: secondKey)

        #expect(try await store.passage(for: firstKey).passage == firstExpectedPassage)
        #expect(try await store.passage(for: secondKey).passage == secondExpectedPassage)
        #expect(repository.passageRequestCount == 2)
    }

    @Test func invalidChapterKeyThrowsWithoutFetching() async {
        let repository = PassageCountingBibleRepository()
        let store = BiblePassageStore(repository: repository)
        let invalidKey = BiblePassageKey(translationID: 1234,
                                         bookCode: "GEN",
                                         chapter: 0)

        await #expect(throws: BiblePassageStoreError.self) {
            try await store.passage(for: invalidKey)
        }
        #expect(repository.passageRequestCount == 0)
    }
}

@MainActor
private final class PassageCountingBibleRepository: BibleRepository {
    private let repository = FakeBibleRepository()

    private(set) var passageRequestCount = 0

    func translations(languageTag: String?) async throws -> [Translation] {
        try await repository.translations(languageTag: languageTag)
    }

    func books(for translationID: Translation.ID) async throws -> [Book] {
        try await repository.books(for: translationID)
    }

    func passage(for reference: ScriptureReference) async throws -> Passage {
        passageRequestCount += 1
        return try await repository.passage(for: reference)
    }
}
