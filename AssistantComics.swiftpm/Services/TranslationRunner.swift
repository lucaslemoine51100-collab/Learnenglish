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
                // La session reste dans cette closure (exigence de Swift 6) : seuls des textes en sortent.
                let jobs = await model.takePendingJobs()
                for (index, job) in jobs.enumerated() {
                    do {
                        let response = try await session.translate(job.text)
                        await model.applyTranslation(job, text: response.targetText)
                    } catch is CancellationError {
                        await model.requeue(Array(jobs[index...]))
                        return
                    } catch {
                        await model.failTranslation(job, message: error.localizedDescription)
                    }
                }
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
