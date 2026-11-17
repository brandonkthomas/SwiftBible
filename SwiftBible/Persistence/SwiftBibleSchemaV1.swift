//
//  SwiftBibleSchemaV1.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-16.
//

import Foundation
import SwiftData

// Freeze current models as SchemaV1
enum SwiftBibleSchemaV1: VersionedSchema {

    /// Required version identifier
    static let versionIdentifier = Schema.Version(1, 0, 0)

    /// Required model definitions
    static var models: [any PersistentModel.Type] {
        get {
            [StoredVerseAnnotation.self,
             StoredTag.self]
        }
    }
}

// The app-wide names (StoredVerseAnnotation, StoredTag) live in SwiftBibleSchemaCurrent.swift
