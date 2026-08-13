// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OrpheusCore",
    // Spelled as a version string rather than a `.vNN` case: the enum cases
    // available depend on the SwiftPM version, and the string form is stable.
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "OrpheusCore", targets: ["OrpheusCore"])
    ],
    targets: [
        .target(
            name: "OrpheusCore",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
