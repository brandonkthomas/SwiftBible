//
//  LibrarySelection.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-10-04.
//

import Foundation

struct LibrarySelection: Equatable {

    // MARK: Properties

    /// Is the Library in selection mode (i.e. this value is non-nil)?
    /// If so, what IDs are selected, if any?
    private var selectedIDs: Set<VerseAnnotation.ID>?

    // MARK: Properties (Computed)

    /// Are we currently making any selections?
    var isSelecting: Bool {
        self.selectedIDs != nil
    }

    /// Return internal list of currently selected IDs
    ///
    /// Nil if not currently in selection mode
    var allSelectedIDs: Set<VerseAnnotation.ID>? {
        // no need to decouple reference before returning it since this is value type
        return self.selectedIDs
    }

    /// Return number of total currently selected IDs (if any)
    ///
    /// Nil if not currently in selection mode
    var selectedIDCount: Int? {
        self.selectedIDs?.count
    }

    // MARK: Functions (Read)

    /// Is the provided ID currently selected?
    func isSelected(_ id: VerseAnnotation.ID) -> Bool {
        guard isSelecting else { return false } // sanity check -- NOT required
        return self.selectedIDs?.contains(id) ?? false
    }

    // MARK: Functions (Write)
    // value types (struct, enum) in Swift are "C# readonly" by default; "mutating" changes
    // Swift (opt in) is inverted behavior compared to C# (opt out)

    /// Enter selection mode, optionally using a range of IDs to pre-select
    mutating func beginSelection(annotationIDs: Set<VerseAnnotation.ID> = []) {
        self.selectedIDs = annotationIDs
    }

    /// Exit selection mode (forgets selected IDs)
    mutating func endSelection() {
        self.selectedIDs = nil
    }

    /// Add a VerseAnnotation to the selection
    ///
    /// If selection mode disabled, this will do nothing
    mutating func addToSelection(_ id: VerseAnnotation.ID) {
        guard isSelecting else { return } // sanity check -- NOT required
        self.selectedIDs?.insert(id)
    }

    /// Remove a VerseAnnotation from the selection
    mutating func removeFromSelection(_ id: VerseAnnotation.ID) {
        self.selectedIDs?.remove(id)
    }

    /// Update selected IDs to only display annotations that are both selected AND visible.
    /// Drops all other IDs.
    mutating func deselectHidden(visibleIDs: Set<VerseAnnotation.ID>) {
        guard let currentSelection = self.selectedIDs else { return } // sanity check
        self.selectedIDs = currentSelection.intersection(visibleIDs)
    }
}
