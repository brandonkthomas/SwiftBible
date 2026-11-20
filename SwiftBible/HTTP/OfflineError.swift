//
//  OfflineError.swift
//  SwiftBible
//

import Foundation

extension Error {

    /// Did this fail because the device has no usable connection?
    ///
    /// - True for the online-only passage check and for URLSession's "no connection" errors
    /// - Views show "offline" for these instead of generic failure +  reload on reconnect
    nonisolated var isOfflineError: Bool {
        if let passageStoreError = self as? BiblePassageStoreError,
           passageStoreError == .offline {
            return true
        }

        guard let urlError = self as? URLError else {
            return false
        }

        switch urlError.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .dataNotAllowed,
             .internationalRoamingOff,
             .cannotFindHost,
             .cannotConnectToHost,
             .timedOut:
            return true
        default:
            return false
        }
    }
}
