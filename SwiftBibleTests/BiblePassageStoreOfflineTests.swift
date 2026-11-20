//
//  BiblePassageStoreOfflineTests.swift
//  SwiftBibleTests
//

import Testing
import Foundation
@testable import SwiftBible

/// Passages, cached or not, are only returned while the device is online
///
/// The two offline tests run only while `ArtificialNetworkConstraint.isNetworkRequired` is true;
/// the back-online test holds either way
@MainActor
struct BiblePassageStoreOfflineTests {

    private let key = BiblePassageKey(translationID: 1234, bookCode: "GEN", chapter: 1)

    /// A passage already in memory is not returned while offline
    @Test(.enabled(if: ArtificialNetworkConstraint.isNetworkRequired,
                   "Online-only passages are turned off"))
    func offlineRejectsPassageInMemory() async throws {
        let networkStatus = FakeNetworkStatus()
        let repository = OfflineTestBibleRepository()
        let store = BiblePassageStore(repository: repository,
                                      passageCache: InMemoryPassageCache(),
                                      networkStatus: networkStatus)
        _ = try await store.passage(for: key)

        networkStatus.isOnline = false

        await #expect(throws: BiblePassageStoreError.offline) {
            try await store.passage(for: key)
        }
        #expect(repository.passageRequestCount == 1)
    }

    /// A passage saved to disk on an earlier launch is not returned while offline
    @Test(.enabled(if: ArtificialNetworkConstraint.isNetworkRequired,
                   "Online-only passages are turned off"))
    func offlineRejectsPassageOnDisk() async throws {
        let networkStatus = FakeNetworkStatus()
        networkStatus.isOnline = false
        let repository = OfflineTestBibleRepository()
        let passageCache = InMemoryPassageCache()
        let savedPassage = try #require(
            FakeBibleRepository.defaultPassages.first { $0.translationID == key.translationID }?.passage
        )
        try await passageCache.save(savedPassage, for: key)
        let store = BiblePassageStore(repository: repository,
                                      passageCache: passageCache,
                                      networkStatus: networkStatus)

        await #expect(throws: BiblePassageStoreError.offline) {
            try await store.passage(for: key)
        }
        #expect(repository.passageRequestCount == 0)
    }

    /// Back online, the passage already in memory is returned without another request
    @Test func backOnlineReturnsPassageInMemoryWithoutRequest() async throws {
        let networkStatus = FakeNetworkStatus()
        let repository = OfflineTestBibleRepository()
        let store = BiblePassageStore(repository: repository,
                                      passageCache: InMemoryPassageCache(),
                                      networkStatus: networkStatus)
        _ = try await store.passage(for: key)

        networkStatus.isOnline = false
        _ = try? await store.passage(for: key)
        networkStatus.isOnline = true

        _ = try await store.passage(for: key)

        #expect(repository.passageRequestCount == 1)
    }
}

/// Counts passage requests so a test can show the network was not used
@MainActor
private final class OfflineTestBibleRepository: BibleRepository {
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
