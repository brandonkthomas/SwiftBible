//
//  LibraryStore.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-19.
//

import Foundation
import OSLog

@Observable
final class LibraryStore {

    // MARK: Properties



    // MARK: Properties (Private)

    /// User storage command implementations
    private let libraryRepository: any LibraryRepository

    /// 
    private(set) var annotations: [VerseAnnotation] = []

    /// OS Logging
    private static let logger = Logger(subsystem: "SwiftBible", category: "LibraryStore")

    // MARK: Init

    init(libraryRepository: LibraryRepository) {
        self.libraryRepository = libraryRepository
    }

    // MARK: Load

    func load() {
        do {
            annotations = try libraryRepository.allAnnotations()
        } catch {
            Self.logger.error("Unable to save annotation: \(error.localizedDescription)")
        }
    }
}
