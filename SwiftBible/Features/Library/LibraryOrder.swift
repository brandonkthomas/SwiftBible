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
    var sort: LibraryOrderSort = .dateAddedDescending

    /// Grouping preferences
    var group: LibraryOrderGroup = .none

    // MARK: Properties (Computed)

    /// True if we're not using strictly defaults
    var isAnySortActive: Bool {
        sort != .dateAddedDescending
    }

    /// True if we're not using strictly defaults
    var isAnyGroupActive: Bool {
        group != .none
    }

    // MARK: Functions



}

/// Library sorting preferences used by LibraryOrder
enum LibraryOrderSort {
    case dateAddedDescending
    case dateAddedAscending
    case bookOrderDescending
    case bookOrderAscending
}

/// Library grouping preferences used by LibraryOrder
enum LibraryOrderGroup {
    case none
    case dateAdded
    case translation
    case book
}
