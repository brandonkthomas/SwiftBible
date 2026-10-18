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
            func bookOrderComparison(_ a: VerseAnnotation, _ b: VerseAnnotation) -> Bool {
                ((bookPosition(a) ?? -1), a.bookCode, a.chapter, a.startVerse, a.createdAt)
                > ((bookPosition(b) ?? -1), b.bookCode, b.chapter, b.startVerse, b.createdAt)
            }
            return annotations.sorted(by: bookOrderComparison)
        case .bookOrderAscending:
            func bookOrderComparison(_ a: VerseAnnotation, _ b: VerseAnnotation) -> Bool {
                ((bookPosition(a) ?? Int.max), a.bookCode, a.chapter, a.startVerse, a.createdAt)
                < ((bookPosition(b) ?? Int.max), b.bookCode, b.chapter, b.startVerse, b.createdAt)
            }
            return annotations.sorted(by: bookOrderComparison)
        }
    }

    /// Reusable grouping function
    func grouped(annotations: [VerseAnnotation],
                 bookPosition: (VerseAnnotation) -> Int?,
                 bookName: (VerseAnnotation) -> String?,
                 translationAbbreviation: (Translation.ID) -> String?) -> [LibraryOrderGroup] {
        var groups: [LibraryOrderGroup] = []

        // logic for all possible options
        switch groupOption {
        case .none:
            groups.append(LibraryOrderGroup(id: "all",
                                            title: nil,
                                            annotations: annotations))
        case .translation:
            let dict = Dictionary(grouping: annotations,
                                  by: { $0.translationID }) // Translation.ID:[VerseAnnotation]
            for entry in dict {
                // if callback is nil, entry is dropped; prevent that case
                let title = translationAbbreviation(entry.key) ?? entry.key.description
                let group = LibraryOrderGroup(id: entry.key.description,
                                              title: title,
                                              annotations: entry.value)
                groups.append(group)
            }
        case .book:
            let dict = Dictionary(grouping: annotations,
                                  by: { $0.bookCode }) // String:[VerseAnnotation]
            // each entry is a (key: bookCode, value: [VerseAnnotation]) tuple
            // value[0] stands in for the whole section; grouping never makes an empty array
            // unknown books sort last; bookCode keeps them in a fixed order
            let entries = dict.sorted { a, b in
                if sortOption == .bookOrderDescending {
                    return (bookPosition(a.value[0]) ?? -1, a.key) > (bookPosition(b.value[0]) ?? -1, b.key)
                }
                return (bookPosition(a.value[0]) ?? Int.max, a.key) < (bookPosition(b.value[0]) ?? Int.max, b.key)
            }
            for entry in entries {
                let group = LibraryOrderGroup(id: entry.key, // bookCode
                                              title: bookName(entry.value[0]) ?? entry.key,
                                              annotations: entry.value) // [VerseAnnotation]
                groups.append(group)
            }
        case .dateAdded:
            let calendar = Calendar.current
            let dict = Dictionary(grouping: annotations,
                                  by: { calendar.startOfDay(for: $0.createdAt) }) // Date:[VerseAnnotation]
            // each entry is a (key: Date, value: [VerseAnnotation]) tuple
            // value[0] stands in for the whole section; grouping never makes an empty array
            let entries = dict.sorted { a, b in
                if sortOption == .dateAddedAscending {
                    return a.key < b.key
                }
                return a.key > b.key
            }
            for entry in entries {
                let group = LibraryOrderGroup(id: entry.key.description,
                                              title: entry.key.formatted(date: .long, time: .omitted),
                                              annotations: entry.value)
                groups.append(group)
            }
        }

        return groups
    }
}

/// Represents a group of annotations
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
