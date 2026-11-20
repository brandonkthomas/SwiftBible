//
//  NetworkMonitor.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-20.
//

import Foundation
import Network
import Observation

/// Live network status from system path monitor
///
/// NWPathMonitor reads "unsatisfied" until first update (~1 ms after startup), so
/// isOnline will wait for this first reading instead of reporting offline at launch
@Observable
final class NetworkMonitor: NetworkStatusProviding {

    // MARK: Properties

    /// nil = no reading yet; observed by views that reload when the connection changes
    private(set) var isConnected: Bool?

    // MARK: Properties (Private)

    /// Callers of isOnline waiting for the first reading
    @ObservationIgnored private var firstReadingWaiters: [CheckedContinuation<Bool, Never>] = []

    /// Loop over the system path monitor; nil until start()
    @ObservationIgnored private var monitoringTask: Task<Void, Never>?

    // MARK: Properties (NetworkStatusProviding)

    /// The latest reading, or the first one once it arrives
    var isOnline: Bool {
        get async {
            if let isConnected {
                return isConnected
            }

            return await withCheckedContinuation { continuation in
                firstReadingWaiters.append(continuation)
            }
        }
    }

    // MARK: Functions

    /// Starts following the system's network path; later calls do nothing
    func start() {
        guard monitoringTask == nil else {
            return
        }

        // iterating starts NWPathMonitor's AsyncSequence... each path is one reading
        monitoringTask = Task {
            for await path in NWPathMonitor() {
                record(isConnected: path.status == .satisfied)
            }
        }
    }

    /// Saves reading & answers everyone waiting for the initial one
    func record(isConnected: Bool) {
        self.isConnected = isConnected

        // each continuation must be resumed exactly once!
        let waiters = firstReadingWaiters
        firstReadingWaiters = []

        for waiter in waiters {
            waiter.resume(returning: isConnected)
        }
    }
}
