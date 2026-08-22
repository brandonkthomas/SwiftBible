//
//  AppEnvironment.swift
//  HomePlus
//
//  Created by Brandon Thomas on 6/27/26.
//

import Foundation
import Observation
import SwiftData // for PersistentModel/ModelContainer/ModelConfiguration/Schema

/// App-wide owner of various repositories (AppConfiguration, ReaderStore, LibraryRepository)
///
/// This is our composition root:
/// - SwiftBibleApp creates one AppEnvironment()
/// - AppEnvironment creates/reads AppConfiguration
/// - AppEnvironment uses that config to choose/create repositories
/// - SwiftBibleApp injects only the view-facing objects
@Observable
final class AppEnvironment {

    // MARK: Properties

    let readerStore: ReaderStore
    let catalogStore: BibleCatalogStore
    let libraryStore: LibraryStore

    let appConfiguration: AppConfiguration

    /// SwiftBible: Store the protocol itself for dependency inversion
    let libraryRepository: LibraryRepository
    
    /// System: Manages app-wide model storage
    let modelContainer: ModelContainer

    // MARK: Init

    // Failable init is not desirable here;
    // if we fail, we need to pass along *why* so that we can show the reason in UI.
    // For now, NOT using "throws"... TODO: convert SwiftBibleApp to proper throwing interceptor
    init() {
        // AppConfiguration - API keys
        let appConfiguration = AppConfiguration()
        self.appConfiguration = appConfiguration

        // ModelContainer - app-wide @Model storage
        // Use explicit ModelConfiguration here for easier caller variations in tests/CloudKit)
        let typesToRegister: [any PersistentModel.Type] = [
            StoredVerseAnnotation.self,
            StoredTag.self
        ]

        do {
            let schema: Schema = .init(typesToRegister)
            let modelConfiguration = ModelConfiguration(schema: schema)
            self.modelContainer = try ModelContainer(for: schema,
                                                     configurations: [modelConfiguration])
        } catch {
            preconditionFailure("Failed to initialize ModelContainer: \(error.localizedDescription)")
        }

        // LibraryRepository - storage for annotation
        let libraryRepository = SwiftDataLibraryRepository(modelContainer: modelContainer)
        self.libraryRepository = libraryRepository

        // ReaderStore - API requests, Reader state, etc
        guard let apiKey = appConfiguration.youVersionApiKey else {
            preconditionFailure("Missing YOUVERSION_APP_KEY in bundled Secrets.plist")
        }

        let bibleRepository = YouVersionBibleRepository(apiKey: apiKey,
                                                   baseURL: appConfiguration.youVersionBaseURL,
                                                   urlSession: .shared)

        self.catalogStore = BibleCatalogStore(repository: bibleRepository)

        self.readerStore = ReaderStore(repository: bibleRepository,
                                       catalogStore: catalogStore,
                                       libraryRepository: libraryRepository)

        // LibraryStore
        self.libraryStore = LibraryStore(libraryRepository: libraryRepository)
    }
}
