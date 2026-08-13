import OrpheusCore
import SwiftData
import SwiftUI

/// Searches queryable entry metadata without decrypting every body.
struct SearchView: View {
    @Query(sort: \Entry.updatedAt, order: .reverse) private var entries: [Entry]
    @State private var query = ""

    private var results: [Entry] {
        guard !query.isEmpty else { return [] }
        return entries.filter { $0.title.localizedStandardContains(query) }
    }

    var body: some View {
        List(results) { entry in
            NavigationLink(entry.title) {
                SearchNoteDetailView(entry: entry)
            }
        }
        .listStyle(.plain)
        .overlay {
            if query.isEmpty {
                ContentUnavailableView {
                    Label("Search ORPHEUS", systemImage: "magnifyingglass")
                } description: {
                    Text("Find encrypted notes by title.")
                }
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .searchable(text: $query, prompt: "Search note titles")
        .navigationTitle("Search")
    }
}

private struct SearchNoteDetailView: View {
    let entry: Entry
    @State private var text = ""
    @State private var failure: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let failure {
                ContentUnavailableView(
                    "Couldn’t open note",
                    systemImage: "exclamationmark.lock",
                    description: Text(failure)
                )
            } else if isLoading {
                ProgressView("Unlocking note…")
            } else {
                ScrollView {
                    Text(text.isEmpty ? "This note is empty." : text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle(entry.title)
        .task {
            do {
                let store = try await VaultAccess.blobStore()
                let data = try await store.load(
                    id: entry.id,
                    for: .entryPayload(entry.id),
                    expectedDigest: entry.blobDigest
                )
                text = String(decoding: data, as: UTF8.self)
            } catch {
                failure = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview("Search — no query") {
    NavigationStack { SearchView() }
        .modelContainer(for: Entry.self, inMemory: true)
}
