//
//  CrosswayPassageResponse.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-05.
//

/// The fields SwiftBible uses from https://api.esv.org/v3/passage/html/
///
/// `passages` holds one HTML string per requested passage; a chapter request returns one.
nonisolated struct CrosswayPassageResponse: Decodable {
    /// i.e. "John 3"
    let canonical: String
    let passages: [String]
}
