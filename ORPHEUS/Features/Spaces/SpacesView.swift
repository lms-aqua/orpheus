import OrpheusCore
import SwiftData
import SwiftUI

/// User-defined organizational containers persisted with SwiftData.
struct SpacesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Space.sortOrder) private var spaces: [Space]
    @State private var isCreatingSpace = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if spaces.isEmpty {
                ContentUnavailableView {
                    Label("No Spaces yet", systemImage: "square.stack")
                } description: {
                    Text("Spaces keep related things together — Personal, Work, Documents, or anything you like.")
                } actions: {
                    Button("Create a Space") { isCreatingSpace = true }
                        .buttonStyle(.glassProminent)
                }
            } else {
                List {
                    ForEach(spaces) { space in
                        Label(space.name, systemImage: "square.stack")
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Spaces")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Create a Space", systemImage: "plus") {
                    isCreatingSpace = true
                }
            }
        }
        .sheet(isPresented: $isCreatingSpace) {
            NewSpaceView(nextSortOrder: (spaces.map(\.sortOrder).max() ?? -1) + 1)
        }
        .alert("Couldn’t update Spaces", isPresented: errorIsPresented) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(spaces[index])
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

private struct NewSpaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var errorMessage: String?
    let nextSortOrder: Int

    var body: some View {
        NavigationStack {
            Form {
                TextField("Space name", text: $name)
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("New Space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func create() {
        let space = Space(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            sortOrder: nextSortOrder
        )
        modelContext.insert(space)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.delete(space)
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Spaces — empty") {
    NavigationStack { SpacesView() }
        .modelContainer(for: Space.self, inMemory: true)
}
