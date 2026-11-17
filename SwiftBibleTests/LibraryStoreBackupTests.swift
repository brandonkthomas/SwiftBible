//
//  LibraryStoreBackupTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-16.
//

import Foundation
import Testing
@testable import SwiftBible

/// Before a new build opens (and possibly migrates) the store, a copy of the store files is
/// kept, so a later update can restore data a bad migration lost.
/// The store files here are plain bytes: copying never opens them as SQLite.
@MainActor
struct LibraryStoreBackupTests {

    /// Mirrors LibraryStoreBackup's private key
    private static let lastBuildNumberKey = "net.brandonthomas.SwiftBible.lastStoreBuildNumber"

    /// a new build copies the store and both sidecar files into a folder named after the build that wrote them
    @Test func copiesStoreFilesWhenBuildChanges() throws {
        let (directoryURL, userDefaults, suiteName) = try makeEnvironment()
        defer { cleanUp(directoryURL, suiteName) }
        let storeURL = try writeStoreFiles(in: directoryURL)
        userDefaults.set("10", forKey: Self.lastBuildNumberKey)

        let backup = makeBackup(storeURL: storeURL, directoryURL: directoryURL, userDefaults: userDefaults)
        let backupFolder = try #require(try backup.backUpIfBuildChanged(currentBuildNumber: "11"))

        #expect(backupFolder.lastPathComponent == "build-10")
        for name in ["default.store", "default.store-wal", "default.store-shm"] {
            let copied = try Data(contentsOf: backupFolder.appending(path: name))
            #expect(copied == Data(name.utf8))
        }
    }

    /// the same build launching again copies nothing; a store from before this feature
    /// (no build recorded) is copied once, as "build-unknown"
    @Test func copiesOncePerBuild() throws {
        let (directoryURL, userDefaults, suiteName) = try makeEnvironment()
        defer { cleanUp(directoryURL, suiteName) }
        let storeURL = try writeStoreFiles(in: directoryURL)
        let backup = makeBackup(storeURL: storeURL, directoryURL: directoryURL, userDefaults: userDefaults)

        let first = try backup.backUpIfBuildChanged(currentBuildNumber: "11")
        let second = try backup.backUpIfBuildChanged(currentBuildNumber: "11")

        #expect(first?.lastPathComponent == "build-unknown")
        #expect(second == nil)
    }

    /// a fresh install (no store yet) copies nothing but still records the build,
    /// so the next build backs up the store this one creates
    @Test func freshInstallRecordsBuildWithoutCopying() throws {
        let (directoryURL, userDefaults, suiteName) = try makeEnvironment()
        defer { cleanUp(directoryURL, suiteName) }
        let storeURL = directoryURL.appending(path: "Store").appending(path: "default.store")
        let backup = makeBackup(storeURL: storeURL, directoryURL: directoryURL, userDefaults: userDefaults)

        let onFreshInstall = try backup.backUpIfBuildChanged(currentBuildNumber: "11")
        _ = try writeStoreFiles(in: directoryURL)
        let onNextBuild = try backup.backUpIfBuildChanged(currentBuildNumber: "12")

        #expect(onFreshInstall == nil)
        #expect(onNextBuild?.lastPathComponent == "build-11")
    }

    // MARK: Keeping the Newest Two

    /// four build changes leave only the two newest backup folders
    @Test func keepsNewestTwoBackups() throws {
        let (directoryURL, userDefaults, suiteName) = try makeEnvironment()
        defer { cleanUp(directoryURL, suiteName) }
        let storeURL = try writeStoreFiles(in: directoryURL)
        userDefaults.set("10", forKey: Self.lastBuildNumberKey)
        let backup = makeBackup(storeURL: storeURL, directoryURL: directoryURL, userDefaults: userDefaults)

        for build in ["11", "12", "13"] {
            _ = try backup.backUpIfBuildChanged(currentBuildNumber: build)
        }

        #expect(try backupFolderNames(in: directoryURL) == ["build-11", "build-12"])
    }

