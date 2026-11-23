import SwiftUI

/// Contenu de la fenêtre flottante : analyse de la page, liste numérotée des bulles, traduction et grammaire.
struct AssistantPanel: View {
    @ObservedObject var model: ReaderModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            toolbar
            if let message = model.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            if let bubble = model.selectedBubble {
                BubbleDetailView(model: model, bubble: bubble)
            } else {
                bubbleList
            }
        }
        .padding(12)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                model.analyzeCurrentPage()
            } label: {
                HStack(spacing: 6) {
                    if model.isAnalyzing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "text.viewfinder")
                    }
                    Text(model.currentAnalysis == nil ? "Analyser" : "Réanalyser")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isAnalyzing || model.document == nil)

            Spacer()

            Toggle(isOn: $model.showMarkers) {
                Image(systemName: "number.square")
            }
            .toggleStyle(.button)
            .accessibilityLabel("Afficher les numéros sur la page")
        }
    }

    @ViewBuilder
    private var bubbleList: some View {
        if let analysis = model.currentAnalysis {
            Text("\(analysis.bubbles.count) bulle(s) · \(analysis.duration.formatted(.number.precision(.fractionLength(1)))) s · touchez une bulle (liste ou page)")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(analysis.bubbles) { bubble in
                        Button {
                            model.select(bubble)
                        } label: {
                            BubbleRow(bubble: bubble)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } else if !model.isAnalyzing {
            Text("Appuyez sur « Analyser » pour détecter les bulles de cette page. La BD n'est jamais modifiée.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct BubbleRow: View {
    let bubble: Bubble

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            NumberBadge(number: bubble.id)
            VStack(alignment: .leading, spacing: 2) {
                Text(bubble.displayText)
                    .font(.callout)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if bubble.kind == .largeText {
                    Text("Grand texte : titre ou onomatopée ?")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(.secondarySystemBackground)))
        .contentShape(Rectangle())
    }
}

private struct NumberBadge: View {
    let number: Int
    var selected = false

    var body: some View {
        Text("\(number)")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .frame(minWidth: 24, minHeight: 24)
            .padding(.horizontal, number >= 10 ? 4 : 0)
            .background(Capsule().fill(selected ? Color.orange : Color.blue))
    }
}

/// Détail d'une bulle : texte anglais (modifiable si l'OCR s'est trompé), traduction, grammaire.
private struct BubbleDetailView: View {
    @ObservedObject var model: ReaderModel
    let bubble: Bubble

    var body: some View {
        let key = model.key(for: bubble)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    model.selectedBubbleID = nil
                } label: {
                    Label("Liste", systemImage: "chevron.left")
                }
                Spacer()
                Button { model.selectAdjacent(-1) } label: { Image(systemName: "chevron.up") }
                    .disabled(bubble.id == model.currentBubbles.first?.id)
                    .accessibilityLabel("Bulle précédente")
                NumberBadge(number: bubble.id, selected: true)
                Button { model.selectAdjacent(1) } label: { Image(systemName: "chevron.down") }
                    .disabled(bubble.id == model.currentBubbles.last?.id)
                    .accessibilityLabel("Bulle suivante")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    section("Anglais") {
                        TextField("Texte de la bulle", text: model.editedTextBinding(for: bubble), axis: .vertical)
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled()
                            .font(.body)
                        Button {
                            model.retranslateSelected()
                        } label: {
                            Label("Retraduire le texte corrigé", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }

                    section("Français") {
                        switch model.translations[key] {
                        case .loading?:
                            ProgressView("Traduction…")
                        case .done(let translation)?:
                            Text(translation)
                                .textSelection(.enabled)
                        case .failed(let message)?:
                            Text("Traduction impossible : \(message)")
                                .foregroundStyle(.red)
                                .font(.callout)
                        case nil:
                            Text("—").foregroundStyle(.secondary)
                        }
                    }

                    section("Grammaire") {
                        switch model.grammar[key] {
                        case nil:
                            Button {
                                model.explainSelected()
                            } label: {
                                Label("Expliquer la grammaire", systemImage: "graduationcap")
                            }
                            .buttonStyle(.bordered)
                        case .loading?:
                            ProgressView("Analyse grammaticale…")
                        case .done(let report)?:
                            GrammarReportView(report: report)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(.secondarySystemBackground)))
    }
}

private struct GrammarReportView: View {
    let report: GrammarReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let notice = report.notice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let aiText = report.aiText {
                formatted(aiText)
                    .textSelection(.enabled)
                if !report.points.isEmpty {
                    Text("Repères automatiques")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(report.points) { point in
                VStack(alignment: .leading, spacing: 2) {
                    Text(point.title)
                        .font(.subheadline.weight(.semibold))
                    Text(point.explanation)
                        .font(.callout)
                    if !point.examples.isEmpty {
                        Text(point.examples.map { "« \($0) »" }.joined(separator: ", "))
                            .font(.caption)
                            .italic()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func formatted(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attributed = try? AttributedString(markdown: text, options: options) {
            return Text(attributed)
        }
        return Text(text)
    }
}
