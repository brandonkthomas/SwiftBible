//
//  LibraryModelContainerTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-11-16.
//

import Foundation
import SwiftData
import Testing
@testable import SwiftBible

/// `ModelContainer.library(configuration:)` owns the schema and migration plan;
/// the caller only decides where the store lives and whether it syncs.
@MainActor
struct LibraryModelContainerTests {

    /// the container opens stores through the app's migration plan
    @Test func usesMigrationPlan() throws {
        let modelContainer = try ModelContainer.library(configuration: inMemoryConfiguration())

        #expect(modelContainer.migrationPlan is SwiftBibleMigrationPlan.Type)
    }

    /// both stored models are registered
    @Test func registersBothModels() throws {
        let modelContainer = try ModelContainer.library(configuration: inMemoryConfiguration())

        #expect(modelContainer.schema.entities.map(\.name).sorted() == ["StoredTag", "StoredVerseAnnotation"])
    }

    /// the store is created at the configuration's URL, and a second container on that URL reads the first one's rows
    @Test func storesAtConfigurationURL() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let storeURL = directoryURL.appending(path: "Library.store")
        let annotationID = UUID()

        do {
            let modelContainer = try ModelContainer.library(configuration: ModelConfiguration(url: storeURL,
                                                                                            cloudKitDatabase: .none))
            modelContainer.mainContext.insert(StoredVerseAnnotation(id: annotationID,
                                                                    translationID: 111,
                                                                    bookCode: "JHN",
                                                                    chapter: 3,
                                                                    startVerse: 16,
                                                                    createdAt: .now))
            try modelContainer.mainContext.save()
        }

        let modelContainer = try ModelContainer.library(configuration: ModelConfiguration(url: storeURL,
                                                                                        cloudKitDatabase: .none))
        let fetched = try modelContainer.mainContext.fetch(FetchDescriptor<StoredVerseAnnotation>())

        #expect(FileManager.default.fileExists(atPath: storeURL.path(percentEncoded: false)))
        #expect(modelContainer.configurations.first?.url == storeURL)
        #expect(fetched.map(\.id) == [annotationID])
    }

    // MARK: Functions (Private)

    /// no schema here on purpose: the container supplies it
    private func inMemoryConfiguration() -> ModelConfiguration {
        ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    }
}
