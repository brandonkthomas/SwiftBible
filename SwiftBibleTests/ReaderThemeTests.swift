//
//  ReaderThemeTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-12.
//

import Foundation
import Testing
@testable import SwiftBible

struct ReaderThemeTests {

    /// No two presets share an ID; IDs are persisted, so a collision would load the wrong theme
    @Test func presetIDsAreUnique() {
        let ids = ReaderTheme.allCases.map(\.id)

        #expect(Set(ids).count == ids.count)
    }

    /// Looking up the default preset's ID returns the default preset
    @Test func lookupByDefaultIDReturnsDefault() {
        let found = ReaderTheme.preset(withID: ReaderTheme.default.id)

        #expect(found == ReaderTheme.default)
    }

    /// The default preset is one of the built-in presets
    @Test func defaultIsInPresetList() {
        #expect(ReaderTheme.allCases.contains(ReaderTheme.default))
    }
}
