//
//  CatalogCacheEntry.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-10-31.
//

import Foundation

/// Cache entry which contains contents, save date, save build number
/// - Codable used for DiskCatalogCache
nonisolated struct CatalogCacheEntry<Value: Codable>: Codable {

    let value: Value
    let createdOn: Date
    let createdByBuildNumber: String

    /// Is this entry less than 7 days old AND was it saved using the current app build?
    ///
    /// (now:) and (currentBuildNumber:) params needed for unit tests
    func isEntryFresh(_ now: Date,
                      maximumAgeInDays: Int,
                      currentBuildNumber: String?) -> Bool {
        // Saved "in the future" means the clock moved; don't trust the entry
        if createdOn > now { return false }

        let ageInDays = Calendar.current.dateComponents([.day], from: createdOn, to: now).day ?? 0
        let isTooOld = ageInDays >= maximumAgeInDays

        let isSameBuild = createdByBuildNumber == currentBuildNumber

        return !isTooOld && isSameBuild
    }
}
