//
//  HighlightPickerView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-09-27.
//

import SwiftUI

/// Highlight action item for an annotation
struct HighlightPickerView: View {

    // MARK: Closures

    /// What should we do when we need to save this as a new highlight annotation?
    let onCreateRequested: (VerseAnnotationHighlightColor) -> Void

    /// What should we do when we need to delete this highlight annotation?
    let onDeleteRequested: () -> Void

    // MARK: Properties

    let existingHighlightColors: [VerseAnnotationHighlightColor]?

    // MARK: Properties (Private)

    /// Triggered when we need to dismiss this view
    @Environment(\.dismiss) private var dismiss

    /// Triggered when a highlight popover button is tapped
    @State private var highlightHapticTrigger: Bool = false

    // MARK: Views

    var body: some View {
        GlassEffectContainer(spacing: 15) {
            HStack(spacing: 15) {
                // show 1 button for each public color
                ForEach(VerseAnnotationHighlightColor.allCases, id: \.rawValue) { item in
                    highlightColorButton(for: item)
                }
            }
            // popover padding on L/R
            .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
            // open minimal popover view
            .presentationCompactAdaptation(.none)
        }
    }

    /// Produces a selectable circle button for a given highlight color
    private func highlightColorButton(for color: VerseAnnotationHighlightColor) -> some View {
        let selected = existingHighlightColors?.contains(color) ?? false

        return Button(action: {
            withAnimation(.snappy(duration: 0.35)) {
                if selected { onDeleteRequested() } else { onCreateRequested(color) }
            }
            highlightHapticTrigger.toggle()
            dismiss()
        }) {
            let size = UIFontMetrics(forTextStyle: .body).scaledValue(for: 30)
            Image(systemName: selected ? "checkmark" : "")
            //Text("") // color only
                .frame(width: size, height: size)
                .foregroundColor(Color.black.opacity(0.7))
        }
        // blend in w/ surrounding elements; interactive; tint to correct color
        .glassEffect(.regular.tint(color.uiColor).interactive(),in: .circle)
        // haptic on selection; warning when removing an existing highlight
        .sensoryFeedback(selected ? .warning : .success, trigger: highlightHapticTrigger)
    }
}

#Preview {
    @Previewable @State var isHighlightPopoverPresented: Bool = false

    Button(action: {
        isHighlightPopoverPresented = true
    }) {
        Image(systemName: "pencil")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.primary, .gray)
        // allow transition between image states
            .contentTransition(.symbolEffect(.replace.offUp.byLayer, options: .nonRepeating))
    }
    .popover(isPresented: $isHighlightPopoverPresented,
             attachmentAnchor: .point(.top),
             arrowEdge: .bottom,
             content: {
        HighlightPickerView(onCreateRequested: { color in },
                            onDeleteRequested: {},
                            existingHighlightColors: [.blue,.green])
    })
}
