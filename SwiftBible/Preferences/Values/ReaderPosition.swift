//
//  ReaderPosition.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-10-23.
//

import Foundation

/// Last-used reader position; to restore on app restart
struct ReaderPosition: Equatable, Codable {
    let translationID: Translation.ID
    let bookCode: String
    let chapter: Int
}
