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
    let preferencesStore: PreferencesStore
    let libraryRepository: LibraryRepository

    // MARK: Init

    init(repository: FakeBibleRepository = FakeBibleRepository(),
         libraryRepository: LibraryRepository = InMemoryLibraryRepository()) {
        self.libraryRepository = libraryRepository
        self.passageStore = BiblePassageStore(repository: repository,
                                              passageCache: InMemoryPassageCache())
        self.catalogStore = BibleCatalogStore(repository: repository)
        self.preferencesStore = PreferencesStore(userDefaults: .standard)
        self.readerStore = ReaderStore(passageStore: passageStore,
                                       catalogStore: catalogStore,
                                       preferencesStore: preferencesStore,
                                       libraryRepository: libraryRepository)
        self.libraryStore = LibraryStore(libraryRepository: libraryRepository,
                                         catalogStore: catalogStore,
                                         passageStore: passageStore)
    }
}

extension View {
    /// Injects every environment value SwiftBibleApp injects (keep in sync with SwiftBibleApp)
    func previewEnvironment(_ environment: PreviewEnvironment = PreviewEnvironment()) -> some View {
        self
            .environment(environment.readerStore)
            .environment(environment.catalogStore)
            .environment(environment.libraryStore)
            .environment(environment.preferencesStore)
            .environment(\.libraryRepository, environment.libraryRepository)
    }
}
