//
//  Canon.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/26/26.
//

/// Which testament is this book in?
/// - Codable used for DiskCatalogCache
nonisolated enum Canon: String, CaseIterable, Codable {
    case oldTestament
    case newTestament
    case deuterocanon

    /// Map String to Canon
    static func fromString(_ string: String) -> Canon? {
        switch string.lowercased() {
        case "old_testament":
            return .oldTestament
        case "new_testament":
            return .newTestament
        case "deuterocanon":
            return .deuterocanon
        default:
            return nil
        }
    }
}
