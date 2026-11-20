//
//  AppDirectories.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-20.
//

import Foundation

/// Collection of frozen app directories for DB storage, caches, etc
nonisolated enum AppDirectories {
    /// bundle ID is currently used for all of our folder names;
    /// not reading from Bundle.main because we want to freeze this
    static let folderName: String = "net.brandonthomas.SwiftBible"

    /// Sandboxed "/Library/Application Support/net.brandonthomas.SwiftBible/" path
    static var applicationSupport: URL {
        URL.applicationSupportDirectory
            .appending(path: folderName, directoryHint: .isDirectory)
    }

    /// Sandboxed "/Library/Caches/net.brandonthomas.SwiftBible/" path
    static var caches: URL {
        URL.cachesDirectory
            .appending(path: folderName, directoryHint: .isDirectory)
    }

    /// Sandboxed "/Library/Application Support/net.brandonthomas.SwiftBible/Library.store" filepath
    static var libraryStore: URL {
        applicationSupport
            .appending(path: "Library.store")
    }

    /// Sandboxed "/Library/Application Support/net.brandonthomas.SwiftBible/LibraryStoreBackups/" path
    static var libraryStoreBackups: URL {
        applicationSupport
            .appending(path: "LibraryStoreBackups", directoryHint: .isDirectory)
    }
}
