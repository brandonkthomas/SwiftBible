//
//  PreferencesStore.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-10-23.
//

import Foundation
import OSLog

/// Stores various app preferences/defaults
///
/// - ReaderPosition
@Observable
final class PreferencesStore {

    // MARK: Properties (UserDefaults)
    // Each automatically calls UserDefaults.set/remove on any modification

    /// Last-used reader position (if any)
    ///
    var readerPosition: ReaderPosition? {
        didSet {
            if let readerPosition {
                // we have a value; try to encode + save it
                do {
                    let data = try JSONEncoder().encode(readerPosition)
                    userDefaults.set(data, forKey: Self.readerPositionKey)
                } catch {
                    Self.logger.error("PreferencesStore: readerPosition failed to encode: \(error.localizedDescription)")
                }
            } else {
                userDefaults.removeObject(forKey: Self.readerPositionKey)
            }
        }
    }

    /// Configured reader theme
    var readerTheme: ReaderTheme = .default {
        didSet {
            userDefaults.set(readerTheme.rawValue, forKey: Self.readerThemeKey)
        }
    }

    /// Configured color scheme preference (light/dark/system)
    var preferredColorScheme: PreferredColorScheme = .default {
        didSet {
            userDefaults.set(preferredColorScheme.rawValue, forKey: Self.preferredColorSchemeKey)
        }
    }

    // MARK: Properties (Private)

    /// Provided UserDefaults instance
    private let userDefaults: UserDefaults

    /// Stable UserDefaults key for ReaderPosition storage
    private static let readerPositionKey = "net.brandonthomas.SwiftBible.readerPosition"

    /// Stable UserDefaults key for ReaderTheme storage
    private static let readerThemeKey = "net.brandonthomas.SwiftBible.readerTheme"

    /// Stable UserDefaults key for preferred ColorScheme storage
    private static let preferredColorSchemeKey = "net.brandonthomas.SwiftBible.preferredColorScheme"

    private static let logger = Logger(subsystem: "SwiftBible", category: "PreferencesStore")

    // MARK: Init

    /// Stores UserDefaults in-instance and tries to load saved ReaderPosition
    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults

        // try to retrieve any saved elements
        if let savedPositionData = userDefaults.data(forKey: Self.readerPositionKey),
           let savedPosition = try? JSONDecoder().decode(ReaderPosition.self, from: savedPositionData) {
            self.readerPosition = savedPosition
        }

        if let savedThemeString = userDefaults.string(forKey: Self.readerThemeKey),
           let savedTheme = ReaderTheme.preset(withID: savedThemeString) {
            self.readerTheme = savedTheme
        }

        if let preferredColorSchemeString = userDefaults.string(forKey: Self.preferredColorSchemeKey),
           let preferredColorScheme = PreferredColorScheme.scheme(withID: preferredColorSchemeString) {
            self.preferredColorScheme = preferredColorScheme
        }
    }
}
