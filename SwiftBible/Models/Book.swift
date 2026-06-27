//
//  Book.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/26/26.
//

/// Represents a Bible book
struct Book: Identifiable, Equatable {
    let id: String
    let code: String
    let displayName: String
    let canon: Canon
    let chapters: [Int]
}