    /// build numbers sort as numbers (99 is newer than 10, 10 newer than 9); "unknown" is the oldest.
    /// Folders are created out of order so creation dates can't stand in for build order
    @Test func ordersBuildNumbersNumerically() throws {
        let (directoryURL, userDefaults, suiteName) = try makeEnvironment()
        defer { cleanUp(directoryURL, suiteName) }
        let storeURL = try writeStoreFiles(in: directoryURL)
        for name in ["build-10", "build-unknown", "build-9"] {
            try makeBackupFolder(named: name, in: directoryURL)
        }
        userDefaults.set("99", forKey: Self.lastBuildNumberKey)
        let backup = makeBackup(storeURL: storeURL, directoryURL: directoryURL, userDefaults: userDefaults)

        _ = try backup.backUpIfBuildChanged(currentBuildNumber: "100")

        #expect(try backupFolderNames(in: directoryURL) == ["build-10", "build-99"])
    }

    /// only "build-" folders are pruned; anything else in the backups directory is left alone
    @Test func pruningLeavesOtherItems() throws {
        let (directoryURL, userDefaults, suiteName) = try makeEnvironment()
        defer { cleanUp(directoryURL, suiteName) }
        let storeURL = try writeStoreFiles(in: directoryURL)
        for name in ["build-1", "build-2"] {
            try makeBackupFolder(named: name, in: directoryURL)
        }
        let otherFileURL = backupsDirectory(in: directoryURL).appending(path: "notes.txt")
        try Data("keep".utf8).write(to: otherFileURL)
        userDefaults.set("3", forKey: Self.lastBuildNumberKey)
        let backup = makeBackup(storeURL: storeURL, directoryURL: directoryURL, userDefaults: userDefaults)

        _ = try backup.backUpIfBuildChanged(currentBuildNumber: "4")

        #expect(try backupFolderNames(in: directoryURL) == ["build-2", "build-3"])
        #expect(FileManager.default.fileExists(atPath: otherFileURL.path(percentEncoded: false)))
    }

    // MARK: Functions (Private)

    private func backupsDirectory(in directoryURL: URL) -> URL {
        directoryURL.appending(path: "Backups", directoryHint: .isDirectory)
    }

    private func makeBackupFolder(named name: String, in directoryURL: URL) throws {
        try FileManager.default.createDirectory(at: backupsDirectory(in: directoryURL).appending(path: name),
                                                withIntermediateDirectories: true)
    }

    /// "build-" folder names in the backups directory, sorted as numbers for comparison
    private func backupFolderNames(in directoryURL: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: backupsDirectory(in: directoryURL).path(percentEncoded: false))
            .filter { $0.hasPrefix("build-") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func makeEnvironment() throws -> (URL, UserDefaults, String) {
        let directoryURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let suiteName = UUID().uuidString
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))

        return (directoryURL, userDefaults, suiteName)
    }

    private func cleanUp(_ directoryURL: URL, _ suiteName: String) {
        try? FileManager.default.removeItem(at: directoryURL)
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    /// stand-in store files whose contents are their own names
    private func writeStoreFiles(in directoryURL: URL) throws -> URL {
        let storeDirectory = directoryURL.appending(path: "Store",
                                                    directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: storeDirectory,
                                                withIntermediateDirectories: true)

        for name in ["default.store", "default.store-wal", "default.store-shm"] {
            try Data(name.utf8).write(to: storeDirectory.appending(path: name))
        }

        return storeDirectory.appending(path: "default.store")
    }

    private func makeBackup(storeURL: URL,
                            directoryURL: URL,
                            userDefaults: UserDefaults) -> LibraryStoreBackup {
        LibraryStoreBackup(storeURL: storeURL,
                           backupsDirectory: directoryURL.appending(path: "Backups",
                                                                    directoryHint: .isDirectory),
                           userDefaults: userDefaults)
    }
}
