//
//  BiblePassageStoreTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-09-13.
//

import Testing
import Foundation
@testable import SwiftBible

@MainActor
struct BiblePassageStoreTests {

    /// Fresh, empty directory for one test; caller deletes it when done
    private func makeTempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    }

    @Test func cacheMissFetchesParsesAndStores() async throws {
        let repository = PassageCountingBibleRepository()
        let store = BiblePassageStore(repository: repository,
                                      passageCache: InMemoryPassageCache())
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

    /// Each provider parses its own HTML, so the store must not pick a parser itself
    @Test func repositoryParsesTheFetchedPassage() async throws {
        let repository = CustomRenderingBibleRepository()
        let store = BiblePassageStore(repository: repository,
                                      passageCache: InMemoryPassageCache())
        let key = BiblePassageKey(translationID: 1234,
                                  bookCode: "GEN",
                                  chapter: 1)

        let loadedPassage = try await store.passage(for: key)

        #expect(repository.renderRequests == [key.translationID])
        #expect(loadedPassage.renderedPassage.paragraphs.first?.runs == CustomRenderingBibleRepository.runs)
    }

    // MARK: Memory-only policy (ESV terms)

    /// A .memoryOnly passage is neither read from nor written to the disk cache
    @Test func memoryOnlyPolicySkipsDiskCache() async throws {
        let repository = VerseLimitedBibleRepository(maximumVerseCount: 500, versesPerChapter: 3)
        let passageCache = InMemoryPassageCache()
        let seededKey = makeKey(chapter: 1)
        let seededPassage = Passage(id: "GEN.1", reference: "Genesis 1", htmlContent: "<p>seeded")
        try await passageCache.save(seededPassage, for: seededKey)

        let store = BiblePassageStore(repository: repository, passageCache: passageCache)

        _ = try await store.passage(for: seededKey)
        _ = try await store.passage(for: makeKey(chapter: 2))

        #expect(repository.passageRequests == [1, 2])
        #expect(try await passageCache.passage(for: seededKey) == seededPassage)
        #expect(try await passageCache.passage(for: makeKey(chapter: 2)) == nil)
    }

    /// Over the verse limit, the least recently used chapter is dropped and fetched again later
    @Test func memoryOnlyPolicyEvictsOldestChapterOverVerseLimit() async throws {
        let repository = VerseLimitedBibleRepository(maximumVerseCount: 5, versesPerChapter: 3)
        let store = BiblePassageStore(repository: repository, passageCache: InMemoryPassageCache())

        _ = try await store.passage(for: makeKey(chapter: 1))
        _ = try await store.passage(for: makeKey(chapter: 2)) // 6 verses > 5: drops chapter 1
        _ = try await store.passage(for: makeKey(chapter: 2)) // still cached
        _ = try await store.passage(for: makeKey(chapter: 1)) // fetched again

        #expect(repository.passageRequests == [1, 2, 1])
    }

    /// Reading a cached chapter makes it the most recently used, so another is dropped first
    @Test func memoryOnlyCacheHitRefreshesRecency() async throws {
        let repository = VerseLimitedBibleRepository(maximumVerseCount: 6, versesPerChapter: 3)
        let store = BiblePassageStore(repository: repository, passageCache: InMemoryPassageCache())

        _ = try await store.passage(for: makeKey(chapter: 1))
        _ = try await store.passage(for: makeKey(chapter: 2))
        _ = try await store.passage(for: makeKey(chapter: 1)) // hit: chapter 2 is now oldest
        _ = try await store.passage(for: makeKey(chapter: 3)) // 9 verses > 6: drops chapter 2
        _ = try await store.passage(for: makeKey(chapter: 1)) // still cached
        _ = try await store.passage(for: makeKey(chapter: 2)) // fetched again

        #expect(repository.passageRequests == [1, 2, 3, 2])
    }

    /// The limit applies per translation; an unlimited translation's chapters don't count
    @Test func memoryOnlyLimitIgnoresOtherTranslations() async throws {
        let repository = VerseLimitedBibleRepository(maximumVerseCount: 5,
                                                     versesPerChapter: 3,
                                                     limitedTranslationID: 59)
        let store = BiblePassageStore(repository: repository, passageCache: InMemoryPassageCache())

        _ = try await store.passage(for: makeKey(translationID: 1234, chapter: 1))
        _ = try await store.passage(for: makeKey(translationID: 59, chapter: 1))
        _ = try await store.passage(for: makeKey(translationID: 1234, chapter: 1)) // still cached
        _ = try await store.passage(for: makeKey(translationID: 59, chapter: 1)) // still cached

        #expect(repository.passageRequests == [1, 1])
    }

    // MARK: Disk-limited policy (ESV terms)

    /// A .diskLimited passage is saved to the cache, so a new store (next launch) reads it
    /// without another network request
    @Test func diskLimitedPolicySurvivesNewStore() async throws {
        let repository = VerseLimitedBibleRepository(maximumVerseCount: 500,
                                                     versesPerChapter: 3,
                                                     storesOnDisk: true)
        let passageCache = InMemoryPassageCache()

        _ = try await BiblePassageStore(repository: repository, passageCache: passageCache)
            .passage(for: makeKey(chapter: 1))
        _ = try await BiblePassageStore(repository: repository, passageCache: passageCache)
            .passage(for: makeKey(chapter: 1))

        #expect(repository.passageRequests == [1])
        #expect(try await passageCache.verseLimitEntries(for: 59)
                == [PassageCacheEntry(key: makeKey(chapter: 1), verseCount: 3)])
    }

    /// Over the verse limit, the least recently used chapter is removed from the cache too
    @Test func diskLimitedPolicyEvictsOldestChapterFromCache() async throws {
        let repository = VerseLimitedBibleRepository(maximumVerseCount: 5,
                                                     versesPerChapter: 3,
                                                     storesOnDisk: true)
        let passageCache = InMemoryPassageCache()
        let store = BiblePassageStore(repository: repository, passageCache: passageCache)

        _ = try await store.passage(for: makeKey(chapter: 1))
        _ = try await store.passage(for: makeKey(chapter: 2)) // 6 verses > 5: drops chapter 1

        #expect(try await passageCache.passage(for: makeKey(chapter: 1)) == nil)
        #expect(try await passageCache.passage(for: makeKey(chapter: 2)) != nil)
        #expect(try await passageCache.verseLimitEntries(for: 59)
                == [PassageCacheEntry(key: makeKey(chapter: 2), verseCount: 3)])

        _ = try await store.passage(for: makeKey(chapter: 1)) // fetched again
        #expect(repository.passageRequests == [1, 2, 1])
    }

    /// Reading a cached chapter makes it the most recently used across launches
    @Test func diskLimitedCacheHitRefreshesRecency() async throws {
        let repository = VerseLimitedBibleRepository(maximumVerseCount: 6,
                                                     versesPerChapter: 3,
                                                     storesOnDisk: true)
        let passageCache = InMemoryPassageCache()

        let firstLaunch = BiblePassageStore(repository: repository, passageCache: passageCache)
        _ = try await firstLaunch.passage(for: makeKey(chapter: 1))
        _ = try await firstLaunch.passage(for: makeKey(chapter: 2))

        let secondLaunch = BiblePassageStore(repository: repository, passageCache: passageCache)
        _ = try await secondLaunch.passage(for: makeKey(chapter: 1)) // disk hit: chapter 2 is now oldest
        _ = try await secondLaunch.passage(for: makeKey(chapter: 3)) // 9 verses > 6: drops chapter 2

        #expect(repository.passageRequests == [1, 2, 3])
        #expect(try await passageCache.passage(for: makeKey(chapter: 2)) == nil)
        #expect(try await passageCache.verseLimitEntries(for: 59).map(\.key)
                == [makeKey(chapter: 1), makeKey(chapter: 3)])
    }

    /// A passage cached without a list entry (e.g. under an earlier policy) is removed rather
    /// than left uncounted, and fetched again
    @Test func diskLimitedPolicyRemovesUnlistedPassages() async throws {
        let repository = VerseLimitedBibleRepository(maximumVerseCount: 500,
                                                     versesPerChapter: 3,
                                                     storesOnDisk: true)
        let passageCache = InMemoryPassageCache()
        let seededPassage = Passage(id: "GEN.1", reference: "Genesis 1", htmlContent: "<p>seeded")
        try await passageCache.save(seededPassage, for: makeKey(chapter: 1))

        let store = BiblePassageStore(repository: repository, passageCache: passageCache)
        _ = try await store.passage(for: makeKey(chapter: 1))

        #expect(repository.passageRequests == [1])
        #expect(try await passageCache.passage(for: makeKey(chapter: 1)) != seededPassage)
    }

    private func makeKey(translationID: Translation.ID = 59, chapter: Int) -> BiblePassageKey {
        BiblePassageKey(translationID: translationID, bookCode: "GEN", chapter: chapter)
    }

    @Test func cacheHitAvoidsAnotherRequest() async throws {
        let repository = PassageCountingBibleRepository()
        let store = BiblePassageStore(repository: repository,
                                      passageCache: InMemoryPassageCache())
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
        let store = BiblePassageStore(repository: repository,
                                      passageCache: InMemoryPassageCache())
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
        let store = BiblePassageStore(repository: repository,
                                      passageCache: InMemoryPassageCache())
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
        let store = BiblePassageStore(repository: repository,
                                      passageCache: InMemoryPassageCache())
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
        let store = BiblePassageStore(repository: repository,
                                      passageCache: InMemoryPassageCache())
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
        let store = BiblePassageStore(repository: repository,
                                      passageCache: InMemoryPassageCache())
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

    /// A cached passage the repository can no longer parse is fetched again and replaced
    @Test func unparseableCachedPassageIsFetchedAgain() async throws {
        let key = BiblePassageKey(translationID: 1234,
                                  bookCode: "GEN",
                                  chapter: 1)
        let expectedPassage = try #require(
            FakeBibleRepository.defaultPassages.first {
                $0.translationID == key.translationID
            }?.passage
        )

        let passageCache = InMemoryPassageCache()
        let stalePassage = Passage(id: expectedPassage.id,
                                   reference: expectedPassage.reference,
                                   htmlContent: "<p>unclosed")
        try await passageCache.save(stalePassage, for: key)

        let repository = PassageCountingBibleRepository()
        let store = BiblePassageStore(repository: repository,
                                      passageCache: passageCache)

        let loadedPassage = try await store.passage(for: key)

        #expect(loadedPassage.passage == expectedPassage)
        #expect(repository.passageRequestCount == 1)
        #expect(try await passageCache.passage(for: key) == expectedPassage)
    }

    @Test func diskCacheHitAvoidsNetworkRequest() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let key = BiblePassageKey(translationID: 1234,
                                  bookCode: "GEN",
                                  chapter: 1)
        let expectedPassage = try #require(
            FakeBibleRepository.defaultPassages.first {
                $0.translationID == key.translationID
            }?.passage
        )

        let diskCache = try DiskPassageCache(baseDirectory: tempDirectory)
        try await diskCache.save(expectedPassage, for: key)

        let repository = PassageCountingBibleRepository()
        let store = BiblePassageStore(repository: repository,
                                      passageCache: diskCache)

        let loadedPassage = try await store.passage(for: key)

        #expect(loadedPassage.passage == expectedPassage)
        #expect(repository.passageRequestCount == 0)
    }

    @Test func cacheMissFetchesAndSavesToDiskCache() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let diskCache = try DiskPassageCache(baseDirectory: tempDirectory)
        let repository = PassageCountingBibleRepository()
        let store = BiblePassageStore(repository: repository,
                                      passageCache: diskCache)
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
        #expect(repository.passageRequestCount == 1)
        #expect(try await diskCache.passage(for: key) == expectedPassage)
    }

    @Test func secondStoreSharingDiskCacheReadsFirstStoresWrite() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let sharedCache = try DiskPassageCache(baseDirectory: tempDirectory)
        let key = BiblePassageKey(translationID: 1234,
                                  bookCode: "GEN",
                                  chapter: 1)
        let expectedPassage = try #require(
            FakeBibleRepository.defaultPassages.first {
                $0.translationID == key.translationID
            }?.passage
        )

        let firstStore = BiblePassageStore(repository: PassageCountingBibleRepository(),
                                           passageCache: sharedCache)
        _ = try await firstStore.passage(for: key)

        // second store has its own repository so we can prove it never gets used
        let secondRepository = PassageCountingBibleRepository()
        let secondStore = BiblePassageStore(repository: secondRepository,
                                            passageCache: sharedCache)
        let secondResult = try await secondStore.passage(for: key)

        #expect(secondResult.passage == expectedPassage)
        #expect(secondRepository.passageRequestCount == 0)
    }

    @Test func failedFetchSavesNothingToDiskCache() async throws {
        let tempDirectory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let diskCache = try DiskPassageCache(baseDirectory: tempDirectory)
        let repository = ControllablePassageRepository()
        let store = BiblePassageStore(repository: repository,
                                      passageCache: diskCache)
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

        #expect(try await diskCache.passage(for: key) == nil)
    }

    @Test func saveFailureDoesNotFailTheRequest() async throws {
        let repository = PassageCountingBibleRepository()
        let store = BiblePassageStore(repository: repository,
                                      passageCache: ThrowingSavePassageCache())
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
        #expect(repository.passageRequestCount == 1)
    }
}

