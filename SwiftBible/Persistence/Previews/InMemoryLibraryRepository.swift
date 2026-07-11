//
//  InMemoryLibraryRepository.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-09.
//

import Foundation

// Nonisolated for testing
@Observable
nonisolated final class InMemoryLibraryRepository: LibraryRepository {

    private var annotations: [VerseAnnotation] = []

    func save(_ annotation: VerseAnnotation) throws {
        self.annotations.append(annotation)
    }

    // TODO: add filter options to function params (i.e. optionally specify translation, etc)
    func annotations(for reference: ScriptureReference) throws -> [VerseAnnotation] {
        return annotations.filter {
            $0.translationID == reference.translationID
            && $0.bookCode == reference.bookCode
            && $0.chapter == reference.chapter
        }
    }
}
