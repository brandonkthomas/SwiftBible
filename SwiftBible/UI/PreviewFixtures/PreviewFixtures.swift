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
                                             content: .highlight(.yellow),
                                             createdAt: .now))
        return repository
    }

    /// A sample annotation of the given content kind, for previews (Genesis 1:1–3, NIV 1234).
    static func sampleAnnotation(content: AnnotationContent) -> VerseAnnotation {
        VerseAnnotation(id: UUID(),
                        translationID: 1234,
                        bookCode: "GEN",
                        chapter: 1,
                        startVerse: 1,
                        endVerse: 3,
                        content: content,
                        createdAt: .now)
    }

    /// Ready-made samples, one per `AnnotationContent` case.
    static let sampleHighlightAnnotation = sampleAnnotation(content: .highlight(.yellow))
    static let sampleNoteAnnotation = sampleAnnotation(content: .note("Remember this passage about creation. This is a very long message and helps with testing paragraph layout."))
    static let sampleTagsAnnotation = sampleAnnotation(content: .tags(["faith", "creation"]))
}
