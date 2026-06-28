//
//  Translation.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/26/26.
//

/// Represents a Bible translation
nonisolated struct Translation: Identifiable, Equatable {
    let id: String
    let abbreviation: String
    let title: String
    let languageTag: String
    let license: String
    let promotionalText: String?
}
