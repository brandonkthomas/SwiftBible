//
//  PreferencesStoreTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-10-23.
//

import Testing
import Foundation
import SwiftUI
@testable import SwiftBible

@MainActor
struct PreferencesStoreTests {

    /// Mirrors PreferencesStore's private key; repeated here so the store's key can stay private
    private static let readerPositionKey = "net.brandonthomas.SwiftBible.readerPosition"
    private static let readerThemeKey = "net.brandonthomas.SwiftBible.readerTheme"
    private static let preferredColorSchemeKey = "net.brandonthomas.SwiftBible.preferredColorScheme"
    private static let readerThemeCustomChangesKey = "net.brandonthomas.SwiftBible.readerThemeCustomChanges"

    // MARK: Reader Position

    /// A fresh UserDefaults suite with nothing saved reads as nil
    @Test func missingReaderPositionReadsAsNil() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)

        #expect(store.readerPosition == nil)
    }

    /// A second PreferencesStore on the same UserDefaults sees what the first one set,
    /// confirming persistence doesn't depend on any in-memory state of the writer
    @Test func secondStoreOnSameDefaultsReadsFirstStoresPosition() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let position = testPosition()

        let firstStore = PreferencesStore(userDefaults: userDefaults)
        firstStore.readerPosition = position

        let secondStore = PreferencesStore(userDefaults: userDefaults)
        #expect(secondStore.readerPosition == position)
    }

    /// Setting a position and then clearing it leaves nothing for a second store to read
    @Test func clearedReaderPositionReadsAsNil() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let firstStore = PreferencesStore(userDefaults: userDefaults)
        firstStore.readerPosition = testPosition()
        firstStore.readerPosition = nil

        let secondStore = PreferencesStore(userDefaults: userDefaults)
        #expect(secondStore.readerPosition == nil)
    }

    /// Saved data that isn't valid JSON is treated as no position rather than a crash
    @Test func corruptReaderPositionReadsAsNil() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        userDefaults.set(Data("not valid json".utf8), forKey: Self.readerPositionKey)

        let store = PreferencesStore(userDefaults: userDefaults)
        #expect(store.readerPosition == nil)
    }

    // MARK: Reader Theme & Color Scheme

    /// A fresh UserDefaults suite with nothing saved loads the defaults
    @Test func missingThemeAndColorSchemeLoadAsDefaults() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)

        #expect(store.readerTheme == .default)
        #expect(store.preferredColorScheme == .system)
    }

    /// A second PreferencesStore on the same UserDefaults sees the theme and color scheme the first one set
    @Test func secondStoreOnSameDefaultsReadsFirstStoresThemeAndColorScheme() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        // non-default values, so a failed load can't pass by falling back to defaults
        let firstStore = PreferencesStore(userDefaults: userDefaults)
        firstStore.readerTheme = .quiet
        firstStore.preferredColorScheme = .dark

        let secondStore = PreferencesStore(userDefaults: userDefaults)
        #expect(secondStore.readerTheme == .quiet)
        #expect(secondStore.preferredColorScheme == .dark)
    }

    /// Saved strings that don't match any case load as the defaults rather than a crash
    @Test func unknownThemeAndColorSchemeLoadAsDefaults() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        userDefaults.set("not a theme", forKey: Self.readerThemeKey)
        userDefaults.set("not a scheme", forKey: Self.preferredColorSchemeKey)

        let store = PreferencesStore(userDefaults: userDefaults)
        #expect(store.readerTheme == .default)
        #expect(store.preferredColorScheme == .default)
    }

    /// System defers to the device (nil); Light and Dark force their ColorScheme
    @Test(arguments: [
        (PreferredColorScheme.system, ColorScheme?.none),
        (.light, .light),
        (.dark, .dark),
    ])
    func preferredColorSchemeMapsToColorScheme(preferred: PreferredColorScheme, expected: ColorScheme?) {
        #expect(preferred.colorScheme == expected)
    }

    // MARK: Reader Theme Custom Changes

    /// A fresh UserDefaults suite with nothing saved has no edits for any preset
    @Test func missingThemeCustomChangesLoadAsEmpty() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)

        #expect(store.readerThemeCustomChanges.isEmpty)
    }

    /// A second PreferencesStore on the same UserDefaults sees the edits the first one set,
    /// keyed by the preset's raw value, and only for that preset
    @Test func secondStoreOnSameDefaultsReadsFirstStoresThemeCustomChanges() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let firstStore = PreferencesStore(userDefaults: userDefaults)
        firstStore.setReaderThemeCustomChanges(ReaderThemeCustom(fontWeight: .bold), for: .linen)

        let secondStore = PreferencesStore(userDefaults: userDefaults)
        #expect(secondStore.readerThemeCustomChanges[ReaderTheme.linen.rawValue]?.fontWeight == .bold)
        #expect(secondStore.readerThemeCustomChanges[ReaderTheme.ink.rawValue] == nil)
        #expect(secondStore.readerThemeCustomChanges.count == 1)
    }

    /// Saved data that isn't valid JSON is treated as no edits rather than a crash
    @Test func corruptThemeCustomChangesLoadAsEmpty() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        userDefaults.set(Data("not valid json".utf8), forKey: Self.readerThemeCustomChangesKey)

        let store = PreferencesStore(userDefaults: userDefaults)
        #expect(store.readerThemeCustomChanges.isEmpty)
    }

    /// Setting edits through the store's method saves them under the preset's raw value
    @Test func settingThemeCustomChangesStoresThemUnderPresetID() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)
        store.setReaderThemeCustomChanges(ReaderThemeCustom(fontWeight: .bold), for: .linen)

        #expect(store.readerThemeCustomChanges[ReaderTheme.linen.rawValue]?.fontWeight == .bold)
        #expect(store.readerThemeCustomChanges.count == 1)
    }

    /// Setting edits with nothing changed removes the preset's entry (so no `*` and nothing saved),
    /// and a second store sees it gone
    @Test func settingEmptyThemeCustomChangesRemovesPresetEntry() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let firstStore = PreferencesStore(userDefaults: userDefaults)
        firstStore.setReaderThemeCustomChanges(ReaderThemeCustom(fontWeight: .bold), for: .linen)
        firstStore.setReaderThemeCustomChanges(ReaderThemeCustom(), for: .linen)

        #expect(firstStore.readerThemeCustomChanges[ReaderTheme.linen.rawValue] == nil)

        let secondStore = PreferencesStore(userDefaults: userDefaults)
        #expect(secondStore.readerThemeCustomChanges.isEmpty)
    }

    /// Picking the preset's own weight means "no change", so it is saved as `nil`;
    /// a weight that differs from the preset is kept, and other edits in the same value are kept
    @Test func presetWeightIsSavedAsNil() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)

        // Ink's own weight (medium) alone: nothing left, so no entry
        #expect(ReaderTheme.ink.fontWeight == .medium)
        store.setReaderThemeCustomChanges(ReaderThemeCustom(fontWeight: .medium), for: .ink)
        #expect(store.readerThemeCustomChanges[ReaderTheme.ink.rawValue] == nil)

        // regular differs from Ink's medium: kept
        store.setReaderThemeCustomChanges(ReaderThemeCustom(fontWeight: .regular), for: .ink)
        #expect(store.readerThemeCustomChanges[ReaderTheme.ink.rawValue]?.fontWeight == .regular)

        // Linen's own weight (regular) with a color edit: entry kept, weight cleared
        #expect(ReaderTheme.linen.fontWeight == .regular)
        let darkBackground = Color.Resolved(red: 0.1, green: 0.2, blue: 0.3)
        store.setReaderThemeCustomChanges(
            ReaderThemeCustom(backgroundColorDark: darkBackground, fontWeight: .regular),
            for: .linen
        )
        let linenChanges = try #require(store.readerThemeCustomChanges[ReaderTheme.linen.rawValue])
        #expect(linenChanges.fontWeight == nil)
        #expect(linenChanges.backgroundColorDark == darkBackground)
    }

    // MARK: Resolved Reader Theme

    /// With no changes saved, every preset resolves to its own values
    @Test(arguments: ReaderTheme.allCases)
    func resolvedThemeWithoutChangesMatchesPreset(preset: ReaderTheme) throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)
        let resolved = store.readerThemeResolved(for: preset)

        #expect(resolved.basePreset == preset)
        #expect(resolved.customizedPreset == nil)
        #expect(resolved.fontDesign == preset.fontDesign)
        #expect(resolved.fontWeight == preset.fontWeight)
        #expect(resolved.backgroundColor == preset.backgroundColor)
        #expect(resolved.primaryTextColor == preset.primaryTextColor)
        #expect(resolved.secondaryTextColor == preset.secondaryTextColor)
    }

    /// A preset resolves with its own changes and never with another preset's
    @Test func resolvedThemeAppliesOnlyThatPresetsChanges() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)
        store.setReaderThemeCustomChanges(ReaderThemeCustom(fontWeight: .regular), for: .ink)

        let ink = store.readerThemeResolved(for: .ink)
        #expect(ink.customizedPreset?.fontWeight == .regular)
        #expect(ink.fontWeight == .regular)

        let linen = store.readerThemeResolved(for: .linen)
        #expect(linen.customizedPreset == nil)
        #expect(linen.fontWeight == ReaderTheme.linen.fontWeight)
    }

    /// The selected resolved theme follows `readerTheme`, and switching back
    /// brings that preset's changes back
    @Test func selectedResolvedThemeFollowsReaderTheme() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let preferencesStore = PreferencesStore(userDefaults: userDefaults)
        preferencesStore.setReaderThemeCustomChanges(ReaderThemeCustom(fontWeight: .bold), for: .linen)

        preferencesStore.readerTheme = .ink
        #expect(preferencesStore.selectedReaderThemeResolved.basePreset == .ink)
        #expect(preferencesStore.selectedReaderThemeResolved.fontWeight == .medium)

        preferencesStore.readerTheme = .linen
        #expect(preferencesStore.selectedReaderThemeResolved.basePreset == .linen)
        #expect(preferencesStore.selectedReaderThemeResolved.fontWeight == .bold)
    }

    /// A preset with changes is named with a `*`; presets without changes are not
    @Test func resolvedDisplayNameMarksCustomizedPreset() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)
        store.setReaderThemeCustomChanges(ReaderThemeCustom(fontWeight: .regular), for: .ink)

        #expect(String(localized: store.readerThemeResolved(for: .ink).displayName) == "Ink*")
        #expect(String(localized: store.readerThemeResolved(for: .linen).displayName) == "Linen")
    }

    /// Clearing a preset's changes removes its `*`
    @Test func clearedChangesRemoveDisplayNameMarker() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)
        store.setReaderThemeCustomChanges(ReaderThemeCustom(fontWeight: .regular), for: .ink)
        store.setReaderThemeCustomChanges(ReaderThemeCustom(), for: .ink)

        #expect(String(localized: store.readerThemeResolved(for: .ink).displayName) == "Ink")
    }

    // MARK: Private Helpers

    private func testPosition() -> ReaderPosition {
        ReaderPosition(translationID: 1849, bookCode: "JHN", chapter: 3)
    }
}
