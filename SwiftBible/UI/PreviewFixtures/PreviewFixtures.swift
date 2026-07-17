//
//  PreviewFixtures.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-14.
//

import Foundation

/// Shared fixtures for Xcode canvas previews.
enum PreviewFixtures {

    /// An in-memory library seeded with one highlight matching the first reference
    /// `FakeBibleRepository`'s defaults select (NIV 1234, Genesis 1) on verse 1, so
    /// previews that load that passage render a highlight through the real load path.
    static func seededLibraryRepository() -> InMemoryLibraryRepository {
        let repository = InMemoryLibraryRepository()
        try? repository.save(VerseAnnotation(id: UUID(),
                                             translationID: 1234,
                                             bookCode: "GEN",
                                             chapter: 1,
                                             startVerse: 1,
                                             endVerse: nil,
                                             highlightColor: .yellow,
                                             createdAt: .now))
        return repository
    }
}
