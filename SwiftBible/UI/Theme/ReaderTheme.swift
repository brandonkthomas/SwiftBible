//
//  ReaderTheme.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-12.
//

import SwiftUI

enum ReaderTheme: String, CaseIterable, Codable, Identifiable {
    case classic
    case vesper
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
        case .vesper: "Vesper"
        case .folio: "Folio"
        case .ink: "Ink"
        case .linen: "Linen"
        case .ember: "Ember"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .classic: .readerThemeClassicBackground
        case .vesper: .readerThemeVesperBackground
        case .folio: .readerThemeFolioBackground
        case .ink: .readerThemeInkBackground
        case .linen: .readerThemeLinenBackground
        case .ember: .readerThemeEmberBackground
        }
    }

    var primaryTextColor: Color {
        switch self {
        case .classic: .readerThemeClassicPrimaryText
        case .vesper: .readerThemeVesperPrimaryText
        case .folio: .readerThemeFolioPrimaryText
        case .ink: .readerThemeInkPrimaryText
        case .linen: .readerThemeLinenPrimaryText
        case .ember: .readerThemeEmberPrimaryText
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .classic: .readerThemeClassicSecondaryText
        case .vesper: .readerThemeVesperSecondaryText
        case .folio: .readerThemeFolioSecondaryText
        case .ink: .readerThemeInkSecondaryText
        case .linen: .readerThemeLinenSecondaryText
        case .ember: .readerThemeEmberSecondaryText
        }
    }

    var fontDesign: Font.Design {
        switch self {
        case .classic: .default
        case .vesper: .serif
        case .folio: .serif
        case .ink: .default
        case .linen: .serif
        case .ember: .default
        }
    }

    var fontWeight: Font.Weight {
        switch self {
        case .classic: .regular
        case .vesper: .regular
        case .folio: .regular
        case .ink: .medium
        case .linen: .regular
        case .ember: .regular
        }
    }

    /// Finds a preset by ID; nil if unknown
    static func preset(withID id: String) -> ReaderTheme? {
        ReaderTheme(rawValue: id)
    }
}
