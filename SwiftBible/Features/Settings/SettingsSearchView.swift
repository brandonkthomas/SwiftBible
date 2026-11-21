//
//  SettingsSearchView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-21.
//

import SwiftUI

/// App search settings
struct SettingsSearchView: View {

    // MARK: Properties (Static, Private)

    /// hardcoded for now
    private static let defaults: [String] = ["Bible & Annotations",
                                             "Bible Only",
                                             "Annotations Only"]

    // MARK: Properties (State, Private)

    /// Selected
    @State private var `default` = "Bible & Annotations"

    // MARK: Views

    /// Main body
    var body: some View {
        List {
            Section {
                // Default Filter
                Picker(selection: $default,
                       label: Label("Default", systemImage: "text.page.badge.magnifyingglass")
                    .imageScale(.medium)
                    .foregroundStyle(.primary)) {
                        ForEach(Self.defaults, id: \.self) { option in
                            Text(option)
                                .tag(option)
                        }
                    }
                .disabled(true)
            } header: {
                Text("Filters")
            } footer: {
                Text("Coming soon.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Search")
    }
}

#Preview {
    NavigationStack {
        SettingsSearchView()
    }
    .previewEnvironment()
}
