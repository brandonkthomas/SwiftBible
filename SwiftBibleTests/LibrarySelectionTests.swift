//
//  LibrarySelectionTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-10-07.
//

import Foundation
import Testing
@testable import SwiftBible

struct LibrarySelectionTests {

    /// a default LibrarySelection() is not in selection mode and has nothing selected
    @Test func defaultIsNotSelectingAndHasNothingSelected() {
        let selection = LibrarySelection()

        #expect(selection.allSelectedIDs == nil)
        #expect(selection.selectedIDCount == nil)
    }

    /// entering selection mode without pre-selected IDs gives an empty selection
    @Test func beginSelectionEntersSelectionModeWithNothingSelected() {
        var selection = LibrarySelection()

        selection.beginSelection()

        #expect(selection.allSelectedIDs == [])
        #expect(selection.selectedIDCount == 0)
    }

    /// adding then removing the same ID round-trips to the original selection
    @Test func addingThenRemovingIDRestoresOriginalSelection() {
        var selection = LibrarySelection()
        selection.beginSelection(annotationIDs: [UUID()])
        let original = selection
        let id = UUID()

        selection.addToSelection(id)
        #expect(selection.allSelectedIDs?.contains(id) == true)

        selection.removeFromSelection(id)
        #expect(selection == original)
    }

    /// leaving selection mode forgets every selected ID
    @Test func endSelectionClearsSelectedIDs() {
        var selection = LibrarySelection()
        selection.beginSelection(annotationIDs: [UUID(), UUID()])

        selection.endSelection()

        #expect(selection.allSelectedIDs == nil)
        #expect(selection == LibrarySelection())
    }

    /// hidden IDs are dropped; visible selected IDs remain and selection mode stays on
    @Test func deselectHiddenKeepsOnlyVisibleSelectedIDs() {
        let visibleID = UUID()
        let hiddenID = UUID()
        let unselectedVisibleID = UUID()
        var selection = LibrarySelection()
        selection.beginSelection(annotationIDs: [visibleID, hiddenID])

        selection.deselectHidden(visibleIDs: [visibleID, unselectedVisibleID])

        #expect(selection.allSelectedIDs == [visibleID])
    }

    /// when every selected ID becomes hidden, selection mode stays on with an empty selection
    @Test func deselectHiddenStaysInSelectionModeWhenNothingIsLeft() {
        var selection = LibrarySelection()
        selection.beginSelection(annotationIDs: [UUID(), UUID()])

        selection.deselectHidden(visibleIDs: [UUID()])

        #expect(selection.allSelectedIDs == [])
        #expect(selection.selectedIDCount == 0)
    }

    /// outside selection mode, add and remove are no-ops and do not enter selection mode
    @Test func addAndRemoveOutsideSelectionModeAreNoOps() {
        var selection = LibrarySelection()
        let id = UUID()

        selection.addToSelection(id)
        #expect(selection.allSelectedIDs == nil)

        selection.removeFromSelection(id)
        #expect(selection.allSelectedIDs == nil)
        #expect(selection == LibrarySelection())
    }

    /// a selected ID reports as selected
    @Test func isSelectedReturnsTrueForSelectedID() {
        let id = UUID()
        var selection = LibrarySelection()
        selection.beginSelection(annotationIDs: [id])

        #expect(selection.isSelected(id))
    }

    /// in selection mode, an ID that was never selected reports as not selected
    @Test func isSelectedReturnsFalseForUnselectedIDWhileSelecting() {
        var selection = LibrarySelection()
        selection.beginSelection(annotationIDs: [UUID()])

        #expect(!selection.isSelected(UUID()))
    }

    /// outside selection mode, no ID reports as selected, including one that was selected before leaving
    @Test func isSelectedReturnsFalseForAnyIDWhileNotSelecting() {
        let previouslySelectedID = UUID()
        var selection = LibrarySelection()
        selection.beginSelection(annotationIDs: [previouslySelectedID])
        selection.endSelection()

        #expect(!selection.isSelected(previouslySelectedID))
        #expect(!selection.isSelected(UUID()))
    }
}
