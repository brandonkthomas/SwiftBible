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
    private static let secretsResourceName = "Secrets"
    private static let youVersionApiKeyName = "YOUVERSION_APP_KEY"

    init(bundle: Bundle = .main,
         youVersionBaseURL: URL = Self.defaultYouVersionBaseURL) {
        self.youVersionBaseURL = youVersionBaseURL

        let rawApiKey = Self.secretString(named: Self.youVersionApiKeyName, in: bundle)
        let trimmedApiKey = rawApiKey?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmedApiKey,
           !trimmedApiKey.isEmpty,
           trimmedApiKey != "$(\(Self.youVersionApiKeyName))" {
            self.youVersionApiKey = trimmedApiKey
        } else {
            self.youVersionApiKey = nil
        }
    }

    /// Retrieve a string from Secrets.plist
    private static func secretString(named key: String, in bundle: Bundle) -> String? {
        guard let secretsURL = bundle.url(forResource: secretsResourceName, withExtension: "plist"),
              let secrets = NSDictionary(contentsOf: secretsURL) as? [String: Any] else {
            return nil
        }

        return secrets[key] as? String
    }
}
