//
//  ReaderTheme.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-12.
//

import SwiftUI

enum ReaderTheme: String, CaseIterable, Codable, Identifiable {
    case classic
    case quiet
    case folio
    case ink
    case linen
    case ember

    /// Built-in default preset
    static let `default`: ReaderTheme = .classic

    /// Stable computed ID
    var id: String { rawValue }

    /// Localized string display name
    var displayName: LocalizedStringResource {
        switch self {
        case .classic: "Classic"
        case .quiet: "Quiet"
        case .folio: "Folio"
        case .ink: "Ink"
        case .linen: "Linen"
        case .ember: "Ember"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .classic: .readerThemeClassicBackground
        case .quiet: .readerThemeQuietBackground
        case .folio: .readerThemeFolioBackground
        case .ink: .readerThemeInkBackground
        case .linen: .readerThemeLinenBackground
        case .ember: .readerThemeEmberBackground
        }
    }

    var primaryTextColor: Color {
        switch self {
        case .classic: .readerThemeClassicPrimaryText
        case .quiet: .readerThemeQuietPrimaryText
        case .folio: .readerThemeFolioPrimaryText
        case .ink: .readerThemeInkPrimaryText
        case .linen: .readerThemeLinenPrimaryText
        case .ember: .readerThemeEmberPrimaryText
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .classic: .readerThemeClassicSecondaryText
        case .quiet: .readerThemeQuietSecondaryText
        case .folio: .readerThemeFolioSecondaryText
        case .ink: .readerThemeInkSecondaryText
        case .linen: .readerThemeLinenSecondaryText
        case .ember: .readerThemeEmberSecondaryText
        }
    }

    /// Default 135 = 1.35x; user-customizable via ReaderThemeCustom
    var lineSpacingPercent: Int {
        135
    }

    /// Default 24; user-customizable via ReaderThemeCustom
    var marginPoints: Int {
        24
    }

    /// Extra space between letters, as a percent of the font size (0 = none);
    /// user-customizable via ReaderThemeCustom
    var characterSpacingPercent: Int {
        0
    }

    /// Extra space between words, as a percent of the font size (0 = none);
    /// user-customizable via ReaderThemeCustom
    var wordSpacingPercent: Int {
        0
    }

    /// Preset's default font family; user-customizable via ReaderThemeCustom
    var font: ReaderThemeFont {
        switch self {
        case .classic: .system
        case .quiet: .system
        case .folio: .seravek
        case .ink: .athelas
        case .linen: .palatino
        case .ember: .iowan
        }
    }

    var fontDesign: ReaderThemeCustomFontDesign {
        switch self {
        case .classic: .serif
        case .quiet: .default
        case .folio: .serif
        case .ink: .default
        case .linen: .serif
        case .ember: .default
        }
    }

    var fontWeight: ReaderThemeCustomFontWeight {
        switch self {
        case .classic: .regular
        case .quiet: .regular
        case .folio: .regular
        case .ink: .bold
        case .linen: .regular
        case .ember: .regular
        }
    }

    /// Finds a preset by ID; nil if unknown
    static func preset(withID id: String) -> ReaderTheme? {
        ReaderTheme(rawValue: id)
    }
}
