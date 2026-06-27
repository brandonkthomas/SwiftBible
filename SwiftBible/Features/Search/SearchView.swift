//
//  SearchView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import SwiftUI

struct SearchView: View {
    var body: some View {
        //ContentUnavailableView.search
        ContentUnavailableView(
            "Search",
            systemImage: "magnifyingglass",
            description: Text("Coming soon.")
        )
        .navigationTitle("Search")
        .navigationBarHidden(true)
    }
}

#Preview {
    SearchView()
}
