//
//  SearchScope.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-21.
//

import Foundation

/// What the search bar searches through
enum SearchScope: String, CaseIterable, Identifiable {
    case all
    case bible
    case annotations

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .all: "All"
        case .bible: "Bible"
        case .annotations: "Annotations"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "circle.dotted"
        case .bible: "book"
        case .annotations: "bookmark"
        }
    }
}
