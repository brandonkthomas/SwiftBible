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
        // upsert
        self.annotations.removeAll { $0.id == annotation.id }
        self.annotations.append(annotation)
    }

    func annotations(for reference: ScriptureReference) throws -> [VerseAnnotation] {
        return annotations.filter {
            $0.translationID == reference.translationID
            && $0.bookCode == reference.bookCode
            && $0.chapter == reference.chapter
        }
    }
    
    func delete(_ id: UUID) throws {
        annotations.removeAll { $0.id == id }
    }
}
