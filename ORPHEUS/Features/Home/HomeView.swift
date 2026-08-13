import OrpheusCore
import SwiftData
import SwiftUI

/// Recent encrypted notes and the primary capture action.
struct HomeView: View {
    @Query(sort: \Entry.updatedAt, order: .reverse) private var recentEntries: [Entry]
    @State private var isCreatingNote = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if recentEntries.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing here yet", systemImage: "circle.dotted.circle")
                    } description: {
                        Text("Create an encrypted note and it will appear here.")
                    } actions: {
                        Button("New Note") { isCreatingNote = true }
                            .buttonStyle(.glassProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(recentEntries) { entry in
                            NavigationLink {
                                NoteDetailView(entry: entry)
                            } label: {
                                EntryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(OrpheusColor.canvas)
        .navigationTitle("ORPHEUS")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Note", systemImage: "square.and.pencil") {
                    isCreatingNote = true
                }
            }
        }
        .sheet(isPresented: $isCreatingNote) {
            NewNoteView()
        }
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
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var greeting: LocalizedStringKey {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5 ..< 12: "Good morning"
        case 12 ..< 17: "Good afternoon"
        case 17 ..< 22: "Good evening"
        default: "Welcome back"
        }
    }
}

private struct EntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "note.text")
                .font(.title3)
                .foregroundStyle(OrpheusColor.secondaryText)
                .frame(width: 36, height: 36)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.headline)
                    .foregroundStyle(OrpheusColor.primaryText)
                    .lineLimit(1)
                Text(entry.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(OrpheusColor.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
    }
}

private struct NewNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var bodyText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextEditor(text: $bodyText)
                    .frame(minHeight: 220)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        errorMessage = nil
        let id = UUID()

        do {
            let store = try await VaultAccess.blobStore()
            let descriptor = try await store.store(
                Data(bodyText.utf8),
                id: id,
                for: .entryPayload(id)
            )
            let entry = Entry(
                id: id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                blobDigest: descriptor.digest,
                plaintextByteCount: descriptor.plaintextByteCount,
                ciphertextByteCount: descriptor.ciphertextByteCount
            )
            modelContext.insert(entry)

            do {
                try modelContext.save()
            } catch {
                try? await store.delete(id: id)
                throw error
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}

private struct NoteDetailView: View {
    let entry: Entry
    @State private var bodyText = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Unlocking note…")
            } else if let errorMessage {
                ContentUnavailableView(
                    "Couldn’t open note",
                    systemImage: "exclamationmark.lock",
                    description: Text(errorMessage)
                )
            } else {
                ScrollView {
                    Text(bodyText.isEmpty ? "This note is empty." : bodyText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle(entry.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: entry.updatedAt) { await load() }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let store = try await VaultAccess.blobStore()
            let data = try await store.load(
                id: entry.id,
                for: .entryPayload(entry.id),
                expectedDigest: entry.blobDigest
            )
            bodyText = String(decoding: data, as: UTF8.self)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview("Home — empty") {
    NavigationStack { HomeView() }
        .modelContainer(for: Entry.self, inMemory: true)
}
