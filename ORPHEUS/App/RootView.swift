import SwiftUI

/// The app's primary navigation.
///
/// One `TabView` with `.sidebarAdaptable` covers both idioms: a tab bar on
/// iPhone, a real sidebar on iPad and in wide windows, resolved by the system
/// rather than by a hand-rolled size-class branch. That is what keeps the iPad
/// build from being a stretched iPhone layout without maintaining two trees.
struct RootView: View {

    @State private var selection: Destination = .home

    private enum Destination: Hashable {
        case home, spaces, search, settings
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "circle.dotted.circle", value: Destination.home) {
                NavigationStack { HomeView() }
            }

            Tab("Spaces", systemImage: "square.stack", value: Destination.spaces) {
                NavigationStack { SpacesView() }
            }

            Tab("Search", systemImage: "magnifyingglass", value: Destination.search, role: .search) {
                NavigationStack { SearchView() }
            }

            Tab("Settings", systemImage: "gearshape", value: Destination.settings) {
                NavigationStack { SettingsView() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview("Root — Light") {
    RootView()
}

#Preview("Root — Dark") {
    RootView()
        .preferredColorScheme(.dark)
}
