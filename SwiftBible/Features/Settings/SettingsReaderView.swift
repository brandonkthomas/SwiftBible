//
//  SettingsReaderView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-16.
//

import SwiftUI

struct SettingsReaderView: View {

    // MARK: Properties (Private)

    /// Read appEnvironment.preferencesStore environment value from current view environment
    @Environment(PreferencesStore.self) private var preferencesStore: PreferencesStore

    /// Hardcoded for now
    @State private var readerSettingsListenModeEnabled: Bool = false

    /// Main body
    var body: some View {
        @Bindable var prefStore = preferencesStore
        List {
            // Listen Mode
            Section {
                Toggle(isOn: $readerSettingsListenModeEnabled,
                       label: {
                    Text("Show Listen Mode")
                })
                .disabled(true)
            } header: {
                Text("Listen Mode")
            } footer: {
                Text("Coming soon.")
                    .font(.footnote)
            }

            // Auto-Lock
            Section {
                Toggle(isOn: $prefStore.disableReaderAutoLock,
                       label: {
                    Text("Prevent Auto-Lock")
                })
            } footer: {
                let message = prefStore.disableReaderAutoLock
                ? "Your device will remain awake while reading."
                : "Your device will respect its configured Auto-Lock setting."
                Text(message)
                    .font(.footnote)
            }
        }
        .navigationTitle("Read")
    }
}

#Preview {
    NavigationStack {
        SettingsReaderView()
    }
    .previewEnvironment(PreviewEnvironment(repository: FakeBibleRepository(throwWhenLoadingTranslations: true)))
}
