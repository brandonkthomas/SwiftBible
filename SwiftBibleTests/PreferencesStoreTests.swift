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
    private static let readerTextSizeStepKey = "net.brandonthomas.SwiftBible.readerTextSizeStep"

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

    // MARK: Reader Text Size

    /// Nothing saved: no text size step, and the resolved theme has none either
    @Test func missingTextSizeStepLoadsAsZero() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)

        #expect(store.readerTextSizeStep == 0)
        #expect(store.selectedReaderThemeResolved.textSizeStep == 0)
    }

    /// A second PreferencesStore on the same UserDefaults sees the step the first one set
    @Test func secondStoreReadsTextSizeStep() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let firstStore = PreferencesStore(userDefaults: userDefaults)
        firstStore.readerTextSizeStep = 2

        let secondStore = PreferencesStore(userDefaults: userDefaults)
        #expect(secondStore.readerTextSizeStep == 2)
    }

    /// A saved step outside -3...5 (bad data, or a newer build's range) loads clamped
    @Test func outOfRangeTextSizeStepLoadsClamped() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        userDefaults.set(40, forKey: Self.readerTextSizeStepKey)
        #expect(PreferencesStore(userDefaults: userDefaults).readerTextSizeStep == 5)

        userDefaults.set(-40, forKey: Self.readerTextSizeStepKey)
        #expect(PreferencesStore(userDefaults: userDefaults).readerTextSizeStep == -3)
    }

    /// One step for all presets: every resolved theme carries it, not only the selected one
    @Test func resolvedThemesCarryTextSizeStep() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)
        store.readerTheme = .folio
        store.readerTextSizeStep = 2

        #expect(store.selectedReaderThemeResolved.textSizeStep == 2)
        #expect(store.readerThemeResolved(for: .ink).textSizeStep == 2)
    }

    /// A/A taps move one step at a time and stop at -3 and 5, so extra taps don't pile up
    @Test func increaseAndDecreaseStopAtStepLimits() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)

        store.increaseTextSize()
        #expect(store.readerTextSizeStep == 1)

        for _ in 0..<10 { store.decreaseTextSize() }
        #expect(store.readerTextSizeStep == -3)

        for _ in 0..<20 { store.increaseTextSize() }
        #expect(store.readerTextSizeStep == 5)
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
        firstStore.replaceReaderThemeCustomChanges(ReaderThemeCustom(fontWeight: .bold), for: .linen)

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
        store.replaceReaderThemeCustomChanges(ReaderThemeCustom(fontWeight: .bold), for: .linen)

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
        firstStore.replaceReaderThemeCustomChanges(ReaderThemeCustom(fontWeight: .bold), for: .linen)
        firstStore.replaceReaderThemeCustomChanges(ReaderThemeCustom(), for: .linen)

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
        store.replaceReaderThemeCustomChanges(ReaderThemeCustom(fontWeight: .medium), for: .ink)
        #expect(store.readerThemeCustomChanges[ReaderTheme.ink.rawValue] == nil)

        // regular differs from Ink's medium: kept
        store.replaceReaderThemeCustomChanges(ReaderThemeCustom(fontWeight: .regular), for: .ink)
        #expect(store.readerThemeCustomChanges[ReaderTheme.ink.rawValue]?.fontWeight == .regular)

        // Linen's own weight (regular) with a color edit: entry kept, weight cleared
        #expect(ReaderTheme.linen.fontWeight == .regular)
        let darkBackground = Color.Resolved(red: 0.1, green: 0.2, blue: 0.3)
        store.replaceReaderThemeCustomChanges(
            ReaderThemeCustom(backgroundColorDark: darkBackground, fontWeight: .regular),
            for: .linen
        )
        let linenChanges = try #require(store.readerThemeCustomChanges[ReaderTheme.linen.rawValue])
        #expect(linenChanges.fontWeight == nil)
        #expect(linenChanges.backgroundColorDark == darkBackground)
    }

    /// Picking the preset's own font is saved as `nil`; a different font is kept
    @Test func presetFontIsSavedAsNil() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)

        // Folio's own font (system) alone: nothing left, so no entry
        #expect(ReaderTheme.folio.font == .system)
        store.replaceReaderThemeCustomChanges(ReaderThemeCustom(font: .system), for: .folio)
        #expect(store.readerThemeCustomChanges[ReaderTheme.folio.rawValue] == nil)

        // Georgia differs from Folio's system font: kept
        store.replaceReaderThemeCustomChanges(ReaderThemeCustom(font: .georgia), for: .folio)
        #expect(store.readerThemeCustomChanges[ReaderTheme.folio.rawValue]?.font == .georgia)
    }

    /// Picking the preset's own design is saved as `nil`; a different design is kept,
    /// and other edits in the same value are kept
    @Test func presetDesignIsSavedAsNil() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)

        // Folio's own design (serif) alone: nothing left, so no entry
        #expect(ReaderTheme.folio.fontDesign == .serif)
        store.replaceReaderThemeCustomChanges(ReaderThemeCustom(fontDesign: .serif), for: .folio)
        #expect(store.readerThemeCustomChanges[ReaderTheme.folio.rawValue] == nil)

        // default differs from Folio's serif: kept
        store.replaceReaderThemeCustomChanges(ReaderThemeCustom(fontDesign: .default), for: .folio)
        #expect(store.readerThemeCustomChanges[ReaderTheme.folio.rawValue]?.fontDesign == .default)

        // Quiet's own design (default) with a font edit: entry kept, design cleared
        #expect(ReaderTheme.quiet.fontDesign == .default)
        store.replaceReaderThemeCustomChanges(ReaderThemeCustom(font: .georgia, fontDesign: .default), for: .quiet)
        let quietChanges = try #require(store.readerThemeCustomChanges[ReaderTheme.quiet.rawValue])
        #expect(quietChanges.fontDesign == nil)
        #expect(quietChanges.font == .georgia)
    }

    /// Picking the preset's own line spacing (135) is saved as `nil`; a different value is kept
    @Test func presetLineSpacingIsSavedAsNil() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)

        // Folio's own line spacing alone: nothing left, so no entry
        #expect(ReaderTheme.folio.lineSpacingPercent == 135)
        store.replaceReaderThemeCustomChanges(ReaderThemeCustom(lineSpacingPercent: 135), for: .folio)
        #expect(store.readerThemeCustomChanges[ReaderTheme.folio.rawValue] == nil)

        // 150 differs from Folio's 135: kept
        store.replaceReaderThemeCustomChanges(ReaderThemeCustom(lineSpacingPercent: 150), for: .folio)
        #expect(store.readerThemeCustomChanges[ReaderTheme.folio.rawValue]?.lineSpacingPercent == 150)
    }

    /// Picking the preset's own margin (24) is saved as `nil`; a different margin is kept,
    /// and other edits in the same value are kept
    @Test func presetMarginIsSavedAsNil() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)

        // Folio's own margin alone: nothing left, so no entry
        #expect(ReaderTheme.folio.marginPoints == 24)
        store.replaceReaderThemeCustomChanges(ReaderThemeCustom(marginPoints: 24), for: .folio)
        #expect(store.readerThemeCustomChanges[ReaderTheme.folio.rawValue] == nil)

        // 32 differs from Folio's 24: kept
        store.replaceReaderThemeCustomChanges(ReaderThemeCustom(marginPoints: 32), for: .folio)
        #expect(store.readerThemeCustomChanges[ReaderTheme.folio.rawValue]?.marginPoints == 32)

        // Quiet's own margin with a line spacing edit: entry kept, margin cleared
        store.replaceReaderThemeCustomChanges(ReaderThemeCustom(lineSpacingPercent: 150, marginPoints: 24),
                                          for: .quiet)
        let quietChanges = try #require(store.readerThemeCustomChanges[ReaderTheme.quiet.rawValue])
        #expect(quietChanges.marginPoints == nil)
        #expect(quietChanges.lineSpacingPercent == 150)
    }

    /// Picking the preset's own spacing (0) is saved as `nil`; a different value is kept,
    /// and each field is cleared on its own
    @Test func presetSpacingIsSavedAsNil() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)

        // Folio's own spacing alone: nothing left, so no entry
        #expect(ReaderTheme.folio.characterSpacingPercent == 0)
        #expect(ReaderTheme.folio.wordSpacingPercent == 0)
        store.replaceReaderThemeCustomChanges(ReaderThemeCustom(characterSpacingPercent: 0, wordSpacingPercent: 0),
                                          for: .folio)
        #expect(store.readerThemeCustomChanges[ReaderTheme.folio.rawValue] == nil)

        // character 5 differs from 0: kept; word 0 equals the preset: cleared
        store.replaceReaderThemeCustomChanges(ReaderThemeCustom(characterSpacingPercent: 5, wordSpacingPercent: 0),
                                          for: .folio)
        let folioChanges = try #require(store.readerThemeCustomChanges[ReaderTheme.folio.rawValue])
        #expect(folioChanges.characterSpacingPercent == 5)
        #expect(folioChanges.wordSpacingPercent == nil)
    }

    // MARK: Editing One Field

    /// Each edit changes one field and keeps the preset's other edits
    @Test func updateChangesOneFieldAndKeepsOthers() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)

        store.updateReaderThemeCustomChanges(for: .folio) { $0.font = .georgia }
        store.updateReaderThemeCustomChanges(for: .folio) { $0.marginPoints = 40 }

        let folioChanges = try #require(store.readerThemeCustomChanges[ReaderTheme.folio.rawValue])
        #expect(folioChanges.font == .georgia)
        #expect(folioChanges.marginPoints == 40)
    }

    /// Clearing a field (the row's undo arrow) or setting it back to the preset's value removes
    /// that edit; when nothing is left the preset has no entry
    @Test func updateBackToPresetRemovesTheEdit() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)
        store.updateReaderThemeCustomChanges(for: .folio) { $0.font = .georgia }
        store.updateReaderThemeCustomChanges(for: .folio) { $0.marginPoints = 40 }

        // undo arrow on the Font row
        store.updateReaderThemeCustomChanges(for: .folio) { $0.font = nil }
        #expect(store.readerThemeCustomChanges[ReaderTheme.folio.rawValue]?.font == nil)
        #expect(store.readerThemeCustomChanges[ReaderTheme.folio.rawValue]?.marginPoints == 40)

        // slider dragged back to Folio's own 24
        store.updateReaderThemeCustomChanges(for: .folio) { $0.marginPoints = 24 }
        #expect(store.readerThemeCustomChanges[ReaderTheme.folio.rawValue] == nil)
    }

    /// Reset removes one preset's edits only; other presets and the text size step stay
    @Test func resetRemovesOnlyThatPreset() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)
        store.updateReaderThemeCustomChanges(for: .folio) { $0.font = .georgia }
        store.updateReaderThemeCustomChanges(for: .ink) { $0.lineSpacingPercent = 160 }
        store.readerTextSizeStep = 2

        store.resetReaderThemeCustomChanges(for: .folio)

        #expect(store.readerThemeCustomChanges[ReaderTheme.folio.rawValue] == nil)
        #expect(store.readerThemeCustomChanges[ReaderTheme.ink.rawValue]?.lineSpacingPercent == 160)
        #expect(store.readerTextSizeStep == 2)
        #expect(PreferencesStore(userDefaults: userDefaults).readerThemeCustomChanges[ReaderTheme.folio.rawValue] == nil)
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
        store.replaceReaderThemeCustomChanges(ReaderThemeCustom(fontWeight: .regular), for: .ink)

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
        preferencesStore.replaceReaderThemeCustomChanges(ReaderThemeCustom(fontWeight: .bold), for: .linen)

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
        store.replaceReaderThemeCustomChanges(ReaderThemeCustom(fontWeight: .regular), for: .ink)

        #expect(String(localized: store.readerThemeResolved(for: .ink).displayName) == "Ink*")
        #expect(String(localized: store.readerThemeResolved(for: .linen).displayName) == "Linen")
    }

    /// Clearing a preset's changes removes its `*`
    @Test func clearedChangesRemoveDisplayNameMarker() throws {
        let suiteName = UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        let store = PreferencesStore(userDefaults: userDefaults)
        store.replaceReaderThemeCustomChanges(ReaderThemeCustom(fontWeight: .regular), for: .ink)
        store.replaceReaderThemeCustomChanges(ReaderThemeCustom(), for: .ink)

        #expect(String(localized: store.readerThemeResolved(for: .ink).displayName) == "Ink")
    }

    // MARK: Private Helpers

    private func testPosition() -> ReaderPosition {
        ReaderPosition(translationID: 1849, bookCode: "JHN", chapter: 3)
    }
}
