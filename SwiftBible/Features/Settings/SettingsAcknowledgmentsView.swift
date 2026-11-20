//
//  SettingsAcknowledgmentsView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-05.
//

import SwiftUI

/// Copyright notice for every available translation, plus a link to each text provider
///
/// Notices come from Translation.license: YouVersion's per-version copyright, or the
/// notice CrosswayBibleRepository defines
struct SettingsAcknowledgmentsView: View {

    // MARK: Types (Private)

    /// One Bible text provider and the translations it serves
    nonisolated private struct Provider: Identifiable {
        let name: String
        let translations: String?
        let url: URL

        var id: String { name }
    }

    // MARK: Properties (Env, Private)

    @Environment(BibleCatalogStore.self) private var catalogStore: BibleCatalogStore

    // MARK: Properties (Static, Private)

    /// Crossway requires a link to www.esv.org wherever ESV text is used
    private static let providers: [Provider] = [
        Provider(name: "YouVersion",
                 translations: nil,
                 url: URL(string: "https://www.youversion.com")!),
        Provider(name: "Crossway",
                 translations: "ESV",
                 url: URL(string: "https://www.esv.org")!)
    ]

    // MARK: Properties (Computed, Private)

    private var sortedTranslations: [Translation] {
        catalogStore.translations.sorted { $0.title < $1.title }
    }

    // MARK: Views

    var body: some View {
        List {
            Section("Bible Translations") {
                if sortedTranslations.isEmpty {
                    Text("Translations haven’t loaded yet.")
                        .foregroundStyle(.secondary)
                }

                ForEach(sortedTranslations) { translation in
                    translationRow(translation)
                }
            }

            Section("Bible Text Providers") {
                ForEach(Self.providers) { provider in
                    providerRow(provider)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Acknowledgments")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Translation title + abbreviation, then its copyright notice as plain text
    private func translationRow(_ translation: Translation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                // API data; never looked up in the String Catalog
                Text(verbatim: translation.title)

//                Spacer()
//
//                Text(verbatim: translation.abbreviation)
//                    .font(.subheadline)
//                    .foregroundStyle(.secondary)
            }

            if let notice = copyrightNotice(for: translation) {
                Text(verbatim: notice)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else {
                Text("No copyright notice was provided for this translation.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    /// Provider name + the translations it serves; opens the provider's site
    private func providerRow(_ provider: Provider) -> some View {
        Link(destination: provider.url) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: provider.name)
                        .foregroundStyle(.primary)

                    if let translations = provider.translations {
                        Text(verbatim: translations)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
    }

    /// YouVersion's guide: use the version's copyright, else its promotional content
    private func copyrightNotice(for translation: Translation) -> String? {
        let candidates = [translation.license, translation.promotionalText]

        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

#Preview {
    NavigationStack {
        SettingsAcknowledgmentsView()
    }
    .previewEnvironment()
}
