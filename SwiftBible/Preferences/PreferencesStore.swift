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

    /// User tweaks to a specific ReaderTheme preset
    var readerThemeCustomChanges: [String: ReaderThemeCustom] = [:] {
        didSet {
            do {
                let data = try JSONEncoder().encode(readerThemeCustomChanges)
                userDefaults.set(data, forKey: Self.readerThemeCustomChangesKey)
            } catch {
                Self.logger.error("PreferencesStore: readerThemeCustomChanges failed to encode: \(error.localizedDescription)")
            }
        }
    }

    /// Configured color scheme preference (light/dark/system)
    var preferredColorScheme: PreferredColorScheme = .default {
        didSet {
            userDefaults.set(preferredColorScheme.rawValue, forKey: Self.preferredColorSchemeKey)
        }
    }

    // MARK: Properties (NOT Persisted)

    /// Resolved ReaderTheme for the currently selected preset + all its user customizations
    var selectedReaderThemeResolved: ReaderThemeResolved {
        self.readerThemeResolved(for: readerTheme)
    }

    // MARK: Properties (Private)

    /// Provided UserDefaults instance
    private let userDefaults: UserDefaults

    /// Stable UserDefaults key for ReaderPosition storage
    private static let readerPositionKey = "net.brandonthomas.SwiftBible.readerPosition"

    /// Stable UserDefaults key for ReaderTheme storage
    private static let readerThemeKey = "net.brandonthomas.SwiftBible.readerTheme"

    /// Stable UserDefaults key for storing ReaderThemeCustom changes
    private static let readerThemeCustomChangesKey = "net.brandonthomas.SwiftBible.readerThemeCustomChanges"

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

        if let savedThemeCustomChangesData = userDefaults.data(forKey: Self.readerThemeCustomChangesKey),
           let savedThemeCustomChanges = try? JSONDecoder().decode([String: ReaderThemeCustom].self,
                                                                   from: savedThemeCustomChangesData) {
            self.readerThemeCustomChanges = savedThemeCustomChanges
        }

        if let preferredColorSchemeString = userDefaults.string(forKey: Self.preferredColorSchemeKey),
           let preferredColorScheme = PreferredColorScheme.scheme(withID: preferredColorSchemeString) {
            self.preferredColorScheme = preferredColorScheme
        }
    }

    // MARK: Functions

    func setReaderThemeCustomChanges(_ changes: ReaderThemeCustom,
                                     for preset: ReaderTheme) {
        // clean up changes before saving
        var stagedChanges = changes
        let key = preset.rawValue

        // we have a weight preference
        if let stagedCustomFontWeight = stagedChanges.fontWeight {
            // equal to preset; don't override
            if stagedCustomFontWeight == preset.fontWeight {
                stagedChanges.fontWeight = nil
            }
            // NOT equal to preset; allow overriding (we already have the value set)
        }

        // if every field is still nil (no changes), clear and exit
        guard stagedChanges.isCustomized else {
            readerThemeCustomChanges[key] = nil
            return
        }

        readerThemeCustomChanges[key] = stagedChanges
    }

    /// Returns a resolved ReaderTheme for a given preset + all its user customizations
    func readerThemeResolved(for preset: ReaderTheme) -> ReaderThemeResolved {
        ReaderThemeResolved(basePreset: preset,
                            customizedPreset: readerThemeCustomChanges[preset.rawValue])
    }
}
