//
//  SettingsLibraryView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-16.
//

import SwiftUI

struct SettingsLibraryView: View {

    /// Read appEnvironment.preferencesStore environment value from current view environment
    @Environment(PreferencesStore.self) private var preferencesStore: PreferencesStore

    var body: some View {
        @Bindable var prefStore = preferencesStore
        List {
            // iCloud Backup
            Section {
                Toggle("Sync to iCloud", isOn: $prefStore.syncAnnotationsToICloud)
            } header: {
                Text("Backup")
            } footer: {
                let applicableText = prefStore.syncAnnotationsToICloud
                ? "Annotations are backed up and available across your devices."
                : "Annotations are not backed up and are available only on this device."
                let noticeText = "Applies after restarting the app."

                Text("\(applicableText) \(noticeText)")
                .font(.footnote)
            }
        }
        .navigationTitle("Annotations")
    }
}

#Preview {
    NavigationStack {
        SettingsLibraryView()
            .environment(PreferencesStore(userDefaults: .standard))
    }
}


#Preview {
    SettingsReaderView()
}
