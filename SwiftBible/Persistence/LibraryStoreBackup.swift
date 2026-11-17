//
//  LibraryStoreBackup.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-16.
//

import Foundation

struct LibraryStoreBackup {
    /// What's the store's path?
    let storeURL: URL

    /// What's the backup directory path?
    let backupsDirectory: URL

    /// Required UserDefaults instance
    let userDefaults: UserDefaults

    /// Stable UserDefaults key
    private static let lastStoreBuildNumber = "net.brandonthomas.SwiftBible.lastStoreBuildNumber"

    // MARK: Functions

    /// If we're running on a new build, backup the current SwiftData database
    func backUpIfBuildChanged(currentBuildNumber: String) throws -> URL? {
        let fileManager = FileManager.default

        let lastBuildNumber = userDefaults.string(forKey: Self.lastStoreBuildNumber)
        guard currentBuildNumber != lastBuildNumber else {
            return nil
        }

        // Do we have a backup folder?
        var backupFolder: URL?
        if fileManager.fileExists(atPath: storeURL.path(percentEncoded: false)) {
            let folder = backupsDirectory.appending(path: "build-\(lastBuildNumber ?? "unknown")",
                                                    directoryHint: .isDirectory)
            // a failed earlier attempt may have left a partial copy; copyItem won't overwrite
            try? fileManager.removeItem(at: folder)
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

            // build store file URLs
            // store + its SQLite sidecar files (-wal holds recent writes, -shm is its index)
            let directory = storeURL.deletingLastPathComponent()
            let name = storeURL.lastPathComponent
            let storeFileURLs = [
                storeURL,
                directory.appending(path: name + "-wal"),
                directory.appending(path: name + "-shm")
            ]

            // backup each file
            for fileURL in storeFileURLs where fileManager.fileExists(atPath: fileURL.path(percentEncoded: false)) {
                try fileManager.copyItem(at: fileURL, to: folder.appending(path: fileURL.lastPathComponent))
            }
            // pruning failure shouldn't fail the backup that just succeeded
            try? removeOldBackups()
            backupFolder = folder
        }

        userDefaults.set(currentBuildNumber, forKey: Self.lastStoreBuildNumber)
        return backupFolder
    }

    /// `build-*` backup folders, newest build first
    ///
    /// Ordered by the build number in the name, not file dates: restoring a device from an
    /// iCloud backup can give every folder a new creation date. `build-unknown` (a store from
    /// before backups existed) is the oldest.
    func backupFolders() throws -> [URL] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: backupsDirectory.path(percentEncoded: false)) else {
            return []
        }

        let prefix = "build-"
        let contents = try fileManager.contentsOfDirectory(at: backupsDirectory,
                                                           includingPropertiesForKeys: [.isDirectoryKey],
                                                           options: .skipsHiddenFiles)
        let folders = contents.compactMap { url -> (url: URL, buildNumber: Int)? in
            let name = url.lastPathComponent
            guard name.hasPrefix(prefix),
                  (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                return nil
            }
            // "unknown" (or anything not a number) sorts below every real build
            return (url, Int(name.dropFirst(prefix.count)) ?? -1)
        }
        return folders
            .sorted { $0.buildNumber > $1.buildNumber }
            .map(\.url)
    }

    /// Keep only the 2 newest backups
    private func removeOldBackups() throws {
        let fileManager = FileManager.default
        for folder in try backupFolders().dropFirst(2) {
            try fileManager.removeItem(at: folder)
        }
    }
}
