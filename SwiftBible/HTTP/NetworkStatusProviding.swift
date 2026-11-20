//
//  NetworkStatusProviding.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-19.
//

import Foundation

/// Consumed by NetworkMonitor
protocol NetworkStatusProviding: AnyObject {
    var isOnline: Bool { get async }
}
