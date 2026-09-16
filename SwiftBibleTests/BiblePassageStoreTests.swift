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

    @Test func simultaneousRequestsForSameKeyShareOneRepositoryRequest() async throws {
        let repository = ControllablePassageRepository()
        let store = BiblePassageStore(repository: repository)
        let key = BiblePassageKey(translationID: 1234,
                                  bookCode: "GEN",
                                  chapter: 1)

        let firstRequest = Task {
            try await store.passage(for: key)
        }
        await repository.waitForPassageRequestCount(1)

        let secondRequest = Task {
            try await store.passage(for: key)
        }
        await Task.yield()

        #expect(repository.passageRequestCount == 1)

        try repository.succeedPassageRequest(for: key)

        let firstResult = try await firstRequest.value
        let secondResult = try await secondRequest.value

        #expect(firstResult.passage == secondResult.passage)
        #expect(repository.passageRequestCount == 1)
    }

    @Test func simultaneousRequestsForDifferentKeysRemainIndependent() async throws {
        let repository = ControllablePassageRepository()
        let store = BiblePassageStore(repository: repository)
        let firstKey = BiblePassageKey(translationID: 1234,
                                       bookCode: "GEN",
                                       chapter: 1)
        let secondKey = BiblePassageKey(translationID: 1849,
                                        bookCode: "GEN",
                                        chapter: 1)

        let firstRequest = Task {
            try await store.passage(for: firstKey)
        }
        let secondRequest = Task {
            try await store.passage(for: secondKey)
        }

        await repository.waitForPassageRequestCount(2)
        #expect(repository.passageRequestCount == 2)

        try repository.succeedPassageRequest(for: firstKey)
        try repository.succeedPassageRequest(for: secondKey)

        let firstResult = try await firstRequest.value
        let secondResult = try await secondRequest.value

        #expect(firstResult.passage != secondResult.passage)
        #expect(repository.passageRequestCount == 2)
    }

    @Test func failedRequestIsRemovedAndCanBeRetried() async throws {
        let repository = ControllablePassageRepository()
        let store = BiblePassageStore(repository: repository)
        let key = BiblePassageKey(translationID: 1234,
                                  bookCode: "GEN",
                                  chapter: 1)

        let failedRequest = Task {
            try await store.passage(for: key)
        }
        await repository.waitForPassageRequestCount(1)
        try repository.failPassageRequest(for: key)

        await #expect(throws: ControllablePassageRepository.RepositoryError.intentionalFailure) {
            try await failedRequest.value
        }

        let retryRequest = Task {
            try await store.passage(for: key)
        }
        await repository.waitForPassageRequestCount(2)
        try repository.succeedPassageRequest(for: key)

        let retriedResult = try await retryRequest.value
        let expectedPassage = try #require(
            FakeBibleRepository.defaultPassages.first {
                $0.translationID == key.translationID
            }?.passage
        )

        #expect(retriedResult.passage == expectedPassage)
        #expect(repository.passageRequestCount == 2)
    }
}

@MainActor
private final class ControllablePassageRepository: BibleRepository {
    enum RepositoryError: Error, Equatable {
        case intentionalFailure
        case missingPendingRequest
        case missingFixture
    }

    private struct RequestCountWaiter {
        let expectedCount: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private var pendingPassageRequests:
        [BiblePassageKey: [CheckedContinuation<Passage, Error>]] = [:]
    private var requestCountWaiters: [RequestCountWaiter] = []

    private(set) var passageRequestCount = 0

    func translations(languageTag: String?) async throws -> [Translation] {
        []
    }

    func books(for translationID: Translation.ID) async throws -> [Book] {
        []
    }

    func passage(for reference: ScriptureReference) async throws -> Passage {
        let key = BiblePassageKey(translationID: reference.translationID,
                                  bookCode: reference.bookCode,
                                  chapter: reference.chapter)

        passageRequestCount += 1
        resumeSatisfiedRequestCountWaiters()

        return try await withCheckedThrowingContinuation { continuation in
            pendingPassageRequests[key, default: []].append(continuation)
        }
    }

    func waitForPassageRequestCount(_ expectedCount: Int) async {
        guard passageRequestCount < expectedCount else {
            return
        }

        await withCheckedContinuation { continuation in
            requestCountWaiters.append(
                RequestCountWaiter(expectedCount: expectedCount,
                                   continuation: continuation)
            )
        }
    }

    func succeedPassageRequest(for key: BiblePassageKey) throws {
        let continuation = try removePendingPassageRequest(for: key)
        guard let passage = FakeBibleRepository.defaultPassages.first(where: {
            $0.translationID == key.translationID &&
            $0.passage.id == "\(key.bookCode).\(key.chapter)"
        })?.passage else {
            continuation.resume(throwing: RepositoryError.missingFixture)
            throw RepositoryError.missingFixture
        }

        continuation.resume(returning: passage)
    }

    func failPassageRequest(for key: BiblePassageKey) throws {
        let continuation = try removePendingPassageRequest(for: key)
        continuation.resume(throwing: RepositoryError.intentionalFailure)
    }

    private func removePendingPassageRequest(
        for key: BiblePassageKey
    ) throws -> CheckedContinuation<Passage, Error> {
        guard var continuations = pendingPassageRequests[key],
              !continuations.isEmpty else {
            throw RepositoryError.missingPendingRequest
        }

        let continuation = continuations.removeFirst()
        pendingPassageRequests[key] = continuations.isEmpty ? nil : continuations
        return continuation
    }

    private func resumeSatisfiedRequestCountWaiters() {
        let satisfiedWaiters = requestCountWaiters.filter {
            passageRequestCount >= $0.expectedCount
        }
        requestCountWaiters.removeAll {
            passageRequestCount >= $0.expectedCount
        }

        for waiter in satisfiedWaiters {
            waiter.continuation.resume()
        }
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
