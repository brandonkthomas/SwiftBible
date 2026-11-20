//
//  OfflineErrorTests.swift
//  SwiftBibleTests
//

import Foundation
import Testing
@testable import SwiftBible

/// Which errors count as "no connection" (offline message + reload on reconnect)
@MainActor
struct OfflineErrorTests {

    @Test(arguments: [URLError.Code.notConnectedToInternet,
                      .networkConnectionLost,
                      .dataNotAllowed,
                      .timedOut])
    func noConnectionURLErrorsAreOffline(code: URLError.Code) {
        #expect(URLError(code).isOfflineError)
    }

    @Test func onlinePassageCheckIsOffline() {
        #expect(BiblePassageStoreError.offline.isOfflineError)
    }

    @Test func otherErrorsAreNotOffline() {
        #expect(URLError(.badServerResponse).isOfflineError == false)
        #expect(BiblePassageStoreError.invalidBiblePassageKey.isOfflineError == false)
    }
}
