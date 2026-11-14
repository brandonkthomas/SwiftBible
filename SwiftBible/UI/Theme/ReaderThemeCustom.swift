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

    /// Custom font weight (`nil` = the preset's weight)
    var fontWeight: ReaderThemeCustomFontWeight?

    /// Custom font family (`nil` = the preset's family)
    var font: ReaderThemeFont?

    /// Custom font design (`nil` = the preset's design)
    var fontDesign: ReaderThemeCustomFontDesign?

    /// Does any field differ from the preset? (Drives the `*` marker.)
    var isCustomized: Bool {
        self != ReaderThemeCustom()
    }
}

/// App-owned font weight because `Font.Weight` is not `Codable`
/// Raw values are saved-- never rename a case
nonisolated enum ReaderThemeCustomFontWeight: String, Codable, CaseIterable {
    case ultraLight
    case thin
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case black

    /// The SwiftUI weight this case stands for
    var weight: Font.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

/// App-owned font design because `Font.Design` is not `Codable`
nonisolated enum ReaderThemeCustomFontDesign: String, Codable, CaseIterable {
    case `default`
    case serif

    var design: Font.Design {
        switch self {
        case .default: .default
        case .serif: .serif
        }
    }
}
