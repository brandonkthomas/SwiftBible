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

    /// Active user-selected filter preferences.
    /// Mutating it automatically changes `filteredAnnotations` for observing views
    var filter = LibraryFilter()

    /// Active user-selected sorting + grouping preferences.
    /// Mutating it automatically changes `filteredAnnotations` for observing views
    var order = LibraryOrder()

    // MARK: Properties (Computed)

    /// view-facing projection of `annotations`; the stored collection remains.
    /// unchanged when the user changes a filter
    var filteredAndSortedAnnotations: [VerseAnnotation] {
        let filtered = annotations.filter(filter.matches)
        return order.sorted(
            annotations: filtered,
            bookPosition: { annotation in
                BibleCatalogStore.bookPosition(for: annotation.bookCode)
            }
        )
    }

    /// Collection of grouped annotations; filters & sorts are also applied
    var filteredSortedGroupedAnnotations: [LibraryOrderGroup] {
        order.grouped(
            annotations: filteredAndSortedAnnotations,
            bookPosition: { annotation in
                BibleCatalogStore.bookPosition(for: annotation.bookCode)
            },
            bookName: { annotation in
                bibleCatalogStore.book(for: annotation.translationID,
                                  bookCode: annotation.bookCode)?.displayName
            },
            translationAbbreviation: { translationID in
                bibleCatalogStore.translation(for: translationID)?.abbreviation
            }
        )
    }

    /// All unique tags across all annotations
    var allTags: Set<String> {
        Set(annotations.flatMap(\.tagNames))
    }

    // MARK: Properties (Private)

    /// Persistence boundary for loading and mutating app-owned annotations
    private let libraryRepository: any LibraryRepository

    /// Authority for all available Translations / Books
    private let bibleCatalogStore: BibleCatalogStore

    /// Authority for all cached/loaded Passages
    ///
    /// Also contains BibleRepository API (Bible passage) command implementations
    private let passageStore: BiblePassageStore

    /// Last successfully loaded annotation snapshots.
    /// External consumers may read this collection but only the store replaces it
    private(set) var annotations: [VerseAnnotation] = []

    /// Annotations are verse-scoped BUT cache is chapter-scoped; allow N annotations in.
    /// LibraryStore to produce 1 passage request
    private(set) var loadedPassages: [BiblePassageKey: LoadedBiblePassage] = [:]

    /// Chapters whose last load failed; their cards show why instead of a loading spinner,
    /// and networkConnectionChanged(isConnected: true) retries them
    private(set) var passageLoadFailures: [BiblePassageKey: LibraryPassageLoadFailure] = [:]

    /// OS Logging
    private static let logger = Logger(subsystem: "SwiftBible", category: "LibraryStore")

    // MARK: Init

    /// Creates Library feature state backed by the supplied persistence implementation
    init(libraryRepository: LibraryRepository,
         catalogStore: BibleCatalogStore,
         passageStore: BiblePassageStore) {
        self.libraryRepository = libraryRepository
        self.bibleCatalogStore = catalogStore
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
        await loadPassage(for: passageKey(for: annotation))
    }

    /// Load one chapter, recording a failure for its cards if it can't be loaded
    private func loadPassage(for biblePassageKey: BiblePassageKey) async {
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

            // only write when needed: every write notifies all observing cards
            if passageLoadFailures[biblePassageKey] != nil {
                passageLoadFailures[biblePassageKey] = nil
            }
        } catch {
            // do not remove existing entries on failure; record why so the card stops spinning
            Self.logger.error("Unable to load passage: \(error.localizedDescription)")
            passageLoadFailures[biblePassageKey] = error.isOfflineError ? .offline : .failed
        }
    }

    /// Called by ContentView whenever NetworkMonitor reports a new reading
    ///
    /// - Connected: retry every chapter whose load failed
    /// - Disconnected: when passages are online only, take loaded passages off screen
    func networkConnectionChanged(isConnected: Bool) async {
        guard isConnected else {
            guard ArtificialNetworkConstraint.isNetworkRequired,
                  !loadedPassages.isEmpty else {
                return
            }

            for key in loadedPassages.keys {
                passageLoadFailures[key] = .offline
            }
            loadedPassages = [:]
            return
        }

        let failedKeys = Array(passageLoadFailures.keys)

        guard !failedKeys.isEmpty else {
            return
        }

        passageLoadFailures = [:]

        await withDiscardingTaskGroup { group in
            for key in failedKeys {
                group.addTask {
                    await self.loadPassage(for: key)
                }
            }
        }
    }

    /// Why an annotation's chapter could not be loaded, if its last load failed
    func passageLoadFailure(for annotation: VerseAnnotation) -> LibraryPassageLoadFailure? {
        passageLoadFailures[passageKey(for: annotation)]
    }

    /// Called on view load (LibraryView); gets missing book display names
    func loadMissingBookMetadata() async {
        let unloadedIDs = Set(self.annotations
            .filter { bibleCatalogStore.books(for: $0.translationID) == nil } // not in memory
            .map { $0.translationID } // only need the ID
        )

        await withDiscardingTaskGroup { group in
            for translationID in unloadedIDs {
                group.addTask {
                    do {
                        try await self.bibleCatalogStore.loadBooks(for: translationID)
                    } catch {
                        await Self.logger.error("loadMissingBookMetadata(): load for ID \(translationID) failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// Map VerseAnnotation -> LoadedBiblePassage (if available)
    func passage(for annotation: VerseAnnotation) -> LoadedBiblePassage? {
        if let loadedPassage = loadedPassages[passageKey(for: annotation)] {
            return loadedPassage
        }
        return nil
    }

    /// Request change of a highlight annotation's color
    func changeHighlightColor(_ id: VerseAnnotation.ID,
                              color: VerseAnnotationHighlightColor) -> Bool {
        do {
            guard var annotation = annotations.first(where: { $0.id == id }) else {
                Self.logger.error("Unable to locate annotation ID '\(id)'")
                return false
            }
            annotation.content = .highlight(color)
            annotation.updatedAt = Date()
            try libraryRepository.save(annotation)
            load()
            return true
        } catch {
            Self.logger.error("Unable to change annotation color for ID '\(id)': \(error.localizedDescription)")
            return false
        }
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

    /// Request deletion of a set of annotations
    func delete(_ ids: Set<VerseAnnotation.ID>) -> Bool {
        var errorCount: Int = 0

        for id in ids {
            do {
                try libraryRepository.delete(id)
            } catch {
                Self.logger.error("Unable to delete annotation: \(error.localizedDescription)")
                errorCount += 1
            }
        }

        load()
        return errorCount == 0
    }

    /// Request deletion of ALL ANNOTATIONS (DANGEROUS!)
    func deleteAll() -> Bool {
        var errorCount: Int = 0

        do {
            try libraryRepository.deleteAll()
        } catch {
            Self.logger.error("Unable to delete annotations: \(error.localizedDescription)")
            errorCount += 1
        }

        load()
        return errorCount == 0
    }

    /// Build AnnotationEditor instance for a given VerseAnnotation (reuses LibraryStore.libraryRepository)
    func annotationEditor(for annotation: VerseAnnotation) -> AnnotationEditor? {
        AnnotationEditor(annotation: annotation,
                         libraryRepository: libraryRepository)
    }

    // MARK: Functions (Private)

    /// Map VerseAnnotation -> BiblePassageKey
    private func passageKey(for annotation: VerseAnnotation) -> BiblePassageKey {
        return BiblePassageKey(translationID: annotation.translationID,
                               bookCode: annotation.bookCode,
                               chapter: annotation.chapter)
    }
}

/// Why a Library card's passage is not shown
enum LibraryPassageLoadFailure: Equatable {
    /// No connection (or online-only passages while offline); reloads on reconnect
    case offline
    /// Any other failure; retried on reconnect or when the card appears again
    case failed
}
