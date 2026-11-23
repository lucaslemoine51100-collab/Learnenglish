import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Une ligne de texte reconnue par l'OCR.
struct OCRLine: Equatable {
    var text: String
    var confidence: Double
    /// Rectangle normalisé (0…1), origine en bas à gauche (convention Vision), relatif à l'image analysée.
    var box: CGRect
}

enum BubbleKind: Equatable {
    /// Texte de taille courante : dialogue, pensée, récitatif.
    case dialogue
    /// Texte nettement plus grand que la moyenne : titre ou onomatopée probable.
    case largeText
}

/// Une bulle (ou un bloc de texte) détectée, numérotée dans l'ordre de lecture.
struct Bubble: Identifiable, Equatable {
    /// Numéro dans l'ordre de lecture, à partir de 1.
    let id: Int
    /// Lignes de la bulle, de haut en bas, telles que reconnues.
    let lines: [String]
    /// Texte brut (lignes réunies).
    let rawText: String
    /// Texte mis en forme pour l'affichage et la traduction.
    let displayText: String
    /// Rectangle normalisé englobant la bulle, origine en bas à gauche.
    let box: CGRect
    /// Confiance moyenne de l'OCR (0…1).
    let confidence: Double
    let kind: BubbleKind
}

/// Regroupe les lignes reconnues par l'OCR en bulles, puis les numérote dans un ordre de lecture approché
/// (de haut en bas, puis de gauche à droite pour les bulles situées à la même hauteur).
///
/// Il n'existe pas d'API Apple de détection de bulles : ce regroupement est une heuristique géométrique.
/// Deux lignes appartiennent à la même bulle si elles ont une taille de texte proche, sont empilées avec un
/// faible interligne et se chevauchent horizontalement (le texte des bulles est centré).
struct BubbleGrouper {

    struct Options: Equatable {
        /// Lignes dont la confiance OCR est inférieure à ce seuil ignorées.
        var minConfidence: Double = 0.3
        /// Écart vertical maximal entre deux lignes d'une même bulle, en hauteur de ligne.
        var maxVerticalGap: Double = 0.75
        /// Rapport maximal entre les hauteurs de deux lignes d'une même bulle.
        var maxHeightRatio: Double = 1.8
        /// Écart horizontal maximal entre deux morceaux d'une même ligne, en hauteur de ligne.
        var maxSameRowGap: Double = 1.2
        /// Chevauchement horizontal minimal entre deux lignes empilées, en fraction de la ligne la plus étroite.
        var minHorizontalOverlap: Double = 0.15
        /// Au-delà de ce multiple de la hauteur médiane, le texte est classé « grand texte ».
        var largeTextFactor: Double = 2.2
    }

    var options = Options()

    /// - Parameters:
    ///   - lines: lignes reconnues par l'OCR.
    ///   - imageAspectRatio: largeur / hauteur de l'image analysée (pour comparer distances horizontales et verticales).
    func group(_ lines: [OCRLine], imageAspectRatio: Double) -> [Bubble] {
        let aspect = imageAspectRatio > 0 ? imageAspectRatio : 1
        let items = lines.enumerated().compactMap { index, line -> Item? in
            guard isUseful(line) else { return nil }
            return Item(index: index, line: line, aspect: aspect)
        }
        guard !items.isEmpty else { return [] }

        // 1. Union des lignes compatibles.
        var parent = Array(0..<items.count)
        func find(_ x: Int) -> Int {
            var x = x
            while parent[x] != x {
                parent[x] = parent[parent[x]]
                x = parent[x]
            }
            return x
        }
        for a in 0..<items.count {
            for b in (a + 1)..<items.count where compatible(items[a], items[b]) {
                let ra = find(a), rb = find(b)
                if ra != rb { parent[rb] = ra }
            }
        }
        var groups: [Int: [Item]] = [:]
        for i in 0..<items.count { groups[find(i), default: []].append(items[i]) }

        // 2. Construction des blocs.
        let medianHeight = median(items.map(\.height))
        var blocks = groups.values.map { makeBlock($0, medianHeight: medianHeight) }

        // 3. Ordre de lecture : rangées de haut en bas, puis gauche → droite dans une rangée.
        blocks.sort { $0.top < $1.top }
        var rows: [[Block]] = []
        for block in blocks {
            if let anchor = rows.last?.first {
                let overlap = min(anchor.bottom, block.bottom) - max(anchor.top, block.top)
                if overlap > 0.3 * min(anchor.height, block.height) {
                    rows[rows.count - 1].append(block)
                    continue
                }
            }
            rows.append([block])
        }
        let ordered = rows.flatMap { $0.sorted { $0.left < $1.left } }

        return ordered.enumerated().map { offset, block in
            Bubble(id: offset + 1,
                   lines: block.lines,
                   rawText: block.text,
                   displayText: TextNormalizer.display(block.text),
                   box: block.box,
                   confidence: block.confidence,
                   kind: block.kind)
        }
    }

