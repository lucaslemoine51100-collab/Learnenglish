import Foundation
import Combine

/// Une réplique étudiée. Seul le texte est conservé, jamais l'image de la page.
struct HistoryEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var comic: String
    /// Numéro de page (à partir de 1).
    var page: Int
    var original: String
    var translation: String
    var grammar: String?
}

/// Historique pédagogique, enregistré localement (fichier JSON dans les Documents de l'app).
@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []

    private let fileURL: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documents.appendingPathComponent("historique.json")
        load()
    }

    /// Ajoute (ou remet en tête) une réplique traduite.
    func record(comic: String, page: Int, original: String, translation: String) {
        if let index = entries.firstIndex(where: { $0.original == original }) {
            var entry = entries.remove(at: index)
            entry.date = Date()
            entry.translation = translation
            entry.comic = comic
            entry.page = page
            entries.insert(entry, at: 0)
        } else {
            entries.insert(HistoryEntry(date: Date(), comic: comic, page: page,
                                        original: original, translation: translation), at: 0)
        }
        save()
    }

    func attachGrammar(_ grammar: String, toOriginal original: String) {
        guard let index = entries.firstIndex(where: { $0.original == original }) else { return }
        entries[index].grammar = grammar
        save()
    }

    func delete(ids: [UUID]) {
        entries.removeAll { ids.contains($0.id) }
        save()
    }

    /// Texte brut de tout l'historique, pour le partager ou l'exporter.
    func exportText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return entries.map { entry in
            var block = "« \(entry.original) »\n→ \(entry.translation)\n(\(entry.comic), p. \(entry.page), \(formatter.string(from: entry.date)))"
            if let grammar = entry.grammar, !grammar.isEmpty { block += "\nGrammaire :\n\(grammar)" }
            return block
        }.joined(separator: "\n\n")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([HistoryEntry].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
