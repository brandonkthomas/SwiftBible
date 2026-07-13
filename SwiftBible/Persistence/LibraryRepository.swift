//
//  LibraryRepository.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-09.
//

import Foundation

/// Protocol for user preference storage
///
/// For UI injection, see: LibraryRepositoryKey
protocol LibraryRepository {
    /// Create a new highlight/tag/note
    func save(_ annotation: VerseAnnotation) throws

    /// Retrieve all highlights/tags/notes for a given ScriptureReference
    ///
    /// TODO: add filter options (i.e. optionally specify translation, etc)
    func annotations(for reference: ScriptureReference) throws -> [VerseAnnotation]
    
    /// Delete a highlight/tag/note
    func delete(_ id: UUID) throws
}

enum LibraryRepositoryError: Error {
    case badFilters
    case internalError(String)
}
