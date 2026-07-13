//
//  EnvironmentValues+LibraryRepository.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-11.
//

import SwiftUI

private struct LibraryRepositoryKey: EnvironmentKey {
    /// This default exists so that \@Environment(\.libraryRepository) can be non-optional;
    /// canvas previews / test subtrees where nobody set the above env value benefit from this
    static let defaultValue: LibraryRepository = InMemoryLibraryRepository()
}

extension EnvironmentValues {
    var libraryRepository: LibraryRepository {
        get { self[LibraryRepositoryKey.self] }
        set { self[LibraryRepositoryKey.self] = newValue }
    }
}
