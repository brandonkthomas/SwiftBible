//
//  PreferredColorScheme.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-13.
//

import SwiftUI

enum PreferredColorScheme: String, CaseIterable, Codable, Identifiable {
    case light
    case dark
    case system

    /// Default to System
    static let `default`: PreferredColorScheme = .system

    /// Stable computed ID
    var id: String { rawValue }

    /// Localized string display name
    var displayName: LocalizedStringResource {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .system: "Device"
        }
    }

    /// ColorScheme for the preferred choice (nil if System)
    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil // no preference
        }
    }

    /// Finds a scheme by ID; nil if unknown
    static func scheme(withID id: String) -> PreferredColorScheme? {
        PreferredColorScheme(rawValue: id)
    }
}
