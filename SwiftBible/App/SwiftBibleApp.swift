//
//  SwiftBibleApp.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import SwiftUI

@main
struct SwiftBibleApp: App {

    // MARK: Properties (Private)

    /// Single SwiftBibleApp-wide instance of AppEnvironment (persists view refreshes);
    /// which in turn handles one instance of ReaderStore.
    ///
    /// @State: SwiftUI owns/preserves this value across the ownership site (App);
    /// its changes can trigger UI updates. .environment below will distribute this once
    /// persistent instance across SwiftBible.
    ///
    /// SwiftUI can recreate value structs during render lifecycle. @State allows for
    /// "storage" outside the transient struct values.
    ///
    /// AppEnvironment is a class (ref obj) so @State preserves ref to this specific instance.
    ///
    /// This is a "var" because @State is a property wrapper which requires "var".
    /// SwiftUI needs writable framework-managed storage behind the scenes;
    /// does not mean we expect to replace appEnvironment.
    @State private var appEnvironment = AppEnvironment()

    // MARK: Properties (Public)

    /// Initial body.
    ///
    /// "some Scene": this is some other type which conforms to the Scene protocol.
    /// WindowGroup is a Scene that presents a group of identically structured windows.
    ///
    /// appEnvironment.readerStore must be an @Observable instance.
    var body: some Scene {
        WindowGroup {
            ContentView()
                // inject @Observable ReaderStore instance
                // this has @Observable state, so we need type-based environment
                // Type-keyed is for @Observable (type itself is the key: stored under ReaderStore)
                .environment(appEnvironment.readerStore)
                // inject custom env/key value for LibraryRepository protocol
                // this is a service/dependency, so we need key-path environment
                // Keypath-keyed is for existential (anything: value types, services, protocols)
                .environment(\.libraryRepository, appEnvironment.libraryRepository)
        }
    }
}
