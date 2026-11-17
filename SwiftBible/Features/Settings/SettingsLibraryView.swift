//
//  SettingsLibraryView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-16.
//

import SwiftUI

struct SettingsLibraryView: View {

    // MARK: Properties (Private)

    /// Read appEnvironment.preferencesStore environment value from current view environment
    @Environment(PreferencesStore.self) private var preferencesStore: PreferencesStore

    /// Read appEnvironment.libraryStore environment value from current view environment
    @Environment(LibraryStore.self) private var libraryStore: LibraryStore

    @State private var deleteAllAnnotationsFirstConfirmationIsPresented: Bool = false
    @State private var deleteAllAnnotationsSecondConfirmationIsPresented: Bool = false
    @State private var deleteAllAnnotationsSecondConfirmationTextEntry: String = ""

    // MARK: Views

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

            // Delete All
            Section {
                // Delete All Annotations
                deleteAllAnnotationsButton
            } header: {
                EmptyView()
            }
        }
        .navigationTitle("Annotations")
    }

    // MARK: Views (Buttons)

    private var deleteAllAnnotationsButton: some View {
        Button(role: .destructive) {
            deleteAllAnnotationsFirstConfirmationIsPresented = true
        } label: {
            HStack {
                Label("Delete All Annotations", systemImage: "trash.fill")
                    .imageScale(.small)
                    .foregroundStyle(.red)
                    .opacity(libraryStore.annotations.count == 0 ? 0.6 : 1)
                    .saturation(libraryStore.annotations.count == 0 ? 0.6 : 1)
                Spacer()
            }
        }
        // reset confirmation 1
        .alert("Delete All Annotations",
               isPresented: $deleteAllAnnotationsFirstConfirmationIsPresented) {
            Button("Cancel", role: .cancel) {
                deleteAllAnnotationsFirstConfirmationIsPresented = false
            }
            Button("Delete", role: .destructive) {
                deleteAllAnnotationsSecondConfirmationTextEntry = "" // reset
                deleteAllAnnotationsFirstConfirmationIsPresented = false
                deleteAllAnnotationsSecondConfirmationIsPresented = true
            }
        } message: {
            let scopeText = preferencesStore.syncAnnotationsToICloud
            ? " from all devices"
            : " from this device"
            let count = libraryStore.annotations.count
            Text("\(count) saved annotations will be erased\(scopeText). This action cannot be undone.")
        }
        // reset confirmation 2
        .alert("Delete All Annotations",
               isPresented: $deleteAllAnnotationsSecondConfirmationIsPresented,
               actions: {
            TextField("Delete Confirmation",
                      text: $deleteAllAnnotationsSecondConfirmationTextEntry,
                      prompt: Text("DELETE"))
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                _ = libraryStore.deleteAll()
            }
            .disabled(deleteAllAnnotationsSecondConfirmationTextEntry != "DELETE")
        }, message: {
            Text("Please enter the word \"DELETE\" (all caps) to confirm.")
        })
        .disabled(libraryStore.annotations.count == 0)
    }
}

#Preview {
    NavigationStack {
        SettingsLibraryView()
            .environment(PreferencesStore(userDefaults: .standard))
    }
}
