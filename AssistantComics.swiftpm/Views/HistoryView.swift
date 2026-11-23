import SwiftUI

/// Historique pédagogique : toutes les répliques traduites, avec leur explication grammaticale.
struct HistoryView: View {
    @EnvironmentObject private var history: HistoryStore
    @State private var query = ""

    private var filtered: [HistoryEntry] {
        guard !query.isEmpty else { return history.entries }
        return history.entries.filter {
            $0.original.localizedCaseInsensitiveContains(query)
                || $0.translation.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.original)
                        .font(.headline)
                    Text(entry.translation)
                    if let grammar = entry.grammar, !grammar.isEmpty {
                        DisclosureGroup("Grammaire") {
                            Text(grammar)
                                .font(.callout)
                                .textSelection(.enabled)
                        }
                    }
                    Text("\(entry.comic) · p. \(entry.page) · \(entry.date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .onDelete { offsets in
                let ids = offsets.map { filtered[$0].id }
                history.delete(ids: ids)
            }
        }
        .overlay {
            if history.entries.isEmpty {
                ContentUnavailableView("Historique vide",
                                       systemImage: "clock",
                                       description: Text("Les répliques que vous traduisez apparaîtront ici."))
            }
        }
        .searchable(text: $query, prompt: "Rechercher une réplique")
        .navigationTitle("Historique")
        .toolbar {
            ShareLink(item: history.exportText()) {
                Label("Exporter", systemImage: "square.and.arrow.up")
            }
            .disabled(history.entries.isEmpty)
        }
    }
}
