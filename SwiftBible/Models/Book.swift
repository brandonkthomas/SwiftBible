//
//  Book.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/26/26.
//

/// Represents a Bible book
///
/// nonisolated: this type is safe to use from any actor (it's just value/data logic)
/// - Anything that SwiftUI reads must be on @MainActor (i.e. ReaderStore)
nonisolated struct Book: Identifiable, Equatable {
    let id: String
    /// i.e. "GEN"
    let code: String
    /// i.e. "Genesis"
    let displayName: String
    let canon: Canon
    let chapters: [Chapter]
}
