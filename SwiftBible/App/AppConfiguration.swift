//
//  AppConfiguration.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/28/26.
//

import Foundation

struct AppConfiguration {

    let youVersionApiKey: String?
    let youVersionBaseURL: URL

    static let defaultYouVersionBaseURL = URL(string: "https://api.youversion.com")!

    init(bundle: Bundle = .main,
         youVersionBaseURL: URL = Self.defaultYouVersionBaseURL) {
        self.youVersionBaseURL = youVersionBaseURL

        let rawApiKey = bundle.object(forInfoDictionaryKey: "YOUVERSION_APP_KEY") as? String
        let trimmedApiKey = rawApiKey?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmedApiKey,
           !trimmedApiKey.isEmpty,
           trimmedApiKey != "$(YOUVERSION_APP_KEY)" {
            self.youVersionApiKey = trimmedApiKey
        } else {
            self.youVersionApiKey = nil
        }
    }
}
