//
//  LibraryOrder.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-10-09.
//

import Foundation

struct LibraryOrder: Equatable {

    // MARK: Properties

    /// Sorting preferences
    var sortOption: LibraryOrderSortOption = .dateAddedDescending

    /// Grouping preferences
    var groupOption: LibraryOrderGroupOption = .none

    // MARK: Properties (Computed)

    /// True if we're not using strictly defaults
    var isAnySortActive: Bool {
        sortOption != .dateAddedDescending
    }

    /// True if we're not using strictly defaults
    var isAnyGroupActive: Bool {
        groupOption != .none
    }

    // MARK: Functions

    /// Reusable sort function
    ///
    /// Intakes bookOrder closure; we pass VerseAnnotation & get back an optional Int;
    /// this prevents dependency bloat on BibleCatalogStore
    func sorted(annotations: [VerseAnnotation],
                bookPosition: (VerseAnnotation) -> Int?) -> [VerseAnnotation] {
        switch sortOption {
            // bookCode is fallback for annotations created at the same instant (sanity check)
            // ideally we check content.type, but this is not measurable
            case .dateAddedDescending:
            return annotations.sorted { a, b in
                (a.createdAt, a.bookCode) > (b.createdAt, b.bookCode)
            }
            case .dateAddedAscending:
            return annotations.sorted { a, b in
                (a.createdAt, a.bookCode) < (b.createdAt, b.bookCode)
            }
            // unknown books sort last
            // 3-tuple is i.e. equiv to C# .OrderBy.ThenBy.ThenBy OR ValueTuple.CompareTo
            // bookCode added to keep unknown books together
            // createdAt added as a final tiebreaker
            case .bookOrderDescending:
            return annotations.sorted { a, b in
                ((bookPosition(a) ?? -1), a.bookCode, a.chapter, a.startVerse, a.createdAt)
                > ((bookPosition(b) ?? -1), b.bookCode, b.chapter, b.startVerse, b.createdAt)
            }
            case .bookOrderAscending:
            return annotations.sorted { a, b in
                ((bookPosition(a) ?? Int.max), a.bookCode, a.chapter, a.startVerse, a.createdAt)
                < ((bookPosition(b) ?? Int.max), b.bookCode, b.chapter, b.startVerse, b.createdAt)
            }
        }
    }

    /// Reusable grouping function
    ///
    /// TODO
    func grouped(annotations: [VerseAnnotation]) -> [LibraryOrderGroup] {
        var groups: [LibraryOrderGroup] = []

        groups.append(LibraryOrderGroup(id: "all",
                                        title: nil,
                                        annotations: annotations))

        return groups
    }
}

///
///
/// Equatable is required since LibraryOrder inherits & is Equatable
struct LibraryOrderGroup: Identifiable, Equatable {
    /// Represents whatever this is grouped by; i.e. a specific Translation.ID  or bookCode
    /// (stringified for reusability)
    let id: String
    /// Optional header text for this group
    let title: String?
    /// All annotations in this group
    let annotations: [VerseAnnotation]
}

/// Library sorting preferences used by LibraryOrder
enum LibraryOrderSortOption {
    case dateAddedDescending
    case dateAddedAscending
    case bookOrderDescending
    case bookOrderAscending
}

/// Library grouping preferences used by LibraryOrder
enum LibraryOrderGroupOption {
    case none
    case dateAdded
    case translation
    case book
}
