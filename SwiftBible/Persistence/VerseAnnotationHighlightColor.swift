//
//  VerseAnnotationHighlightColor.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-11.
//

import Foundation

/// Which highlight color are we storing?
///
/// Implements String so that StoredVerseAnnotation (CloudKit) knows how to store this
/// via inferred RawRepresentable -- SwiftData will see :String and just stores the string.
///
/// Codable is required by SwiftData
nonisolated enum VerseAnnotationHighlightColor: String, Codable, CaseIterable {
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case pink = "pink"
    case purple = "purple"

    /// Support for SwiftBibleMigrationPlan and SwiftBibleSchemaV1
    init(from decoder: any Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = VerseAnnotationHighlightColor(rawValue: rawValue) ?? .yellow
    }
}
