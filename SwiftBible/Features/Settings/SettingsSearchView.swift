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

    /// Read appEnvironment.preferencesStore environment value from current view environment
    @Environment(PreferencesStore.self) private var preferencesStore: PreferencesStore

    // MARK: Views

    /// Main body
    var body: some View {
        @Bindable var prefStore = preferencesStore
        List {
            Section {
                // Default Filter
                Picker(selection: $prefStore.defaultSearchScope,
                       label: Label("Default Source", systemImage: "archivebox")
                    .imageScale(.medium)
                    .foregroundStyle(.primary)
                ) {
                    ForEach(SearchScope.allCases) { scope in
                        Text(scope.title)
                            .tag(scope)
                    }
                }
            } header: {
                Text("Filters")
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