/// PassageCache whose save() always fails; used to prove that a failed cache write is
/// swallowed (BiblePassageStore only logs it) rather than failing the caller's request
private struct ThrowingSavePassageCache: PassageCache {
    enum SaveError: Error {
        case intentionalFailure
    }

    func passage(for key: BiblePassageKey) async throws -> Passage? {
        nil
    }

    func save(_ passage: Passage, for key: BiblePassageKey) async throws {
        throw SaveError.intentionalFailure
    }

    func removePassage(for key: BiblePassageKey) async throws {}

    func verseLimitEntries(for translationID: Translation.ID) async throws -> [PassageCacheEntry] {
        []
    }

    func saveVerseLimitEntries(_ entries: [PassageCacheEntry],
                               for translationID: Translation.ID) async throws {}
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

/// Returns fixed runs from renderedPassage, so a test can tell its parser was used
@MainActor
private final class CustomRenderingBibleRepository: BibleRepository {
    static let runs: [RenderedPassageRun] = [.text("Custom parser output", verseRange: nil)]

    private let repository = FakeBibleRepository()

    private(set) var renderRequests: [Translation.ID] = []

    func translations(languageTag: String?) async throws -> [Translation] {
        try await repository.translations(languageTag: languageTag)
    }

    func books(for translationID: Translation.ID) async throws -> [Book] {
        try await repository.books(for: translationID)
    }

