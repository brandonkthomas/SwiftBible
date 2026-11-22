//
//  View+SwipeActionsContainer.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-21.
//

import SwiftUI

// MARK: Swipe Actions Availability

extension View {

    /// Enables row `.swipeActions` outside a List on iOS 27+; no-op on earlier versions
    ///
    /// Shared by LibraryView and SearchView (both ScrollView + LazyVStack)
    ///
    /// The `if` depends only on the OS version, which never changes while the app runs,
    /// so view identity stays stable (unlike a conditional modifier driven by state)
    @ViewBuilder
    func swipeActionsContainerIfAvailable() -> some View {
        if #available(iOS 27, *) {
            swipeActionsContainer()
        } else {
            self
        }
    }
}
