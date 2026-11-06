//
//  AppConfigurationTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-05.
//

import Foundation
import Testing
@testable import SwiftBible

struct AppConfigurationTests {

    // MARK: Tyndale key

    @Test func tyndaleKeyIsReadAndTrimmed() throws {
        let configuration = try makeConfiguration(secrets: ["TYNDALE_APP_KEY": "  tyndale-key\n"])

        #expect(configuration.tyndaleApiKey == "tyndale-key")
    }

    /// Empty, whitespace, and the unexpanded build-setting placeholder all mean "no key"
    @Test(arguments: ["", "   ", "$(TYNDALE_APP_KEY)"])
    func unusableTyndaleKeyIsNil(value: String) throws {
        let configuration = try makeConfiguration(secrets: ["TYNDALE_APP_KEY": value])

        #expect(configuration.tyndaleApiKey == nil)
    }

    /// A missing Tyndale key must not affect the YouVersion key
    @Test func keysAreReadIndependently() throws {
        let configuration = try makeConfiguration(secrets: ["YOUVERSION_APP_KEY": "youversion-key"])

        #expect(configuration.youVersionApiKey == "youversion-key")
        #expect(configuration.tyndaleApiKey == nil)
    }

    @Test func missingSecretsFileLeavesAllKeysNil() throws {
        let configuration = AppConfiguration(bundle: try makeBundle(secrets: nil))

        #expect(configuration.youVersionApiKey == nil)
        #expect(configuration.tyndaleApiKey == nil)
        #expect(configuration.crosswayApiKey == nil)
    }

    // MARK: Crossway key

    @Test func crosswayKeyIsReadAndTrimmed() throws {
        let configuration = try makeConfiguration(secrets: ["CROSSWAY_APP_KEY": " crossway-key "])

        #expect(configuration.crosswayApiKey == "crossway-key")
        #expect(configuration.crosswayBaseURL.absoluteString == "https://api.esv.org")
    }

    @Test func tyndaleBaseURLDefaultsToNLTAPI() throws {
        let configuration = try makeConfiguration(secrets: [:])

        #expect(configuration.tyndaleBaseURL.absoluteString == "https://api.nlt.to")
    }

    // MARK: Functions (Private Helpers)

    private func makeConfiguration(secrets: [String: String]) throws -> AppConfiguration {
        AppConfiguration(bundle: try makeBundle(secrets: secrets))
    }

    /// A bundle in a fresh temp directory, with a Secrets.plist when secrets is non-nil
    private func makeBundle(secrets: [String: String]?) throws -> Bundle {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if let secrets {
            let data = try PropertyListSerialization.data(fromPropertyList: secrets,
                                                          format: .xml,
                                                          options: 0)
            try data.write(to: directory.appending(path: "Secrets.plist"))
        }

        return try #require(Bundle(url: directory))
    }
}
