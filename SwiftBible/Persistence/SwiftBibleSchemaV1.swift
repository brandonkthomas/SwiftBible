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

// Required so other files can find these classes
typealias StoredVerseAnnotation = SwiftBibleSchemaV1.StoredVerseAnnotation
typealias StoredTag = SwiftBibleSchemaV1.StoredTag
