//
//  ModelContainer+Library.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-16.
//

import Foundation
import SwiftData

extension ModelContainer {

    /// Build a ModelContainer from a given ModelConfiguration using SwiftBible custom
    /// schema / migration plan (consolidated helper)
    ///
    /// The schema is the current version's own `models` list, so a model type added in a new
    /// version is picked up without editing this file.
    static func library(configuration: ModelConfiguration) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SwiftBibleSchemaCurrent.self)

        return try ModelContainer(for: schema,
                                  migrationPlan: SwiftBibleMigrationPlan.self,
                                  configurations: [configuration])
    }
}
