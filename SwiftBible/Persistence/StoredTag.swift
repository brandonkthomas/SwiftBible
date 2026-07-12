//
//  StoredTag.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-07-11.
//

import Foundation
import SwiftData

/// Sibling CloudKit storage file for `Tag`
///
/// `Tag` is unaware of this file; only `LibraryRepository` knows of both
/// (repo to models, never inverse)
///
/// Final class over struct (this needs to be a ref type bound to ModelContext)
///
/// \@Attribute(.unique) macro not needed here (SwiftData) because CloudKit has no field
/// uniqueness constraint
///
/// final: we dont need this Model to ever be subclassed
///
/// Defaults are required by CloudKit for non-optionals; else they're rejected...
/// id/etc uses a default so that CloudKit can materialize populated records; no optional app-facing
/// paths are ever exposed (so SwiftBible cannot use defaults)
@Model
final class StoredTag {
    var id: UUID = UUID()
    var displayName: String = ""
    var normalizedName: String = ""
    
    /// 1 tag:M annotations
    ///
    /// Tags do not own annotations; nullify on delete.
    /// See `StoredVerseAnnotation.tags`.
    var annotations: [StoredVerseAnnotation]?
    
    init(id: UUID,
         displayName: String,
         normalizedName: String) {
        self.id = id
        self.displayName = displayName
        self.normalizedName = normalizedName
    }
}
