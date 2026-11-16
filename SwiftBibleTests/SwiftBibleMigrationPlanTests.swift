//
//  SwiftBibleMigrationPlanTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-16.
//

import Foundation
import Testing
import SwiftData
@testable import SwiftBible

struct SwiftBibleMigrationPlanTests {

    /// the plan lists every schema version oldest first; today that is only V1
    @Test func schemasStartAtV1() {
        let versions = SwiftBibleMigrationPlan.schemas.map { $0.versionIdentifier }

        #expect(versions == [Schema.Version(1, 0, 0)])
    }

    /// one version means nothing to migrate between
    @Test func hasNoStagesWhileOnlyV1() {
        #expect(SwiftBibleMigrationPlan.stages.isEmpty)
    }

    /// a store saved before the plan existed opens through the plan with its rows intact
    @Test func existingStoreOpensWithPlan() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let storeURL = directoryURL.appending(path: "Library.store")
        let schema = Schema([StoredVerseAnnotation.self, StoredTag.self])
        let modelConfiguration = ModelConfiguration(schema: schema,
                                                    url: storeURL,
                                                    cloudKitDatabase: .none)
        let annotationID = UUID()

        // save with no plan (how every build before this one opened the store)
        do {
            let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let modelContext = ModelContext(modelContainer)
            modelContext.insert(StoredVerseAnnotation(id: annotationID,
                                                      translationID: 111,
                                                      bookCode: "JHN",
                                                      chapter: 3,
                                                      startVerse: 16,
                                                      createdAt: .now))
            try modelContext.save()
        }

        // reopen through the plan
        let modelContainer = try ModelContainer(for: schema,
                                                migrationPlan: SwiftBibleMigrationPlan.self,
                                                configurations: [modelConfiguration])
        let fetched = try ModelContext(modelContainer).fetch(FetchDescriptor<StoredVerseAnnotation>())

        let annotation = try #require(fetched.first)
        #expect(fetched.count == 1)
        #expect(annotation.id == annotationID)
        #expect(annotation.bookCode == "JHN")
    }
}
