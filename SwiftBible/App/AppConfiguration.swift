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

    let tyndaleApiKey: String?
    let tyndaleBaseURL: URL

    static let defaultYouVersionBaseURL = URL(string: "https://api.youversion.com")!
    static let defaultTyndaleBaseURL = URL(string: "https://api.nlt.to")!
    private static let secretsResourceName = "Secrets"
    private static let youVersionApiKeyName = "YOUVERSION_APP_KEY"
    private static let tyndaleApiKeyName = "TYNDALE_APP_KEY"

    init(bundle: Bundle = .main,
         youVersionBaseURL: URL = Self.defaultYouVersionBaseURL,
         tyndaleBaseURL: URL = Self.defaultTyndaleBaseURL) {
        self.youVersionBaseURL = youVersionBaseURL
        self.tyndaleBaseURL = tyndaleBaseURL

        self.youVersionApiKey = Self.apiKey(named: Self.youVersionApiKeyName, in: bundle)
        self.tyndaleApiKey = Self.apiKey(named: Self.tyndaleApiKeyName, in: bundle)
    }

    /// Retrieve a trimmed API key from Secrets.plist
    ///
    /// Returns nil when the key is missing, empty, or still the unexpanded "$(NAME)" placeholder.
    private static func apiKey(named key: String, in bundle: Bundle) -> String? {
        let rawApiKey = secretString(named: key, in: bundle)
        let trimmedApiKey = rawApiKey?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let trimmedApiKey,
              !trimmedApiKey.isEmpty,
              trimmedApiKey != "$(\(key))" else {
            return nil
        }

        return trimmedApiKey
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
