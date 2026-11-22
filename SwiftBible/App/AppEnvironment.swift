//
//  AppEnvironment.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import Foundation
import Observation
import OSLog
import TipKit
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
    let searchStore: SearchStore
    let preferencesStore: PreferencesStore
    let networkMonitor: NetworkMonitor

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

    /// True when launched with `-seedLibraryInMemory` (DEBUG builds only)
    /// Library will use in-memorystore seeded from `LibrarySeedFixtures`... on-disk store and iCloud are ignored
    private static var isSeedingLibrary: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-seedLibraryInMemory")
        #else
        false
        #endif
    }

    // MARK: Init

    // Failable init is not desirable here;
    // if we fail, we need to pass along *why* so that we can show the reason in UI.
    // For now, NOT using "throws"... TODO: convert SwiftBibleApp to proper throwing interceptor
    init() {
        // AppConfiguration - API keys
        let appConfiguration = AppConfiguration()
        self.appConfiguration = appConfiguration

        // deps (set to self @ bottom of init)
        let prefStore = PreferencesStore(userDefaults: .standard,
                                         ubiquitousStore: Self.isRunningTests ? nil : NSUbiquitousKeyValueStore.default)

        // ModelContainer - app-wide @Model storage
        do {
            // Only enable iCloud when NOT running tests & our Preference is enabled
            // Hosted test runs launch the app too; keep them off iCloud so they never sync the real store
            let cloudKitDB: ModelConfiguration.CloudKitDatabase =
                !Self.isRunningTests && prefStore.syncAnnotationsToICloud
                ? .private("iCloud.net.brandonthomas.SwiftBible")
                : .none
            let modelConfiguration = Self.isSeedingLibrary
                ? ModelConfiguration(isStoredInMemoryOnly: true,
                                     cloudKitDatabase: .none)
                : ModelConfiguration(url: AppDirectories.libraryStore,
                                     cloudKitDatabase: cloudKitDB)

            // Perform best-effort backup (if needed) BEFORE we assign modelContainer
            do {
                if let currentBuildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
                   !Self.isRunningTests,
                   !Self.isSeedingLibrary {
                    let backupURL = AppDirectories.libraryStoreBackups

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

        #if DEBUG
        if Self.isSeedingLibrary {
            do {
                for annotation in LibrarySeedFixtures.annotations {
                    try libraryRepository.save(annotation)
                }
            } catch {
                Self.logger.error("Seeding library from LibrarySeedFixtures failed: \(error.localizedDescription)")
            }
        }
        #endif

        do {
            // Try to merge dupes first (iCloud race/edge case)
            try libraryRepository.mergeDuplicateTags()
        } catch {
            Self.logger.error("libraryRepository.mergeDuplicateTags() failed: \(error.localizedDescription)")
        }

        self.libraryRepository = libraryRepository

        // ReaderStore [pre-req] - API requests, Reader state, etc
        guard let apiKey = appConfiguration.youVersionApiKey else {
            preconditionFailure("Missing YOUVERSION_APP_KEY in bundled Secrets.plist")
        }

        // deps
        let youVersionRepository = YouVersionBibleRepository(apiKey: apiKey,
                                                             baseURL: appConfiguration.youVersionBaseURL,
                                                             urlSession: .shared)
        // NLT and KJV (Tyndale) were removed 2026-11-20: Tyndale ends public API access on
        // 2027-01-01; the picker lists them as unavailable (DisabledTranslation)
        var routes: [RoutingBibleRepository.Route] = []

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

        // NetworkMonitor - live connection status (online only passages, reload on reconnect)
        let networkMonitor = NetworkMonitor()
        networkMonitor.start()
        self.networkMonitor = networkMonitor

        self.passageStore = BiblePassageStore(repository: bibleRepository,
                                              passageCache: passageCache,
                                              networkStatus: networkMonitor)

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
        self.preferencesStore = prefStore

        // ReaderStore 2 - API requests, Reader state, etc
        self.readerStore = ReaderStore(passageStore: passageStore,
                                       catalogStore: catalogStore,
                                       preferencesStore: preferencesStore,
                                       libraryRepository: libraryRepository)

        // LibraryStore 2 - presentation view for annotations
        self.libraryStore = LibraryStore(libraryRepository: libraryRepository,
                                         catalogStore: catalogStore,
                                         passageStore: passageStore)

        // SearchStore
        self.searchStore = SearchStore(repository: bibleRepository,
                                       libraryStore: libraryStore,
                                       bibleCatalogStore: catalogStore,
                                       biblePassageStore: passageStore)

        // Done with deps...
        // TipKit
        if !Self.isRunningTests {
            do {
                // Show every tip again: Xcode runs only (the shared scheme passes -resetTips;
                // archived/TestFlight builds never get scheme arguments)
                if ProcessInfo.processInfo.arguments.contains("-resetTips") {
                    try Tips.resetDatastore()
                }
                try Tips.configure()
            } catch {
                Self.logger.error("Failed to initialize TipKit: \(error.localizedDescription)")
            }
        }
    }
}
