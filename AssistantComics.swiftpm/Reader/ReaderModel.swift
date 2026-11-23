import SwiftUI
import PDFKit
import Translation

/// Résultat de l'analyse d'une page.
struct PageAnalysis {
    let bubbles: [Bubble]
    /// Rectangle de chaque bulle dans l'espace PDF de la page (clé : numéro de bulle).
    let pageRects: [Int: CGRect]
    let duration: TimeInterval
}

/// Repère affiché sur la page (cadre + numéro), sans modifier le fichier PDF.
struct PageHighlight: Equatable {
    let number: Int
    let rect: CGRect
    let selected: Bool
}

enum AsyncText: Equatable {
    case loading
    case done(String)
    case failed(String)
}

enum GrammarState: Equatable {
    case loading
    case done(GrammarReport)
}

/// Une demande de traduction en attente (traitée par `TranslationRunner`).
struct TranslationJob: Sendable {
    let key: String
    let text: String
    let page: Int
}

/// État du lecteur et de l'assistant pour un comic ouvert.
@MainActor
final class ReaderModel: ObservableObject {
    let comic: ComicFile
    let document: PDFDocument?

    @Published var pageIndex: Int
    @Published private(set) var analyses: [Int: PageAnalysis] = [:]
    @Published private(set) var isAnalyzing = false
    @Published var errorMessage: String?
    @Published var selectedBubbleID: Int?
    @Published var showMarkers = true
    @Published private(set) var translations: [String: AsyncText] = [:]
    @Published private(set) var grammar: [String: GrammarState] = [:]
    @Published var editedTexts: [String: String] = [:]
    /// Incrémenté à chaque demande de traduction (déclenche `TranslationRunner`).
    @Published private(set) var translationTrigger = 0

    weak var history: HistoryStore?
    private var pendingJobs: [TranslationJob] = []

    init(comic: ComicFile, startPage: Int) {
        self.comic = comic
        let document = PDFDocument(url: comic.url)
        self.document = document
        let count = document?.pageCount ?? 0
        self.pageIndex = min(max(0, startPage), max(0, count - 1))
    }

    // MARK: - Accès

    var pageCount: Int { document?.pageCount ?? 0 }
    var currentAnalysis: PageAnalysis? { analyses[pageIndex] }
    var currentBubbles: [Bubble] { currentAnalysis?.bubbles ?? [] }

    var selectedBubble: Bubble? {
        guard let id = selectedBubbleID else { return nil }
        return currentBubbles.first { $0.id == id }
    }

    func key(for bubble: Bubble) -> String { "\(pageIndex)-\(bubble.id)" }

    func text(for bubble: Bubble) -> String { editedTexts[key(for: bubble)] ?? bubble.displayText }

    func editedTextBinding(for bubble: Bubble) -> Binding<String> {
        let key = self.key(for: bubble)
        let fallback = bubble.displayText
        return Binding(
            get: { self.editedTexts[key] ?? fallback },
            set: { self.editedTexts[key] = $0 })
    }

    var highlights: [PageHighlight] {
        guard showMarkers, let analysis = currentAnalysis else { return [] }
        return analysis.bubbles.compactMap { bubble in
            analysis.pageRects[bubble.id].map {
                PageHighlight(number: bubble.id, rect: $0, selected: bubble.id == selectedBubbleID)
            }
        }
    }

    // MARK: - Navigation

    func pageDidChange() {
        selectedBubbleID = nil
        errorMessage = nil
    }

    func goToPage(_ index: Int) {
        guard pageCount > 0 else { return }
        pageIndex = min(max(0, index), pageCount - 1)
    }

    // MARK: - Analyse