    // MARK: - Filtrage

    private func isUseful(_ line: OCRLine) -> Bool {
        let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, line.confidence >= options.minConfidence else { return false }
        guard line.box.width > 0, line.box.height > 0 else { return false }
        let hasLetter = text.contains { $0.isLetter }
        let hasPunctuation = text.contains("?") || text.contains("!")
        guard hasLetter || hasPunctuation else { return false }
        // Numéros de page et autres nombres isolés.
        if text.allSatisfy({ $0.isNumber || $0.isWhitespace }) { return false }
        return true
    }

    // MARK: - Compatibilité de deux lignes

    private func compatible(_ a: Item, _ b: Item) -> Bool {
        let hMin = min(a.height, b.height), hMax = max(a.height, b.height)
        guard hMin > 0, hMax / hMin <= options.maxHeightRatio else { return false }
        let avgHeight = (a.height + b.height) / 2
        let verticalOverlap = min(a.bottom, b.bottom) - max(a.top, b.top)

        if verticalOverlap > 0.5 * hMin {
            // Même ligne de texte découpée en plusieurs morceaux par l'OCR.
            let horizontalGap = max(a.left, b.left) - min(a.right, b.right)
            return horizontalGap <= options.maxSameRowGap * avgHeight
        }
        // Lignes empilées.
        let verticalGap = -verticalOverlap
        guard verticalGap <= options.maxVerticalGap * avgHeight else { return false }
        let horizontalOverlap = min(a.right, b.right) - max(a.left, b.left)
        return horizontalOverlap >= options.minHorizontalOverlap * min(a.width, b.width)
    }

    // MARK: - Construction d'un bloc

    private func makeBlock(_ members: [Item], medianHeight: Double) -> Block {
        // Regroupe les morceaux d'une même ligne, puis ordonne les lignes de haut en bas.
        let sorted = members.sorted { $0.top < $1.top }
        var rows: [[Item]] = []
        for item in sorted {
            if let anchor = rows.last?.first {
                let overlap = min(anchor.bottom, item.bottom) - max(anchor.top, item.top)
                if overlap > 0.5 * min(anchor.height, item.height) {
                    rows[rows.count - 1].append(item)
                    continue
                }
            }
            rows.append([item])
        }
        let lineTexts = rows.map { row in
            row.sorted { $0.left < $1.left }
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .joined(separator: " ")
        }
        let text = BubbleGrouper.joinLines(lineTexts)

        var box = members[0].line.box
        for item in members.dropFirst() { box = box.union(item.line.box) }
        let confidence = members.map(\.line.confidence).reduce(0, +) / Double(members.count)
        let averageHeight = members.map(\.height).reduce(0, +) / Double(members.count)
        let kind: BubbleKind = (medianHeight > 0 && averageHeight > options.largeTextFactor * medianHeight)
            ? .largeText : .dialogue

        return Block(lines: lineTexts, text: text, box: box, confidence: confidence, kind: kind,
                     top: members.map(\.top).min() ?? 0,
                     bottom: members.map(\.bottom).max() ?? 0,
                     left: members.map(\.left).min() ?? 0)
    }

    /// Réunit les lignes d'une bulle. Un mot coupé en fin de ligne (« AMAZ- / ING ») est recollé sans espace ;
    /// un tiret double (« WAIT-- ») est conservé avec un espace.
    static func joinLines(_ lines: [String]) -> String {
        var result = ""
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if result.isEmpty {
                result = line
            } else if result.hasSuffix("-") && !result.hasSuffix("--") {
                result += line
            } else {
                result += " " + line
            }
        }
        while result.contains("  ") { result = result.replacingOccurrences(of: "  ", with: " ") }
        return result
    }

    private func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let s = values.sorted()
        let mid = s.count / 2
        return s.count % 2 == 0 ? (s[mid - 1] + s[mid]) / 2 : s[mid]
    }

    // MARK: - Types internes

    /// Ligne exprimée dans un repère à origine en haut à gauche, en unités de « hauteur d'image ».
    private struct Item {
        let index: Int
        let line: OCRLine
        let text: String
        let left: Double, right: Double, top: Double, bottom: Double

        var width: Double { right - left }
        var height: Double { bottom - top }

        init(index: Int, line: OCRLine, aspect: Double) {
            self.index = index
            self.line = line
            self.text = line.text
            left = Double(line.box.minX) * aspect
            right = Double(line.box.maxX) * aspect
            top = 1 - Double(line.box.maxY)
            bottom = 1 - Double(line.box.minY)
        }
    }

    private struct Block {
        let lines: [String]
        let text: String
        let box: CGRect
        let confidence: Double
        let kind: BubbleKind
        let top: Double, bottom: Double, left: Double
        var height: Double { bottom - top }
    }
}
