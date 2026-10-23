//
//  Translation.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/26/26.
//

/// Represents a Bible translation
/// - Codable used for DiskCatalogCache
nonisolated struct Translation: Identifiable, Equatable, Codable {
    let id: Int
    let abbreviation: String
    let title: String
    let languageTag: String
    let license: String?
    let promotionalText: String?
    let availableBookCodes: [String]
}
