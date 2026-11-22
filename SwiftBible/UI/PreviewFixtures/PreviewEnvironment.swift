//
//  PreviewEnvironment.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-10-29.
//

import SwiftUI

/// Preview-only composition root: mirrors AppEnvironment's store graph using fakes,
/// so any view subtree can be previewed with the same environment SwiftBibleApp injects.
struct PreviewEnvironment {

    // MARK: Properties

    let readerStore: ReaderStore
    let passageStore: BiblePassageStore
    let catalogStore: BibleCatalogStore
    let libraryStore: LibraryStore
    let searchStore: SearchStore
    let preferencesStore: PreferencesStore
    let libraryRepository: LibraryRepository

    /// Not started; reports online so previews never show offline state
    let networkMonitor: NetworkMonitor

    // MARK: Init

    init(repository: FakeBibleRepository = FakeBibleRepository(),
         libraryRepository: LibraryRepository = InMemoryLibraryRepository()) {
        self.libraryRepository = libraryRepository
        self.networkMonitor = NetworkMonitor()
        self.networkMonitor.record(isConnected: true)
        self.passageStore = BiblePassageStore(repository: repository,
                                              passageCache: InMemoryPassageCache(),
                                              networkStatus: AlwaysOnlineNetworkStatus())
        self.catalogStore = BibleCatalogStore(repository: repository)
        self.preferencesStore = PreferencesStore(userDefaults: .standard)
        self.readerStore = ReaderStore(passageStore: passageStore,
                                       catalogStore: catalogStore,
                                       preferencesStore: preferencesStore,
                                       libraryRepository: libraryRepository)
        self.libraryStore = LibraryStore(libraryRepository: libraryRepository,
                                         catalogStore: catalogStore,
                                         passageStore: passageStore)
        self.searchStore = SearchStore(repository: repository,
                                       libraryStore: libraryStore,
                                       bibleCatalogStore: catalogStore,
                                       biblePassageStore: passageStore)
    }
}

extension View {
    /// Injects every environment value SwiftBibleApp injects (keep in sync with SwiftBibleApp)
    func previewEnvironment(_ environment: PreviewEnvironment = PreviewEnvironment()) -> some View {
        self
            .environment(environment.readerStore)
            .environment(environment.catalogStore)
            .environment(environment.libraryStore)
            .environment(environment.searchStore)
            .environment(environment.preferencesStore)
            .environment(environment.networkMonitor)
            .environment(\.libraryRepository, environment.libraryRepository)
    }
}
