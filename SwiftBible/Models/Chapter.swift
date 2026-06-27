//
//  Chapter.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

struct Chapter: Identifiable, Equatable {
    let id: String
    let number: Int // likely redundant w/ ID
    let bookID: String
    let displayName: String
}
