// swift-tools-version: 5.9

// Projet d'app Swift Playgrounds (iPad). Ouvrir le dossier « AssistantComics.swiftpm » dans Swift Playgrounds.
// Les réglages de l'app (nom, icône, couleur) peuvent aussi être modifiés dans Swift Playgrounds > Réglages de l'app.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Assistant Comics",
    platforms: [
        .iOS("18.0")
    ],
    products: [
        .iOSApplication(
            name: "Assistant Comics",
            targets: ["AppModule"],
            bundleIdentifier: "fr.learnenglish.assistantcomics",
            teamIdentifier: "",
            displayVersion: "0.1",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .chatMessage),
            accentColor: .presetColor(.orange),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            appCategory: .education
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
