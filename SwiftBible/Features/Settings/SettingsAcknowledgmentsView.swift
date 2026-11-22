//
//  SettingsAcknowledgmentsView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-05.
//

import SwiftUI

/// Copyright notice for every available translation, plus a link to each text provider
///
/// Notices come from Translation.copyrightNotice
/// Missing ones are fetched when this view opens
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

    // MARK: Views

    var body: some View {
        List {
            // Bible Translations
            Section {
                if catalogStore.translationsByTitle.isEmpty {
                    ProgressView()
                }

                ForEach(catalogStore.translationsByTitle) { translation in
                    translationRow(translation)
                }
            } header: {
                Text("Bible Translations")
            } footer: {
                Text("* Translations marked \"Unavailable\" in the translation picker (NLT, KJV) are not licensed to this app and cannot be used.")
                    .font(.footnote)
            }

            // Bible Text Providers
            Section {
                ForEach(Self.providers) { provider in
                    providerRow(provider)
                }
            } header: {
                Text("Bible Text Providers")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Acknowledgments")
        .navigationBarTitleDisplayMode(.inline)
        // opening this view is the user action that allows these requests
        .task(id: catalogStore.translations.map(\.id)) {
            await catalogStore.loadMissingCopyrightNotices()
        }
    }

    /// Translation title + abbreviation
    ///
    /// copyright notice is plain text
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

            if let notice = translation.copyrightNotice {
                Text(verbatim: notice)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else {
                missingNoticeView(for: translation)
            }
        }
        .padding(.vertical, 4)
    }

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

    /// Spinner while the notice loads, else why there is none
    ///
    /// Nil status means the lookup hasn't started yet
    @ViewBuilder
    private func missingNoticeView(for translation: Translation) -> some View {
        switch catalogStore.copyrightNoticeStatuses[translation.id] {
        case .unavailable:
            missingNoticeReason("Please contact YouVersion (below) to review this translation's copyright notice.")
        case .failed:
            missingNoticeReason("Couldn't load this copyright notice. Check your connection and reopen this screen.")
        case .loading, nil:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Loading copyright notice")
        }
    }

    private func missingNoticeReason(_ reason: LocalizedStringKey) -> some View {
        Text(reason)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

#Preview("Loading") {
    NavigationStack {
        SettingsAcknowledgmentsView()
    }
    .previewEnvironment()
}
#Preview("Loaded") {
    @Previewable @State var environment = PreviewEnvironment()

    NavigationStack {
        SettingsAcknowledgmentsView()
    }
    .previewEnvironment(environment)
    .task {
        try? await environment.catalogStore.loadTranslations()
    }
}
