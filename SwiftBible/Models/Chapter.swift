//
//  Chapter.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

nonisolated struct Chapter: Identifiable, Equatable {
    /// i.e. "GEN.1"
    let id: String
    /// i.e. 1
    let number: Int // redundant w/ id but only used for UI purposes
    /// i.e. "GEN"
    let bookID: String
    /// i.e. "1"
    let displayName: String // likely reudndant w/ id
    let verses: [Verse]
}
