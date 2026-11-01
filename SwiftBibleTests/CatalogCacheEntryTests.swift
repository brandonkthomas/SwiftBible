//
//  CatalogCacheEntryTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-10-31.
//

import Testing
import Foundation
@testable import SwiftBible

struct CatalogCacheEntryTests {

    // MARK: Age

    /// An entry saved recently by the same build is fresh
    @Test func recentEntryFromSameBuildIsFresh() {
        let entry = makeEntry(createdOn: date(daysBeforeNow: 1))

        #expect(entry.isEntryFresh(now,
                                   maximumAgeInDays: 7,
                                   currentBuildNumber: buildNumber))
    }

    /// An entry older than the limit is stale
    @Test func entryOlderThanLimitIsStale() {
        let entry = makeEntry(createdOn: date(daysBeforeNow: 30))

        #expect(!entry.isEntryFresh(now,
                                    maximumAgeInDays: 7,
                                    currentBuildNumber: buildNumber))
    }

    /// An entry exactly 7 days old is stale (limit is exclusive)
    @Test func entryExactlyAtLimitIsStale() {
        let entry = makeEntry(createdOn: date(daysBeforeNow: 7))

        #expect(!entry.isEntryFresh(now,
                                    maximumAgeInDays: 7,
                                    currentBuildNumber: buildNumber))
    }

    /// An entry dated after "now" (clock moved backward) is stale
    @Test func entrySavedInFutureIsStale() {
        let entry = makeEntry(createdOn: date(daysBeforeNow: -1))

        #expect(!entry.isEntryFresh(now,
                                    maximumAgeInDays: 7,
                                    currentBuildNumber: buildNumber))
    }

    // MARK: Build number

    /// An entry saved by a different build is stale even if recent
    @Test func entryFromDifferentBuildIsStale() {
        let entry = makeEntry(createdOn: date(daysBeforeNow: 1), buildNumber: "41")

        #expect(!entry.isEntryFresh(now,
                                    maximumAgeInDays: 7,
                                    currentBuildNumber: buildNumber))
    }

    /// If the current build number can't be read, the entry is stale
    @Test func unknownCurrentBuildIsStale() {
        let entry = makeEntry(createdOn: date(daysBeforeNow: 1))

        #expect(!entry.isEntryFresh(now,
                                    maximumAgeInDays: 7,
                                    currentBuildNumber: nil))
    }

    // MARK: Codable

    /// Encoding then decoding keeps value, createdOn, and createdByBuildNumber
    @Test func encodeDecodeRoundTripKeepsAllProperties() throws {
        let entry = makeEntry(createdOn: date(daysBeforeNow: 2))

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(CatalogCacheEntry<[String]>.self, from: data)

        #expect(decoded.value == entry.value)
        #expect(decoded.createdOn == entry.createdOn)
        #expect(decoded.createdByBuildNumber == entry.createdByBuildNumber)
    }

    /// Fixed "now" so tests don't depend on the wall clock
    private let now = Date(timeIntervalSinceReferenceDate: 815_000_000)
    private let buildNumber = "42"

    /// Builds entry dates with calendar days (not seconds) so DST shifts can't change the day count
    private func date(daysBeforeNow days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
    }

    private func makeEntry(createdOn: Date, buildNumber: String? = nil) -> CatalogCacheEntry<[String]> {
        CatalogCacheEntry(value: ["GEN", "EXO"],
                          createdOn: createdOn,
                          createdByBuildNumber: buildNumber ?? self.buildNumber)
    }
}
