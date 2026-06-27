//
//  LibraryView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Saved",
                systemImage: "bookmark",
                description: Text("Coming soon.")
            )
            .navigationTitle("Saved")
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    LibraryView()
}
