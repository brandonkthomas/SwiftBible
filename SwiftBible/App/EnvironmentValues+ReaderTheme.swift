//
//  EnvironmentValues+ReaderTheme.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-12.
//

import SwiftUI

extension EnvironmentValues {
    /// Active reader theme; defaults to .default for previews / subtrees without an injected value
    @Entry var readerTheme: ReaderThemeResolved = .init(basePreset: .default)
}
