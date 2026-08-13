import OrpheusCore
import SwiftUI

/// Home: an overview of recent and pinned content.
///
/// Not a dashboard. There are no charts, counters, or analytics here — per the
/// brief this is a personal application, so Home answers "what was I just
/// doing" and "let me put something in", nothing more.
struct HomeView: View {

    // Phase 1 has no persisted entries yet, so Home correctly shows its empty
    // state. It is wired to real data in the content phase rather than faked
    // with sample entries, which would make the empty state untestable.
    private let recentEntries: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if recentEntries.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing here yet", systemImage: "circle.dotted.circle")
                    } description: {
                        Text("Add a note, file, photo, recording, or scan and it will appear here.")
                    } actions: {
                        Button("New Note") {}
                            .buttonStyle(.glassProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(OrpheusColor.canvas)
        .navigationTitle("ORPHEUS")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(OrpheusColor.primaryText)

            Text("Your private workspace.")
                .font(.subheadline)
                .foregroundStyle(OrpheusColor.secondaryText)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        // One accessibility element: VoiceOver reads the greeting and subtitle
        // as a single heading rather than two disconnected fragments.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// Returned as a `LocalizedStringKey` so the String Catalog picks these up
    /// automatically and `Text` resolves them, rather than baking in English.
    private var greeting: LocalizedStringKey {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5 ..< 12: "Good morning"
        case 12 ..< 17: "Good afternoon"
        case 17 ..< 22: "Good evening"
        default: "Welcome back"
        }
    }
}

#Preview("Home — empty") {
    NavigationStack { HomeView() }
}

#Preview("Home — dark") {
    NavigationStack { HomeView() }
        .preferredColorScheme(.dark)
}

#Preview("Home — accessibility sizes") {
    NavigationStack { HomeView() }
        .environment(\.dynamicTypeSize, .accessibility3)
}
