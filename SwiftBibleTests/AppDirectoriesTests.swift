//
//  AppDirectoriesTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-20.
//

import Foundation
import Testing
@testable import SwiftBible

/// Every file the app writes lives under one app-named folder inside Application Support or
/// Caches, never loose at their roots. A non-sandboxed process (e.g. a macOS probe) shares
/// those roots with every other app, so a loose `default.store` can collide.
@MainActor
struct AppDirectoriesTests {

    /// the folder name is the app's bundle identifier; hosted tests run inside the app, so
    /// Bundle.main is SwiftBible. A hard-coded name keeps the store path fixed, and this test
    /// catches it drifting from the real identifier
    @Test func folderNameIsBundleIdentifier() {
        #expect(AppDirectories.folderName == Bundle.main.bundleIdentifier)
    }

    /// Application Support files go in the app's own subfolder, not the Application Support root
    @Test func applicationSupportIsAppSubfolder() {
        let expected = URL.applicationSupportDirectory
            .appending(path: "net.brandonthomas.SwiftBible", directoryHint: .isDirectory)

        #expect(AppDirectories.applicationSupport == expected)
    }

    /// Cache files go in the app's own subfolder, not the Caches root
    @Test func cachesIsAppSubfolder() {
        let expected = URL.cachesDirectory
            .appending(path: "net.brandonthomas.SwiftBible", directoryHint: .isDirectory)

        #expect(AppDirectories.caches == expected)
    }

    /// the SwiftData store is a file named Library.store inside the app's Application Support
    /// folder; SwiftData names its sidecar files (-wal, -shm, Library_ckAssets) after it
    @Test func libraryStoreIsInsideApplicationSupport() {
        let expected = URL.applicationSupportDirectory
            .appending(path: "net.brandonthomas.SwiftBible", directoryHint: .isDirectory)
            .appending(path: "Library.store", directoryHint: .notDirectory)

        #expect(AppDirectories.libraryStore == expected)
    }

    /// store backups sit next to the store, in their own folder
    @Test func libraryStoreBackupsIsInsideApplicationSupport() {
        let expected = URL.applicationSupportDirectory
            .appending(path: "net.brandonthomas.SwiftBible", directoryHint: .isDirectory)
            .appending(path: "LibraryStoreBackups", directoryHint: .isDirectory)

        #expect(AppDirectories.libraryStoreBackups == expected)
    }
}
