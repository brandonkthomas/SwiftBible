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

    // MARK: Private Helpers

    private func testPosition() -> ReaderPosition {
        ReaderPosition(translationID: 1849, bookCode: "JHN", chapter: 3)
    }
}
