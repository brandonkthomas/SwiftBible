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
            // put newer days first when grouping by dateAdded
            if groupOption == .dateAdded {
                let calendar = Calendar.current
                return annotations.sorted { a, b in
                    // is day A later than day B?
                    let dayA = calendar.startOfDay(for: a.createdAt)
                    let dayB = calendar.startOfDay(for: b.createdAt)
                    if dayA != dayB {
                        return dayA > dayB
                    } else {
                        // days are the same; book order decides
                        return bookOrderComparison(a, b)
                    }
                }
            }
            return annotations.sorted(by: bookOrderComparison)
        case .bookOrderAscending:
            func bookOrderComparison(_ a: VerseAnnotation, _ b: VerseAnnotation) -> Bool {
                ((bookPosition(a) ?? Int.max), a.bookCode, a.chapter, a.startVerse, a.createdAt)
                < ((bookPosition(b) ?? Int.max), b.bookCode, b.chapter, b.startVerse, b.createdAt)
            }
            // put newer days first when grouping by dateAdded
            if groupOption == .dateAdded {
                let calendar = Calendar.current
                return annotations.sorted { a, b in
                    // is day A later than day B?
                    let dayA = calendar.startOfDay(for: a.createdAt)
                    let dayB = calendar.startOfDay(for: b.createdAt)
                    if dayA != dayB {
                        return dayA > dayB
                    } else {
                        // days are the same; book order decides
                        return bookOrderComparison(a, b)
                    }
                }
            }
            return annotations.sorted(by: bookOrderComparison)
        }
    }

    /// Reusable grouping function
    func grouped(annotations: [VerseAnnotation]) -> [LibraryOrderGroup] {
        var groups: [LibraryOrderGroup] = []

        // logic for all possible options
        switch groupOption {
        case .none:
            groups.append(LibraryOrderGroup(id: "all",
                                            title: nil,
                                            annotations: annotations))
        case .translation:
            let dict = Dictionary(grouping: annotations,
                                  by: { $0.translationID }) // Translation.ID : VerseAnnotation
            var translationIDs: [Translation.ID] = []
            for annotation in annotations {
                if !translationIDs.contains(annotation.translationID) {
                    translationIDs.append(annotation.translationID)
                }
            }
            for translationID in translationIDs {
                guard let annotationsForTranslationID = dict[translationID] else { continue }
                let group = LibraryOrderGroup(id: translationID.description,
                                              title: translationID.description, // TODO: friendly name
                                              annotations: annotationsForTranslationID)
                groups.append(group)
            }
        case .book:
            let dict = Dictionary(grouping: annotations,
                                  by: { $0.bookCode }) // String : VerseAnnotation
            var bookCodes: [String] = []
            for annotation in annotations {
                if !bookCodes.contains(annotation.bookCode) {
                    bookCodes.append(annotation.bookCode)
                }
            }
            for bookCode in bookCodes {
                guard let annotationsForBookCode = dict[bookCode] else { continue }
                let group = LibraryOrderGroup(id: bookCode,
                                              title: bookCode, // TODO: friendly name
                                              annotations: annotationsForBookCode)
                groups.append(group)
            }
        case .dateAdded:
            let calendar = Calendar.current
            let dict = Dictionary(grouping: annotations,
                                  by: { calendar.startOfDay(for: $0.createdAt) }) // Date : VerseAnnotation
            var dates: [Date] = []
            for annotation in annotations {
                let startOfDay = calendar.startOfDay(for: annotation.createdAt)
                if !dates.contains(startOfDay) {
                    dates.append(startOfDay)
                }
            }
            for date in dates {
                guard let annotationsForDate = dict[date] else { continue }
                let group = LibraryOrderGroup(id: date.description,
                                              title: date.formatted(date: .long, time: .omitted),
                                              annotations: annotationsForDate)
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
