//
//  SearchBarView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-21.
//

import SwiftUI

/// Search bar in bottom of SearchView
struct SearchBarView: View {

    // MARK: Properties

    /// What is the text field's value?
    @Binding var text: String

    /// What is our search scope? (Bible, Annotations, Both)
    @Binding var scope: SearchScope

    /// Translations available to search, sorted by title
    var translations: [Translation]

    /// Which translation are we searching?
    @Binding var selectedTranslationID: Translation.ID?

    /// Is the text field focused?
    var isFocused: FocusState<Bool>.Binding

    /// Closure so parent views can react to text keystrokes
    var onTextChange: (String) -> Void

    /// Closure so parent views can react to textfield submission
    var onTextSubmit: (String) async -> Void

    // MARK: Properties (Private)

    /// Used for filter/close buttons' liquid glass container
    @Namespace private var glassNamespace

    // MARK: Views

    /// Main body
    var body: some View {
        HStack(spacing: 8) {
            searchField
            filterAndCloseButtons
        }
        .tint(.primary)
        .animation(.smooth, value: isFocused.wrappedValue)
    }

    ///
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.primary)
            TextField("Search", text: $text)
                .focused(isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onChange(of: text) {
                    onTextChange(text)
                }
                .onSubmit {
                    Task {
                        await onTextSubmit(text)
                    }
                }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        // Padding isn't part of the TextField's hit area, so route taps on the whole capsule to focus
        .contentShape(.capsule)
        .onTapGesture { isFocused.wrappedValue = true }
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    ///
    private var filterAndCloseButtons: some View {
        // Container lets the menu and X morph into each other
        GlassEffectContainer {
            HStack {
                // Filters
                Menu {
                    Section("Filter By") {
                        // Scope
                        Picker(selection: $scope) {
                            ForEach(SearchScope.allCases) { scope in
                                Label(scope.title, systemImage: scope.systemImage)
                                    .tag(scope)
                            }
                        } label: {
                            Label("Source", systemImage: "archivebox")
                            Text(scope.title)
                                .foregroundStyle(Color.secondary)
                        }
                        .pickerStyle(.menu)

                        // Translations
                        Picker(selection: $selectedTranslationID) {
                            ForEach(translations) { translation in
                                Text(verbatim: translation.title)
                                    .tag(Optional(translation.id))
                            }
                        } label: {
                            Label("Translation", systemImage: "text.book.closed")
                            if let abbreviation = translations.first(where: { $0.id == selectedTranslationID })?.abbreviation {
                                Text(verbatim: abbreviation)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } label: {
                    Label("Filters", systemImage: "line.3.horizontal.decrease")
                        .labelStyle(.iconOnly)
                        .imageScale(.large)
                        .frame(width: 48, height: 48)
                        .contentShape(.circle)
                        .foregroundStyle(scope == .all ? Color.primary : Color(.systemBackground))
                        .background(scope == .all ? Color.clear : Color.accent, in: .circle)
                }
                .menuOrder(.fixed)
                .glassEffect(.regular.interactive(), in: .circle)
                .glassEffectID("trailing", in: glassNamespace)

                // Close
                if isFocused.wrappedValue {
                    Button {
                        text = ""
                        isFocused.wrappedValue = false
                        // ensure SearchStore resets state
                        Task {
                            await onTextSubmit(text)
                        }
                    } label: {
                        Label("Clear", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                            .imageScale(.large)
                            .frame(width: 48, height: 48)
                            .contentShape(.circle)
                    }
                    .glassEffect(.regular.interactive(), in: .circle)
                    .glassEffectID("trailing", in: glassNamespace)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var text = ""
    @Previewable @State var scope = SearchScope.all
    @Previewable @State var translationID: Translation.ID?
    @Previewable @FocusState var isFocused: Bool

    SearchBarView(text: $text,
                  scope: $scope,
                  translations: FakeBibleRepository.defaultTranslations,
                  selectedTranslationID: $translationID,
                  isFocused: $isFocused,
                  onTextChange: { text in },
                  onTextSubmit: { text in })
        .padding()
        .previewEnvironment()
}
