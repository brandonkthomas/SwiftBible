//
//  LibraryStoreNetworkTests.swift
//  SwiftBibleTests
//

import Foundation
import Testing
@testable import SwiftBible

/// Library card passages when the connection drops or returns
///
/// Offline tests run only while `ArtificialNetworkConstraint.isNetworkRequired` is true, since
/// the fake repository itself never fails for lack of a network
@MainActor
struct LibraryStoreNetworkTests {

    private let annotation = VerseAnnotation(id: UUID(),
                                             translationID: 1234,
                                             bookCode: "GEN",
                                             chapter: 1,
                                             startVerse: 1,
                                             endVerse: nil,
                                             content: .note("Note"),
                                             createdAt: .now)

    /// An offline load records why, so the card shows a message instead of spinning (P1)
    @Test(.enabled(if: ArtificialNetworkConstraint.isNetworkRequired,
                   "Online-only passages are turned off"))
    func offlineLoadRecordsOfflineFailure() async {
        let networkStatus = FakeNetworkStatus()
        networkStatus.isOnline = false
        let store = libraryStore(networkStatus: networkStatus)

        await store.loadPassage(for: annotation)

        #expect(store.passage(for: annotation) == nil)
        #expect(store.passageLoadFailure(for: annotation) == .offline)
    }

    /// Reconnecting reloads cards whose passage failed, with no tab switch needed (P1)
    @Test(.enabled(if: ArtificialNetworkConstraint.isNetworkRequired,
                   "Online-only passages are turned off"))
    func reconnectReloadsFailedPassage() async {
        let networkStatus = FakeNetworkStatus()
        networkStatus.isOnline = false
        let store = libraryStore(networkStatus: networkStatus)
        await store.loadPassage(for: annotation)

        networkStatus.isOnline = true
        await store.networkConnectionChanged(isConnected: true)

        #expect(store.passage(for: annotation) != nil)
        #expect(store.passageLoadFailure(for: annotation) == nil)
    }

    /// Losing the connection takes loaded passages off the cards
    @Test(.enabled(if: ArtificialNetworkConstraint.isNetworkRequired,
                   "Online-only passages are turned off"))
    func connectionLossTakesPassagesOffScreen() async {
        let networkStatus = FakeNetworkStatus()
        let store = libraryStore(networkStatus: networkStatus)
        await store.loadPassage(for: annotation)
        #expect(store.passage(for: annotation) != nil)

        networkStatus.isOnline = false
        await store.networkConnectionChanged(isConnected: false)

        #expect(store.passage(for: annotation) == nil)
        #expect(store.passageLoadFailure(for: annotation) == .offline)
    }

    /// A non-network failure is reported as a failure, not as offline
    @Test func failedLoadRecordsFailure() async {
        let store = libraryStore(networkStatus: FakeNetworkStatus(),
                                 repository: FakeBibleRepository(passages: []))

        await store.loadPassage(for: annotation)

        #expect(store.passageLoadFailure(for: annotation) == .failed)
    }

    // MARK: Helpers

    private func libraryStore(networkStatus: FakeNetworkStatus,
                              repository: FakeBibleRepository? = nil) -> LibraryStore {
        let repository = repository ?? FakeBibleRepository()
        return LibraryStore(libraryRepository: InMemoryLibraryRepository(),
                     catalogStore: BibleCatalogStore(repository: repository),
                     passageStore: BiblePassageStore(repository: repository,
                                                     passageCache: InMemoryPassageCache(),
                                                     networkStatus: networkStatus))
    }
}
