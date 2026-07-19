//
//  LibraryView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/27/26.
//

import SwiftUI

struct LibraryView: View {

    // MARK: Properties (Proj Env, Private)

    /// Read appEnvironment.readerStore environment value from current view environment
    ///
    /// Don't need "\." here because this is a type-based lookup for an observable instance
    /// placed into the environment: .environment(readerStore))
    @Environment(LibraryStore.self) private var libraryStore: LibraryStore

    // MARK: Views

    var body: some View {
        NavigationStack {
            libraryListView
            .navigationTitle("Saved")
            .navigationSubtitle("\(libraryStore.annotations.count) Annotation\(libraryStore.annotations.count == 1 ? "" : "s")")
//            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                filterOptionsToolbarItem
            }
        }
        .onAppear {
            libraryStore.load()
        }
    }

    /// List of annotations
    var libraryListView: some View {
        List {
            ForEach(libraryStore.annotations) { annotation in
                // build this annotation into a card
                Group {
                    Text("\(annotation)")
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    ///
    @ToolbarContentBuilder
    private var filterOptionsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {

            } label: {
                Image(systemName: "magnifyingglass")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Menu {
                    Button {

                    } label: {
                        Label("Test", systemImage: "plus")
                    }
                    Button {

                    } label: {
                        Label("Test", systemImage: "plus")
                    }
                    Button {

                    } label: {
                        Label("Test", systemImage: "plus")
                    }
                } label: {
                    Label("Sort By", systemImage: "arrow.up.arrow.down")
                }

                Menu {
                    Button {

                    } label: {
                        Label("Test", systemImage: "plus")
                    }
                    Button {

                    } label: {
                        Label("Test", systemImage: "plus")
                    }
                    Button {

                    } label: {
                        Label("Test", systemImage: "plus")
                    }
                } label: {
                    Label("Filter By", systemImage: "line.3.horizontal.decrease")
                }

                Divider()

                Button {

                } label: {
                    Label("Select", systemImage: "checkmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }
}

// MARK: Xcode Canvas Previews

#Preview {
    let libraryStore = LibraryStore(libraryRepository: PreviewFixtures.seededLibraryRepository())
    LibraryPreviewHost(libraryStore: libraryStore)
}

/// Preview-only host
private struct LibraryPreviewHost: View {
    let libraryStore: LibraryStore

    var body: some View {
        LibraryView()
        .environment(libraryStore)
        .task {
            libraryStore.load()
        }
    }
}
