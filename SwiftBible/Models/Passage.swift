//
//  Passage.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/30/26.
//

nonisolated struct Passage: Identifiable, Equatable {
    /// i.e. "GEN.1"
    let id: String
    /// i.e. "Genesis 1"
    let reference: String
    let htmlContent: String
}

enum PassageLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}
