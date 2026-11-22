//
//  Translation.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/26/26.
//

import Foundation

/// Represents a Bible translation
/// - Codable used for DiskCatalogCache
nonisolated struct Translation: Identifiable, Equatable, Codable {
    let id: Int
    let abbreviation: String
    let title: String
    let languageTag: String
    let license: String?
    let promotionalText: String?
    let availableBookCodes: [String]
}

nonisolated extension Translation {
    /// Copyright text to show; see TranslationCopyright.notice
    var copyrightNotice: String? {
        copyright.notice
    }

    /// 2 copyright fields-- as cached by CatalogCache
    var copyright: TranslationCopyright {
        TranslationCopyright(license: license, promotionalText: promotionalText)
    }

    /// Same translation w/ copyright fields from detail response/cache
    func withCopyright(_ copyright: TranslationCopyright) -> Translation {
        Translation(id: id,
                    abbreviation: abbreviation,
                    title: title,
                    languageTag: languageTag,
                    license: copyright.license,
                    promotionalText: copyright.promotionalText,
                    availableBookCodes: availableBookCodes)
    }
}

/// copyright fields
///
/// - Both nil means provider has no notice (ASV)
/// - Codable used for DiskCatalogCache
nonisolated struct TranslationCopyright: Equatable, Codable {
    let license: String?
    let promotionalText: String?

    /// license first then promotionalText (YouVersion's documented fallback)
    ///
    /// nil when neither holds any text
    var notice: String? {
        [license, promotionalText]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}
