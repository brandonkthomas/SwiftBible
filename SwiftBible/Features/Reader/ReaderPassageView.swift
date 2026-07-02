//
//  ReaderPassageView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import SwiftUI

/// Main scrollview for text; only called once we've validated all other states
struct ReaderPassageView: View {

    // MARK: Properties

    var passage: Passage

    // MARK: Views

    /// Reader view
    var body: some View {
        ScrollView {
            VStack {
                Text(passage.htmlContent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineHeight(AttributedString.LineHeight.exact(points: 30))
                // inset on L/R edges; spacing between paragraphs
                .padding(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
            }
            // prevent tab bar from covering up bottom few lines
            .padding(EdgeInsets(top: 24, leading: 0, bottom: 75, trailing: 0))
        }
    }
}
