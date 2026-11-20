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

    let crosswayApiKey: String?
    let crosswayBaseURL: URL

    static let defaultYouVersionBaseURL = URL(string: "https://api.youversion.com")!
    static let defaultCrosswayBaseURL = URL(string: "https://api.esv.org")!
    private static let secretsResourceName = "Secrets"
    private static let youVersionApiKeyName = "YOUVERSION_APP_KEY"
    private static let crosswayApiKeyName = "CROSSWAY_APP_KEY"

    init(bundle: Bundle = .main,
         youVersionBaseURL: URL = Self.defaultYouVersionBaseURL,
         crosswayBaseURL: URL = Self.defaultCrosswayBaseURL) {
        self.youVersionBaseURL = youVersionBaseURL
        self.crosswayBaseURL = crosswayBaseURL

        self.youVersionApiKey = Self.apiKey(named: Self.youVersionApiKeyName, in: bundle)
        self.crosswayApiKey = Self.apiKey(named: Self.crosswayApiKeyName, in: bundle)
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
