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

    /// Single app-wide instance of AppEnvironment;
    /// which in turn handles one instance of ReaderStore.
    ///
    /// @State: SwiftUI owns/preserves this value across view/app refreshes;
    /// its changes can trigger UI updates.
    /// SwiftUI can recreate value structs during render lifecycle. @State allows for
    /// "storage" outside the transient struct values.
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
    /// appEnvironment.readerStore is @Observable ReaderStore instance.
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appEnvironment.readerStore) // inject @Observable ReaderStore instance
        }
    }
}
