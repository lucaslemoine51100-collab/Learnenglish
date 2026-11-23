import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Résultat de l'explication grammaticale d'une réplique.
struct GrammarReport: Equatable {
    /// Explication rédigée par le modèle local d'Apple Intelligence, si disponible.
    var aiText: String?
    /// Repères détectés par les règles locales (toujours calculés).
    var points: [GrammarPoint]
    /// Message d'information (modèle indisponible, erreur…).
    var notice: String?

    /// Résumé texte, enregistré dans l'historique.
    var summary: String {
        if let aiText, !aiText.isEmpty { return aiText }
        return points.map { point in
            point.examples.isEmpty ? "• \(point.title)" : "• \(point.title) : \(point.examples.joined(separator: ", "))"
        }.joined(separator: "\n")
    }
}

/// Explication grammaticale : Apple Intelligence (sur l'appareil) si disponible, sinon règles locales.
enum GrammarService {

    static var isAppleIntelligenceAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return AppleIntelligenceGrammar.isAvailable
        }
        #endif
        return false
    }

    static func explain(_ text: String) async -> GrammarReport {
        let rules = GrammarAnalyzer.analyze(text)
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if AppleIntelligenceGrammar.isAvailable {
                do {
                    let answer = try await AppleIntelligenceGrammar.explain(text)
                    return GrammarReport(aiText: answer, points: rules, notice: nil)
                } catch {
                    return GrammarReport(
                        aiText: nil, points: rules,
                        notice: "Apple Intelligence n'a pas pu répondre (\(error.localizedDescription)). Voici les repères automatiques.")
                }
            }
        }
        #endif
        return GrammarReport(
            aiText: nil, points: rules,
            notice: "Apple Intelligence n'est pas disponible sur cet appareil : explications simplifiées, générées par des règles.")
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
enum AppleIntelligenceGrammar {

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static func explain(_ text: String) async throws -> String {
        let instructions = """
            Tu es un professeur d'anglais bienveillant. Ton élève est un adulte francophone de niveau \
            intermédiaire qui lit des comics en anglais. Pour la réplique fournie, explique en français, \
            en 10 lignes maximum :
            1. le sens général de la réplique ;
            2. les temps et constructions verbales utilisés (nomme-les en français et cite la forme anglaise) ;
            3. les contractions, l'argot ou les expressions idiomatiques et leur sens ;
            4. un point de grammaire à retenir, avec un court exemple.
            N'invente pas de contexte sur l'histoire. Sois précis et concis.
            """
        let session = LanguageModelSession(instructions: instructions)
        let prompt = "Réplique de comics : « \(text) »"
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
#endif
