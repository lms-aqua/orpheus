import OrpheusCore
import SwiftUI

/// Spaces: the primary organisational surface.
///
/// Full create/rename/reorder/archive behaviour arrives with the persistence
/// layer in the next commit of Phase 1. This view already renders the real
/// empty state a new install sees, so that state is exercised rather than
/// discovered later.
struct SpacesView: View {

    private let spaces: [String] = []

    var body: some View {
        Group {
            if spaces.isEmpty {
                ContentUnavailableView {
                    Label("No Spaces yet", systemImage: "square.stack")
                } description: {
                    Text("Spaces keep related things together — Personal, Work, Documents, or anything you like.")
                } actions: {
                    Button("Create a Space") {}
                        .buttonStyle(.glassProminent)
                }
            } else {
                List(spaces, id: \.self) { space in
                    Text(space)
                }
            }
        }
        .navigationTitle("Spaces")
    }
}

#Preview("Spaces — empty") {
    NavigationStack { SpacesView() }
}
