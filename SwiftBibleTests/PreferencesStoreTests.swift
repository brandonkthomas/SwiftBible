//
//  PreferencesStoreTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-10-23.
//

import Testing
import Foundation
@testable import SwiftBible

@MainActor
struct PreferencesStoreTests {

    /// Mirrors PreferencesStore's private key; repeated here so the store's key can stay private
    private static let readerPositionKey = "net.brandonthomas.SwiftBible.readerPosition"

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

    // MARK: Private Helpers

    private func testPosition() -> ReaderPosition {
        ReaderPosition(translationID: 1849, bookCode: "JHN", chapter: 3)
    }
}
