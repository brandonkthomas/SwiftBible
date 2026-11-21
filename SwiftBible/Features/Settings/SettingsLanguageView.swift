//
//  SettingsLanguageView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-21.
//

import SwiftUI

/// App language settings
struct SettingsLanguageView: View {

    // MARK: Properties (Static, Private)

    /// hardcoded for now
    private static let languages: [String] = ["English"]

    // MARK: Properties (State, Private)

    /// Selected language
    @State private var language = "English"

    // MARK: Views

    /// Main body
    var body: some View {
        List {
            Section {
                // Language
                Picker(selection: $language,
                       label: Label("Preferred Language", systemImage: "globe.fill")
                    .imageScale(.medium)
                    .foregroundStyle(.primary)) {
                        ForEach(Self.languages, id: \.self) { language in
                            Text(language)
                                .tag(language)
                        }
                    }
                .disabled(true)
            } header: {
                EmptyView()
            } footer: {
                Text("Coming soon.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Language & Region")
    }
}

#Preview {
    NavigationStack {
        SettingsLanguageView()
    }
    .previewEnvironment()
}
