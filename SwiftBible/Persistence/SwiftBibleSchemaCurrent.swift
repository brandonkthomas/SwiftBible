//
//  SwiftBibleSchemaCurrent.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-16.
//

import Foundation
import SwiftData

/// The schema version the app reads and writes today.
///
/// Bumping the version (e.g. to V2):
/// 1. Add `SwiftBibleSchemaV2` with its own nested `@Model` copies.
/// 2. Change the line below to `SwiftBibleSchemaV2`.
/// 3. Append V2 to `SwiftBibleMigrationPlan.schemas` and add a V1 -> V2 stage.
/// `SwiftBibleMigrationPlanTests.lastSchemaIsCurrent` fails if step 2 or 3 is missed.
typealias SwiftBibleSchemaCurrent = SwiftBibleSchemaV1

// App-wide model names; always the current version's classes
typealias StoredVerseAnnotation = SwiftBibleSchemaCurrent.StoredVerseAnnotation
typealias StoredTag = SwiftBibleSchemaCurrent.StoredTag
