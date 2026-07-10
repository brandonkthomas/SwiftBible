//
//  InMemoryLibraryRepository.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-09.
//

import Foundation

// Nonisolated for testing
nonisolated final class InMemoryLibraryRepository: LibraryRepository {

    private var annotations: [VerseAnnotation] = []

    func save(_ annotation: VerseAnnotation) throws {
        // validate...?
        self.annotations.append(annotation)
    }

    // TODO: add filter options to function params (i.e. optionally specify translation, etc)
    func annotations(for reference: ScriptureReference) throws -> [VerseAnnotation] {
//        guard reference.startVerse != nil else { // let startVerse =
//            throw LibraryRepositoryError.noResults
//        }

        return annotations.filter {
            $0.translationID == reference.translationID
            && $0.bookCode == reference.bookCode
            && $0.chapter == reference.chapter
//            && $0.startVerse == startVerse
//            && $0.endVerse == reference.endVerse
        }
    }
}
