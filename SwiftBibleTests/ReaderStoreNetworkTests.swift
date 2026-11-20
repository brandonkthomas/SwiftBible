//
//  ReaderStoreNetworkTests.swift
//  SwiftBibleTests
//

import Foundation
import Testing
@testable import SwiftBible

/// Reader behavior when the connection drops or returns
///
/// Offline tests run only while `ArtificialNetworkConstraint.isNetworkRequired` is true, since
/// the fake repository itself never fails for lack of a network
@MainActor
struct ReaderStoreNetworkTests {

    /// A passage requested while offline shows the offline state, not a general failure
    @Test(.enabled(if: ArtificialNetworkConstraint.isNetworkRequired,
                   "Online-only passages are turned off"))
    func offlinePassageLoadShowsOffline() async {
        let networkStatus = FakeNetworkStatus()
        networkStatus.isOnline = false
        let store = readerStore(networkStatus: networkStatus)

        await store.loadTranslationsAndBooks(languageTag: "en")
        await store.loadSelectedPassage()

        #expect(store.loadState == .loaded)
        #expect(store.passageLoadState == .offline)
        #expect(store.selectedRenderedPassage == nil)
    }

    /// Reconnecting loads the passage that was offline (P1: Reader never recovered)
    @Test(.enabled(if: ArtificialNetworkConstraint.isNetworkRequired,
                   "Online-only passages are turned off"))
    func reconnectLoadsOfflinePassage() async {
        let networkStatus = FakeNetworkStatus()
        networkStatus.isOnline = false
        let store = readerStore(networkStatus: networkStatus)
        await store.loadTranslationsAndBooks(languageTag: "en")
        await store.loadSelectedPassage()

        networkStatus.isOnline = true
        await store.networkConnectionChanged(isConnected: true)

        #expect(store.passageLoadState == .loaded)
        #expect(store.selectedRenderedPassage != nil)
    }

    /// Losing the connection takes the shown passage off screen
    @Test(.enabled(if: ArtificialNetworkConstraint.isNetworkRequired,
                   "Online-only passages are turned off"))
    func connectionLossTakesPassageOffScreen() async {
        let networkStatus = FakeNetworkStatus()
        let store = readerStore(networkStatus: networkStatus)
        await store.loadTranslationsAndBooks(languageTag: "en")
        await store.loadSelectedPassage()
        store.selectedVerses = 1...1

        networkStatus.isOnline = false
        await store.networkConnectionChanged(isConnected: false)

        #expect(store.passageLoadState == .offline)
        #expect(store.selectedRenderedPassage == nil)
        #expect(store.selectedVerses == nil)
    }

    /// Reconnecting retries a failed books load, then loads the passage
    @Test func reconnectRetriesFailedCatalogLoad() async {
        let repository = FakeBibleRepository(throwWhenLoadingBooks: true)
        let store = readerStore(networkStatus: FakeNetworkStatus(), repository: repository)
        await store.loadTranslationsAndBooks(languageTag: "en")
        #expect(store.loadState == .failed("Unable to load books and chapters."))

        repository.throwWhenLoadingBooks = false
        await store.networkConnectionChanged(isConnected: true)

        #expect(store.loadState == .loaded)
        #expect(store.passageLoadState == .loaded)
    }

    /// Reconnecting does nothing to a passage that is already loaded
    @Test func reconnectLeavesLoadedPassageAlone() async {
        let store = readerStore(networkStatus: FakeNetworkStatus())
        await store.loadTranslationsAndBooks(languageTag: "en")
        await store.loadSelectedPassage()
        store.selectedVerses = 1...1

        await store.networkConnectionChanged(isConnected: true)

        #expect(store.passageLoadState == .loaded)
        #expect(store.selectedVerses == 1...1)
    }

    // MARK: Helpers

    private func readerStore(networkStatus: FakeNetworkStatus,
                             repository: FakeBibleRepository? = nil) -> ReaderStore {
        let repository = repository ?? FakeBibleRepository()
        let passageStore = BiblePassageStore(repository: repository,
                                             passageCache: InMemoryPassageCache(),
                                             networkStatus: networkStatus)
        return ReaderStore(passageStore: passageStore,
                           catalogStore: BibleCatalogStore(repository: repository),
                           preferencesStore: PreferencesStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
                           libraryRepository: InMemoryLibraryRepository())
    }
}
