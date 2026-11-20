//
//  DisabledTranslation.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-20.
//

import Foundation

/// A translation listed in the passage picker but not selectable, with the reason shown when tapped
///
/// Hardcoded, display-only rows: nothing else in the app knows about these
nonisolated struct DisabledTranslation: Identifiable {
    let abbreviation: String
    let title: String

    /// Alert message shown when the row is tapped
    let reason: String

    var id: String { abbreviation }

    /// Disabled rows for the English translations list
    static let english: [DisabledTranslation] = [
        DisabledTranslation(
            abbreviation: "NLT",
            title: "New Living Translation",
            reason: String(localized: "Tyndale has shut down their public API access for this translation. We're working on finding another provider. Thank you for your patience!",
                           comment: "Alert message for the unavailable NLT translation")
        ),
        DisabledTranslation(
            abbreviation: "KJV",
            title: "King James Version",
            reason: String(localized: "Tyndale has shut down their public API access for this translation. We're working on finding another provider. Thank you for your patience!",
                           comment: "Alert message for the unavailable KJV translation")
        )
    ]
}
