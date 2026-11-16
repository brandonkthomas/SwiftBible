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

    /// Configured reader text size step increment
    var readerTextSizeStep: Int = 0 {
        didSet {
            userDefaults.set(readerTextSizeStep, forKey: Self.readerTextSizeStepKey)
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

    /// Stable UserDefaults key for preferred reader text size step storage
    private static let readerTextSizeStepKey = "net.brandonthomas.SwiftBible.readerTextSizeStep"

    /// Stable UserDefaults key for preferred ColorScheme storage
    private static let preferredColorSchemeKey = "net.brandonthomas.SwiftBible.preferredColorScheme"

    private static let logger = Logger(subsystem: "SwiftBible", category: "PreferencesStore")

    // MARK: Init

    /// Stores UserDefaults in-instance and tries to load any saved preferences
    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults

        // try to retrieve any saved elements
        // Last Reader position
        if let savedPositionData = userDefaults.data(forKey: Self.readerPositionKey),
           let savedPosition = try? JSONDecoder().decode(ReaderPosition.self, from: savedPositionData) {
            self.readerPosition = savedPosition
        }

        // Theme preset
        if let savedThemeString = userDefaults.string(forKey: Self.readerThemeKey),
           let savedTheme = ReaderTheme.preset(withID: savedThemeString) {
            self.readerTheme = savedTheme
        }

        // Theme preset customizations
        if let savedThemeCustomChangesData = userDefaults.data(forKey: Self.readerThemeCustomChangesKey),
           let savedThemeCustomChanges = try? JSONDecoder().decode([String: ReaderThemeCustom].self,
                                                                   from: savedThemeCustomChangesData) {
            self.readerThemeCustomChanges = savedThemeCustomChanges
        }

        // System Color Scheme
        if let preferredColorSchemeString = userDefaults.string(forKey: Self.preferredColorSchemeKey),
           let preferredColorScheme = PreferredColorScheme.scheme(withID: preferredColorSchemeString) {
            self.preferredColorScheme = preferredColorScheme
        }

        // Text size
        let readerTextSizeStep = userDefaults.integer(forKey: Self.readerTextSizeStepKey)
        let readerTextSizeStepClamped = min( // clamp as a sanity check
            max(readerTextSizeStep, ReaderThemeResolved.textSizeStepRange.lowerBound),
            ReaderThemeResolved.textSizeStepRange.upperBound
        )
        self.readerTextSizeStep = readerTextSizeStepClamped
    }

    // MARK: Functions

    /// Returns a resolved ReaderTheme for a given preset + all its user customizations
    func readerThemeResolved(for preset: ReaderTheme) -> ReaderThemeResolved {
        ReaderThemeResolved(basePreset: preset,
                            customizedPreset: readerThemeCustomChanges[preset.rawValue],
                            textSizeStep: readerTextSizeStep)
    }

    /// Apply modified custom changes (skip unmodified options)
    ///
    /// Starts from nothing + overrides ALL customizations for a given base preset
    func replaceReaderThemeCustomChanges(_ changes: ReaderThemeCustom,
                                         for preset: ReaderTheme) {
        // clean up changes before saving
        var stagedChanges = changes
        let key = preset.rawValue

        // if we have a font preference & it's equal to preset, then do not override
        if let stagedCustomFont = stagedChanges.font,
           stagedCustomFont == preset.font {
            stagedChanges.font = nil
        }

        // if we have a design preference & it's equal to preset, then do not override
        if let stagedCustomFontDesign = stagedChanges.fontDesign,
           stagedCustomFontDesign == preset.fontDesign {
            stagedChanges.fontDesign = nil
        }

        // if we have a weight preference & it's equal to preset, then do not override
        if let stagedCustomFontWeight = stagedChanges.fontWeight,
           stagedCustomFontWeight == preset.fontWeight {
            stagedChanges.fontWeight = nil
        }

        // if we have a line spacing preference & it's equal to preset, then do not override
        if let stagedCustomLineSpacing = stagedChanges.lineSpacingPercent,
           stagedCustomLineSpacing == preset.lineSpacingPercent {
            stagedChanges.lineSpacingPercent = nil
        }

        // if we have a margin preference & it's equal to preset, then do not override
        if let stagedCustomMargin = stagedChanges.marginPoints,
           stagedCustomMargin == preset.marginPoints {
            stagedChanges.marginPoints = nil
        }

        // if we have a character spacing preference & it's equal to preset, then do not override
        if let stagedCustomCharacterSpacing = stagedChanges.characterSpacingPercent,
           stagedCustomCharacterSpacing == preset.characterSpacingPercent {
            stagedChanges.characterSpacingPercent = nil
        }

        // if we have a word spacing preference & it's equal to preset, then do not override
        if let stagedCustomWordSpacing = stagedChanges.wordSpacingPercent,
           stagedCustomWordSpacing == preset.wordSpacingPercent {
            stagedChanges.wordSpacingPercent = nil
        }

        // if every field is still nil (no changes), clear and exit
        guard stagedChanges.isCustomized else {
            readerThemeCustomChanges[key] = nil
            return
        }

        readerThemeCustomChanges[key] = stagedChanges
    }

    /// Updates one or more existing custom changes for a base preset
    ///
    /// Does NOT replace the entire preset's customizations like `replaceReaderThemeCustomChanges` does
    func updateReaderThemeCustomChanges(for preset: ReaderTheme,
                                        _ change: (inout ReaderThemeCustom) -> Void) {
        // cannot guard here because we need nil to still execute; just use default init fallback
        var custom = self.readerThemeCustomChanges[preset.rawValue] ?? .init()

        // execute change closure (inout will ensure that `custom` is modified in-place)
        change(&custom)
        replaceReaderThemeCustomChanges(custom, for: preset)
    }

    /// Clear all user modifications from a given theme preset
    func resetReaderThemeCustomChanges(for preset: ReaderTheme) {
        self.readerThemeCustomChanges[preset.rawValue] = nil
    }

    /// Increase text size by 1 step
    func increaseTextSize() {
        modifyTextSize(by: 1)
    }

    /// Decrease text size by 1 step
    func decreaseTextSize() {
        modifyTextSize(by: -1)
    }

    // MARK: Functions (Private)

    private func modifyTextSize(by amount: Int) {
        let requestedSize = self.readerTextSizeStep + amount
        let cappedSize = min(
            max(requestedSize, ReaderThemeResolved.textSizeStepRange.lowerBound),
            ReaderThemeResolved.textSizeStepRange.upperBound
        )
        self.readerTextSizeStep = cappedSize
    }
}
