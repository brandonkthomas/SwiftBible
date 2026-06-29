//
//  AppEnvironment.swift
//  HomePlus
//
//  Created by Brandon Thomas on 6/27/26.
//

import Foundation
import Observation

/// App-wide owner of our single repository
///
/// This is our composition root:
/// - SwiftBibleApp creates one AppEnvironment()
/// - AppEnvironment creates/reads AppConfiguration
/// - AppEnvironment uses that config to choose/create repositories
/// - SwiftBibleApp injects only the view-facing objects, currently readerStore
@Observable
final class AppEnvironment {

    // MARK: Properties

    let readerStore: ReaderStore
    let appConfiguration: AppConfiguration

    // MARK: Init

    init() {
        let appConfiguration = AppConfiguration()
        self.appConfiguration = appConfiguration

        guard let apiKey = appConfiguration.youVersionApiKey else {
            preconditionFailure("Missing YOUVERSION_APP_KEY in bundled Secrets.plist")
        }

        let repository = YouVersionBibleRepository(apiKey: apiKey,
                                                   baseURL: appConfiguration.youVersionBaseURL,
                                                   urlSession: .shared)
        self.readerStore = ReaderStore(repository: repository)
    }
}
