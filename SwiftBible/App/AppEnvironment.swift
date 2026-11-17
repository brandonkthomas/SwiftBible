//
//  AppEnvironment.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import Foundation
import Observation
import OSLog
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
    let passageStore: BiblePassageStore
    let catalogStore: BibleCatalogStore
    let libraryStore: LibraryStore
    let preferencesStore: PreferencesStore

    let appConfiguration: AppConfiguration

    /// SwiftBible: Store the protocol itself for dependency inversion
    let libraryRepository: LibraryRepository
    
    /// System: Manages app-wide model storage
    let modelContainer: ModelContainer

    private static let logger = Logger(subsystem: "SwiftBible", category: "AppEnvironment")

    /// True when the app process is hosting a test bundle (XCTest or Swift Testing).
    /// Xcode sets XCTestConfigurationFilePath for hosted runs; the class check covers runners that don't.
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        || NSClassFromString("XCTestCase") != nil
    }

    // MARK: Init

    // Failable init is not desirable here;
    // if we fail, we need to pass along *why* so that we can show the reason in UI.
    // For now, NOT using "throws"... TODO: convert SwiftBibleApp to proper throwing interceptor
    init() {
        // AppConfiguration - API keys
        let appConfiguration = AppConfiguration()
        self.appConfiguration = appConfiguration

        // ModelContainer - app-wide @Model storage
        do {
            // Hosted test runs launch the app too; keep them off iCloud so they never sync the real store
            let modelConfiguration = ModelConfiguration(cloudKitDatabase: Self.isRunningTests ? .none : .automatic)

            // Perform best-effort backup (if needed) BEFORE we assign modelContainer
            do {
                if let currentBuildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
                   !Self.isRunningTests {
                    let backupURL = URL.applicationSupportDirectory
                        .appending(path: "SwiftBible")
                        .appending(path: "LibraryStoreBackups")

                    let backup = LibraryStoreBackup(storeURL: modelConfiguration.url,
                                                    backupsDirectory: backupURL,
                                                    userDefaults: UserDefaults.standard)

                    _ = try backup.backUpIfBuildChanged(currentBuildNumber: currentBuildNumber)
                }
            } catch {
                // the store still opens; only this build's pre-migration copy is missing
                Self.logger.error("LibraryStoreBackup failed; continuing without a backup: \(error.localizedDescription)")
            }

            // We're done here...
            self.modelContainer = try ModelContainer.library(configuration: modelConfiguration)
        } catch {
            preconditionFailure("Failed to initialize ModelContainer: \(error.localizedDescription)")
        }

        // LibraryRepository - storage for annotations
        let libraryRepository = SwiftDataLibraryRepository(modelContainer: modelContainer)
        self.libraryRepository = libraryRepository

        // ReaderStore [pre-req] - API requests, Reader state, etc
        guard let apiKey = appConfiguration.youVersionApiKey else {
            preconditionFailure("Missing YOUVERSION_APP_KEY in bundled Secrets.plist")
        }

        // deps
        let youVersionRepository = YouVersionBibleRepository(apiKey: apiKey,
                                                             baseURL: appConfiguration.youVersionBaseURL,
                                                             urlSession: .shared)
        // Tyndale serves NLT and KJV; without its key those IDs stay with YouVersion
        var routes: [RoutingBibleRepository.Route] = []

        if let tyndaleApiKey = appConfiguration.tyndaleApiKey {
            let tyndaleRepository = TyndaleBibleRepository(apiKey: tyndaleApiKey,
                                                           baseURL: appConfiguration.tyndaleBaseURL,
                                                           urlSession: .shared)
            routes.append(.init(translationIDs: [TyndaleBibleRepository.nltTranslation.id,
                                                 TyndaleBibleRepository.kjvTranslation.id],
                                repository: tyndaleRepository))
        } else {
            Self.logger.error("Missing TYNDALE_APP_KEY in bundled Secrets.plist; NLT/KJV routing disabled")
        }

        // Crossway serves the ESV; without its key that ID stays with YouVersion
        if let crosswayApiKey = appConfiguration.crosswayApiKey {
            let crosswayRepository = CrosswayBibleRepository(apiKey: crosswayApiKey,
                                                             baseURL: appConfiguration.crosswayBaseURL,
                                                             urlSession: .shared)
            routes.append(.init(translationIDs: [CrosswayBibleRepository.esvTranslation.id],
                                repository: crosswayRepository))
        } else {
            Self.logger.error("Missing CROSSWAY_APP_KEY in bundled Secrets.plist; ESV routing disabled")
        }

        let bibleRepository = RoutingBibleRepository(fallbackRepository: youVersionRepository,
                                                     routes: routes)

        // BiblePassageStore (+ DiskPassageCache)
        var passageCache: any PassageCache
        do {
            passageCache = try DiskPassageCache()
        } catch {
            Self.logger.error("Failed to initialize DiskPassageCache: \(error.localizedDescription)")
            passageCache = InMemoryPassageCache()
        }

        self.passageStore = BiblePassageStore(repository: bibleRepository,
                                              passageCache: passageCache)

        // BibleCatalogStore (+ DiskCatalogCache)
        var catalogCache: any CatalogCache
        do {
            catalogCache = try DiskCatalogCache()
        } catch {
            Self.logger.error("Failed to initialize DiskCatalogCache: \(error.localizedDescription)")
            catalogCache = InMemoryCatalogCache()
        }

        self.catalogStore = BibleCatalogStore(repository: bibleRepository,
                                              catalogCache: catalogCache)

        // PreferencesStore
        self.preferencesStore = PreferencesStore(userDefaults: .standard)

        // ReaderStore 2 - API requests, Reader state, etc
        self.readerStore = ReaderStore(passageStore: passageStore,
                                       catalogStore: catalogStore,
                                       preferencesStore: preferencesStore,
                                       libraryRepository: libraryRepository)

        // LibraryStore 2 - presentation view for annotations
        self.libraryStore = LibraryStore(libraryRepository: libraryRepository,
                                         catalogStore: catalogStore,
                                         passageStore: passageStore)
    }
}
