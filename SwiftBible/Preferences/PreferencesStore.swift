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

    // MARK: Properties

    /// Last-used reader position (if any)
    ///
    /// Automatically calls UserDefaults.set/remove on any modification
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
    ///
    /// Automatically calls UserDefaults.set/remove on any modification
    var readerTheme: ReaderTheme = .default {
        didSet {
            userDefaults.set(readerTheme.rawValue, forKey: Self.readerThemeKey)
        }
    }

    // MARK: Properties (Private)

    /// Provided UserDefaults instance
    private let userDefaults: UserDefaults

    /// Stable UserDefaults key for ReaderPosition storage
    private static let readerPositionKey = "net.brandonthomas.SwiftBible.readerPosition"

    /// Stable UserDefaults key for ReaderTheme storage
    private static let readerThemeKey = "net.brandonthomas.SwiftBible.readerTheme"

    private static let logger = Logger(subsystem: "SwiftBible", category: "PreferencesStore")

    // MARK: Init

    /// Stores UserDefaults in-instance and tries to load saved ReaderPosition
    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults

        // try to retrieve any saved Reader position
        if let savedPositionData = userDefaults.data(forKey: Self.readerPositionKey),
           let savedPosition = try? JSONDecoder().decode(ReaderPosition.self, from: savedPositionData) {
            self.readerPosition = savedPosition
        }

        // try to retrieve any saved Reader theme
        if let savedThemeString = userDefaults.string(forKey: Self.readerThemeKey),
           let savedTheme = ReaderTheme.preset(withID: savedThemeString) {
            self.readerTheme = savedTheme
        }
    }

    // MARK: Functions


}
