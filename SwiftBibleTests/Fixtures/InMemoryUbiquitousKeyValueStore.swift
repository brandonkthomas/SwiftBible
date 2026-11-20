//
//  InMemoryUbiquitousKeyValueStore.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-17.
//

import Foundation
@testable import SwiftBible

/// Stands in for `NSUbiquitousKeyValueStore` so tests never read or write real iCloud.
/// `values` exposes everything stored; `writeCount` counts writes made through the protocol
/// (values passed to `init` stand in for another device's writes and aren't counted).
final class InMemoryUbiquitousKeyValueStore: UbiquitousKeyValueStoring {

    private(set) var values: [String: Any]
    private(set) var writeCount = 0
    private(set) var synchronizeCount = 0

    init(values: [String: Any] = [:]) {
        self.values = values
    }

    func object(forKey key: String) -> Any? {
        values[key]
    }

    func set(_ value: Any?, forKey key: String) {
        values[key] = value
        writeCount += 1
    }

    func removeObject(forKey key: String) {
        values[key] = nil
        writeCount += 1
    }

    func synchronize() -> Bool {
        synchronizeCount += 1
        return true
    }

    /// Stands in for another device's write arriving after launch; not counted in `writeCount`
    func receiveRemoteValue(_ value: Any, forKey key: String) {
        values[key] = value
    }
}
