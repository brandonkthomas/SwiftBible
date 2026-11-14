//
//  ReaderThemeCustom.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-13.
//

import SwiftUI

/// User edits for one preset. Every field is Optional: `nil` means "use the
/// preset's value". Saved per preset, keyed by the preset's raw value, so the
/// preset itself is not stored here.
///
/// `nonisolated` so the `Codable` conformance is usable outside the main
/// actor (e.g. in tests that are not `@MainActor`).
nonisolated struct ReaderThemeCustom: Equatable, Codable {

    /// Custom background color in light mode
    ///
    /// `Color.Resolved` because `Color` is not `Codable`
    var backgroundColorLight: Color.Resolved?

    /// Custom background color in dark mode
    var backgroundColorDark: Color.Resolved?

    /// Custom primary text color in light mode
    var primaryTextColorLight: Color.Resolved?

    /// Custom primary text color in dark mode
    var primaryTextColorDark: Color.Resolved?

    /// Custom secondary text color in light mode
    var secondaryTextColorLight: Color.Resolved?

    /// Custom secondary text color in dark mode
    var secondaryTextColorDark: Color.Resolved?

    /// `true` = bold; `nil` = the preset's weight
    var bold: Bool?

    /// Does any field differ from the preset? (Drives the `*` marker.)
    var isCustomized: Bool {
        self != ReaderThemeCustom()
    }
}
