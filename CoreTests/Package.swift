// swift-tools-version: 5.9

// Tests unitaires de la logique pure de l'app (dossier AssistantComics.swiftpm/Core).
// Les fichiers sont copiés dans Sources/ComicsCore avant l'exécution : voir README.md.

import PackageDescription

let package = Package(
    name: "ComicsCoreTests",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "ComicsCore", path: "Sources/ComicsCore"),
        .testTarget(name: "ComicsCoreTests", dependencies: ["ComicsCore"], path: "Tests/ComicsCoreTests")
    ]
)
