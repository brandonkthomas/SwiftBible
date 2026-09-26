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

    /// Authority for all cached/loaded Passages
    ///
    /// Also contains BibleRepository API (Bible passage) command implementations
    private let passageStore: BiblePassageStore

    /// Last successfully loaded annotation snapshots
    /// External consumers may read this collection but only the store replaces it
    private(set) var annotations: [VerseAnnotation] = []

    /// Annotations are verse-scoped BUT cache is chapter-scoped; allow N annotations in
    /// LibraryStore to produce 1 passage request
    private(set) var loadedPassages: [BiblePassageKey: LoadedBiblePassage] = [:]

    /// OS Logging
    private static let logger = Logger(subsystem: "SwiftBible", category: "LibraryStore")

    // MARK: Init

    /// Creates Library feature state backed by the supplied persistence implementation
    init(libraryRepository: LibraryRepository,
         passageStore: BiblePassageStore) {
        self.libraryRepository = libraryRepository
        self.passageStore = passageStore
    }

    // MARK: Functions (Public + Load)

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

    /// Load a specific annotation's passage
    func loadPassage(for annotation: VerseAnnotation) async {
        // dont need (for:) here since "self" is implied
        let biblePassageKey = passageKey(for: annotation)

        // no need to load again if already done
        // Assigning here notifies every @Observing view even if value is unchanged;
        //   therefore we need this check to ensure that the whole list doesnt re-eval for
        //   every row refresh
        if loadedPassages[biblePassageKey] != nil {
            return
        }

        do {
            let loadedPassage = try await passageStore.passage(for: biblePassageKey)
            loadedPassages[biblePassageKey] = loadedPassage
        } catch {
            // do not remove existing entries on failure; just log
            Self.logger.error("Unable to load passage: \(error.localizedDescription)")
        }
    }

    /// Map VerseAnnotation -> LoadedBiblePassage (if available)
    func passage(for annotation: VerseAnnotation) -> LoadedBiblePassage? {
        if let loadedPassage = loadedPassages[passageKey(for: annotation)] {
            return loadedPassage
        }
        return nil
    }

    /// Request deletion of an annotation
    func delete(_ id: VerseAnnotation.ID) -> Bool {
        do {
            try libraryRepository.delete(id)
            load()
            return true
        } catch {
            Self.logger.error("Unable to delete annotation: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: Functions (Private)

    /// Map VerseAnnotation -> BiblePassageKey
    private func passageKey(for annotation: VerseAnnotation) -> BiblePassageKey {
        return BiblePassageKey(translationID: annotation.translationID,
                               bookCode: annotation.bookCode,
                               chapter: annotation.chapter)
    }
}
