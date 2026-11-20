//
//  FakeNetworkStatus.swift
//  SwiftBibleTests
//

@testable import SwiftBible

/// Network status a test can switch on and off; online by default
@MainActor
final class FakeNetworkStatus: NetworkStatusProviding {
    var isOnline = true
}
