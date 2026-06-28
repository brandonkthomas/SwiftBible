//
//  Verse.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/28/26.
//

nonisolated struct Verse: Identifiable, Equatable {
    /// i.e. "GEN.1.1"
    let id: String
    /// i.e. 1
    let number: Int // redundant w/ id but only used for UI purposes
    /// i.e. "GEN.1"
    let chapterID: String
    /// i.e. "GEN"
    let bookID: String
    /// i.e. "1"
    let displayName: String // likely reudndant w/ id
}
