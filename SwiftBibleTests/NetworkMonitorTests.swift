//
//  NetworkMonitorTests.swift
//  SwiftBibleTests
//

import Testing
@testable import SwiftBible

/// Readings are fed in with record(isConnected:); start() (the real path monitor) is never called
@MainActor
struct NetworkMonitorTests {

    /// Before the first reading the status is unknown, not offline
    @Test func statusIsUnknownUntilFirstReading() {
        let monitor = NetworkMonitor()
        #expect(monitor.isConnected == nil)

        monitor.record(isConnected: true)

        #expect(monitor.isConnected == true)
    }

    /// A read before the first reading waits for it instead of answering "offline"
    @Test func isOnlineWaitsForFirstReading() async {
        let monitor = NetworkMonitor()
        let earlyRead = Task { await monitor.isOnline }
        await Task.yield()

        monitor.record(isConnected: true)

        #expect(await earlyRead.value == true)
    }

    /// After the first reading, isOnline answers with the latest one
    @Test func isOnlineReturnsLatestReading() async {
        let monitor = NetworkMonitor()

        monitor.record(isConnected: true)
        monitor.record(isConnected: false)

        #expect(await monitor.isOnline == false)
    }
}