    func analyzeCurrentPage() {
        guard !isAnalyzing, let page = document?.page(at: pageIndex) else { return }
        let index = pageIndex
        let url = comic.url
        let box = page.bounds(for: .cropBox)
        let rotation = page.rotation
        isAnalyzing = true
        errorMessage = nil
        selectedBubbleID = nil

        Task {
            let start = Date()
            do {
                let bubbles = try await PageAnalyzer.analyze(url: url, pageIndex: index)
                var rects: [Int: CGRect] = [:]
                for bubble in bubbles {
                    rects[bubble.id] = PageGeometry.pageRect(fromNormalized: bubble.box, box: box, rotation: rotation)
                }
                analyses[index] = PageAnalysis(bubbles: bubbles, pageRects: rects,
                                               duration: Date().timeIntervalSince(start))
                if bubbles.isEmpty && index == pageIndex {
                    errorMessage = "Aucun texte détecté sur cette page."
                }
            } catch {
                if index == pageIndex { errorMessage = "Analyse impossible : \(error.localizedDescription)" }
            }
            isAnalyzing = false
        }
    }

    // MARK: - Sélection

    func select(_ bubble: Bubble) {
        selectedBubbleID = bubble.id
        let key = self.key(for: bubble)
        if translations[key] == nil {
            requestTranslation(key: key, text: self.text(for: bubble))
        }
    }

    func selectAdjacent(_ delta: Int) {
        let bubbles = currentBubbles
        guard let id = selectedBubbleID, let index = bubbles.firstIndex(where: { $0.id == id }) else { return }
        let target = index + delta
        guard bubbles.indices.contains(target) else { return }
        select(bubbles[target])
    }

    /// Touche sur la page (coordonnées PDF) : sélectionne la bulle touchée, la plus petite si plusieurs.
    func handleTap(pageIndex tappedPage: Int, point: CGPoint) {
        guard tappedPage == pageIndex, let analysis = currentAnalysis else { return }
        let margin: CGFloat = 6
        let hits = analysis.bubbles.compactMap { bubble -> (Bubble, CGFloat)? in
            guard let rect = analysis.pageRects[bubble.id],
                  rect.insetBy(dx: -margin, dy: -margin).contains(point) else { return nil }
            return (bubble, rect.width * rect.height)
        }
        if let best = hits.min(by: { $0.1 < $1.1 })?.0 { select(best) }
    }

    // MARK: - Traduction

    func retranslateSelected() {
        guard let bubble = selectedBubble else { return }
        let key = self.key(for: bubble)
        grammar[key] = nil
        requestTranslation(key: key, text: self.text(for: bubble))
    }

    private func requestTranslation(key: String, text: String) {
        let cleaned = TextNormalizer.forTranslation(text)
        guard !cleaned.isEmpty else { return }
        translations[key] = .loading
        pendingJobs.removeAll { $0.key == key }
        pendingJobs.append(TranslationJob(key: key, text: cleaned, page: pageIndex + 1))
        translationTrigger += 1
    }

    /// Demandes en attente, retirées de la file (la traduction est faite par `TranslationRunner`,
    /// là où la session de traduction est valide).
    func takePendingJobs() -> [TranslationJob] {
        let jobs = pendingJobs
        pendingJobs.removeAll()
        return jobs
    }

    /// Remet des demandes interrompues en tête de file.
    func requeue(_ jobs: [TranslationJob]) {
        pendingJobs.insert(contentsOf: jobs, at: 0)
    }

    func applyTranslation(_ job: TranslationJob, text: String) {
        translations[job.key] = .done(text)
        history?.record(comic: comic.name, page: job.page, original: job.text, translation: text)
    }

    func failTranslation(_ job: TranslationJob, message: String) {
        translations[job.key] = .failed(message)
    }

    // MARK: - Grammaire

    func explainSelected() {
        guard let bubble = selectedBubble else { return }
        let key = self.key(for: bubble)
        let sentence = TextNormalizer.forTranslation(self.text(for: bubble))
        grammar[key] = .loading
        Task {
            let report = await GrammarService.explain(sentence)
            grammar[key] = .done(report)
            history?.attachGrammar(report.summary, toOriginal: sentence)
        }
    }
}
