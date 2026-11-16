//
//  SwiftBibleMigrationPlan.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-16.
//

import Foundation
import SwiftData

enum SwiftBibleMigrationPlan: SchemaMigrationPlan {

    /// Required schemas
    static var schemas: [any VersionedSchema.Type] {
        [SwiftBibleSchemaV1.self]
    }

    /// Required stages
    static var stages: [MigrationStage] {
        []
    }
}
