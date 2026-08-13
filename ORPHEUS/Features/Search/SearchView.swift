import SwiftUI

/// Search across every Space.
///
/// The index and filters land in the discovery phase. What is here now is the
/// real search presentation and its two genuine zero-states — no query typed,
/// and a query with no matches — which are the states most often left broken.
struct SearchView: View {

    @State private var query = ""

    private var results: [String] { [] }

    var body: some View {
        List {
            ForEach(results, id: \.self) { result in
                Text(result)
            }
        }
        .listStyle(.plain)
        .overlay {
            if query.isEmpty {
                ContentUnavailableView {
                    Label("Search ORPHEUS", systemImage: "magnifyingglass")
                } description: {
                    Text("Find notes, files, photos, and recordings by title, text, or tag.")
                }
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .searchable(text: $query, prompt: "Search notes, files, and tags")
        .navigationTitle("Search")
    }
}

#Preview("Search — no query") {
    NavigationStack { SearchView() }
}
