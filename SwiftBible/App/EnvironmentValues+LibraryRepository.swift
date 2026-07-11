//
//  EnvironmentValues+LibraryRepository.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-11.
//

import SwiftUI

private struct LibraryRepositoryKey: EnvironmentKey {
    static let defaultValue: LibraryRepository = InMemoryLibraryRepository()
}

extension EnvironmentValues {
    var libraryRepository: LibraryRepository {
        get { self[LibraryRepositoryKey.self] }
        set { self[LibraryRepositoryKey.self] = newValue }
    }
}