    func passage(for reference: ScriptureReference) async throws -> Passage {
        try await repository.passage(for: reference)
    }

    func renderedPassage(from passage: Passage,
                         translationID: Translation.ID) throws -> RenderedPassage {
        renderRequests.append(translationID)
        return RenderedPassage(paragraphs: [RenderedParagraph(runs: Self.runs)],
                               footnotes: [])
    }
}

/// Applies .memoryOnly(maximumVerseCount:) (or .diskLimited when storesOnDisk) to one
/// translation and serves chapters of a fixed verse count in YouVersion markup; records the
/// chapter of every network request
@MainActor
private final class VerseLimitedBibleRepository: BibleRepository {
    private let maximumVerseCount: Int
    private let versesPerChapter: Int
    private let limitedTranslationID: Translation.ID
    private let storesOnDisk: Bool

    private(set) var passageRequests: [Int] = []

    init(maximumVerseCount: Int,
         versesPerChapter: Int,
         limitedTranslationID: Translation.ID = 59,
         storesOnDisk: Bool = false) {
        self.maximumVerseCount = maximumVerseCount
        self.versesPerChapter = versesPerChapter
        self.limitedTranslationID = limitedTranslationID
        self.storesOnDisk = storesOnDisk
    }

    func translations(languageTag: String?) async throws -> [Translation] {
        []
    }

    func books(for translationID: Translation.ID) async throws -> [Book] {
        []
    }

    func passage(for reference: ScriptureReference) async throws -> Passage {
        passageRequests.append(reference.chapter)

        let verses = (1...versesPerChapter).map { verse in
            #"<span class="yv-v" v="\#(verse)"></span><span class="yv-vlbl">\#(verse)</span>Verse text."#
        }

        return Passage(id: reference.passageID,
                       reference: "Genesis \(reference.chapter)",
                       htmlContent: #"<div class="p">\#(verses.joined())</div>"#)
    }

    func passageCachePolicy(for translationID: Translation.ID) -> PassageCachePolicy {
        guard translationID == limitedTranslationID else {
            return .unlimited
        }

        return storesOnDisk
            ? .diskLimited(maximumVerseCount: maximumVerseCount)
            : .memoryOnly(maximumVerseCount: maximumVerseCount)
    }
}
