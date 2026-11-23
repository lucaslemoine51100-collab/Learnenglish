import SwiftUI

/// Assistant Comics — version PDF.
///
/// Lire un comic PDF, analyser la page affichée (OCR sur l'iPad), choisir une bulle numérotée,
/// voir sa traduction française et une explication grammaticale, garder un historique.
@main
struct AssistantComicsApp: App {
    @StateObject private var library = ComicLibrary()
    @StateObject private var history = HistoryStore()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(library)
                .environmentObject(history)
        }
    }
}
