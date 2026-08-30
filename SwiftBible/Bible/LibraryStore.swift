//
//  LibraryStore.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-19.
//

import Foundation
import OSLog

/// Observable feature state for Saved/Library interface
///
/// Flow: LibraryRepository -> LibraryStore -> LibraryView
///
/// The repository owns persistence operations. Here we convert those operations
/// into view-facing state and apply user's in-memory Library filter
@Observable
final class LibraryStore {

    // MARK: Properties

    /// Active user-selected filter
    /// Mutating it automatically changes `filteredAnnotations` for observing views
    var filter = LibraryFilter()

    /// view-facing projection of `annotations`; the stored collection remains
    /// unchanged when the user changes a filter
    var filteredAnnotations: [VerseAnnotation] {
        annotations.filter(filter.matches)
    }

    // MARK: Properties (Private)

    /// Persistence boundary for loading and mutating app-owned annotations
    private let libraryRepository: any LibraryRepository

    /// Last successfully loaded annotation snapshots
    /// External consumers may read this collection but only the store replaces it
    private(set) var annotations: [VerseAnnotation] = []

    /// OS Logging
    private static let logger = Logger(subsystem: "SwiftBible", category: "LibraryStore")

    // MARK: Init

    /// Creates Library feature state backed by the supplied persistence implementation
    init(libraryRepository: LibraryRepository) {
        self.libraryRepository = libraryRepository
    }

    // MARK: Load

    /// Refreshes the view-facing annotation collection from persistence
    ///
    /// Assignment occurs only after the repository call succeeds, so a failed refresh
    /// preserves the last successfully loaded collection
    func load() {
        do {
            annotations = try libraryRepository.allAnnotations()
        } catch {
            Self.logger.error("Unable to load annotations: \(error.localizedDescription)")
        }
    }
}
