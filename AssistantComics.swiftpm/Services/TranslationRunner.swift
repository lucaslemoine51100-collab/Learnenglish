import SwiftUI
import Translation

/// Fournit une session de traduction anglais → français (framework Translation, traitement sur l'iPad).
///
/// La session n'est accessible que dans la closure de `translationTask` : à chaque nouvelle demande,
/// on (ré)active la configuration, ce qui relance la tâche, qui traite les demandes en attente du modèle.
/// Au premier usage, iPadOS peut proposer de télécharger les langues.
struct TranslationRunner: ViewModifier {
    @ObservedObject var model: ReaderModel
    @State private var configuration: TranslationSession.Configuration? = nil

    init(model: ReaderModel) {
        _model = ObservedObject(wrappedValue: model)
    }

    func body(content: Content) -> some View {
        content
            .translationTask(configuration) { session in
                await model.performPendingTranslations(using: session)
            }
            .onChange(of: model.translationTrigger) { _, _ in
                if configuration == nil {
                    configuration = TranslationSession.Configuration(
                        source: Locale.Language(identifier: "en"),
                        target: Locale.Language(identifier: "fr"))
                } else {
                    configuration?.invalidate()
                }
            }
    }
}
