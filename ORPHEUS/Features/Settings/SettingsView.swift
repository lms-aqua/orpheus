import OrpheusCore
import SwiftUI

/// Settings.
///
/// Sectioned with a native `Form`, so grouping, Dynamic Type, and pointer
/// behaviour come from the platform. Security, Storage, Intelligence, and Data
/// sections fill in as those subsystems land; what is shown here is real and
/// accurate today rather than a menu of inert rows.
struct SettingsView: View {

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section("About") {
                LabeledContent("Version", value: version)
                // Reading this from the core package is also a live check that
                // the app is linked against the encryption layer it claims to
                // use, rather than a stale copy.
                LabeledContent(
                    "Content format",
                    value: "v\(EncryptedBlobHeader.currentVersion)"
                )
            }

            Section {
                NavigationLink("How ORPHEUS protects your data") {
                    SecurityExplanationView()
                }
            } footer: {
                Text("ORPHEUS stores your content encrypted on this device.")
            }
        }
        .navigationTitle("Settings")
    }
}

/// Plain-language description of the actual security model.
///
/// Every claim here is one the implementation can back. Per the brief there is
/// no "military grade" or "unhackable" language, and the limitations are stated
/// rather than omitted.
private struct SecurityExplanationView: View {
    var body: some View {
        List {
            Section("Encryption") {
                Text("Your entries and attachments are encrypted on this device using AES-256-GCM, which both conceals content and detects any change to it.")
                Text("Each item is encrypted with its own key, derived from a single vault key using HKDF. One item's key cannot open another item.")
            }

            Section("Keys") {
                Text("The vault key is generated on this device and stored in the iOS Keychain. It is never written into app settings, the database, or any file.")
            }

            Section("Limitations") {
                Text("ORPHEUS cannot protect content after you export or share it. A device with malware or one that has been jailbroken can bypass app-level protection.")
                Text("If you lose access to this device and have no ORPHEUS archive, encrypted content cannot be recovered — there is no backdoor and no recovery key held elsewhere.")
            }
        }
        .navigationTitle("Your data")
    }
}

#Preview("Settings") {
    NavigationStack { SettingsView() }
}

#Preview("Security explanation") {
    NavigationStack { SecurityExplanationView() }
}
