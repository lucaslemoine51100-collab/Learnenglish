import Foundation
import CoreGraphics
import PDFKit
import UIKit
import Vision

enum AnalysisError: LocalizedError {
    case pageUnavailable
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .pageUnavailable: return "La page n'a pas pu être lue dans le PDF."
        case .renderFailed: return "La page n'a pas pu être convertie en image."
        }
    }
}

/// Analyse d'une page : rendu en image → OCR Vision (sur l'iPad) → regroupement en bulles.
enum PageAnalyzer {

    /// Plus grand côté de l'image envoyée à l'OCR, en pixels.
    static let renderMaxDimension: CGFloat = 2800

    /// Analyse la page hors du fil principal, à partir d'une instance PDF dédiée (PDFKit n'est pas garanti
    /// sûr entre fils d'exécution : on n'utilise pas le document affiché).
    static func analyze(url: URL, pageIndex: Int) async throws -> [Bubble] {
        try await Task.detached(priority: .userInitiated) {
            try analyzeSynchronously(url: url, pageIndex: pageIndex)
        }.value
    }

    static func analyzeSynchronously(url: URL, pageIndex: Int) throws -> [Bubble] {
        guard let document = PDFDocument(url: url), let page = document.page(at: pageIndex) else {
            throw AnalysisError.pageUnavailable
        }
        let image = try render(page: page, maxDimension: renderMaxDimension)
        let lines = try recognizeText(in: image)
        let aspect = Double(image.width) / Double(max(image.height, 1))
        return BubbleGrouper().group(lines, imageAspectRatio: aspect)
    }

    /// Rend la page (rotation comprise) dans une image RVB opaque de taille maîtrisée.
    static func render(page: PDFPage, maxDimension: CGFloat) throws -> CGImage {
        let box = page.bounds(for: .cropBox)
        let size = PageGeometry.renderSize(box: box, rotation: page.rotation, maxDimension: maxDimension)
        let width = Int(size.width), height = Int(size.height)
        guard width > 0, height > 0 else { throw AnalysisError.renderFailed }

        let thumbnail = page.thumbnail(of: size, for: .cropBox)
        guard let source = thumbnail.cgImage,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw AnalysisError.renderFailed }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(rect)
        context.interpolationQuality = .high
        context.draw(source, in: rect)
        guard let image = context.makeImage() else { throw AnalysisError.renderFailed }
        return image
    }

    /// OCR anglais avec Vision, exécuté sur l'appareil.
    static func recognizeText(in image: CGImage) throws -> [OCRLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        // Par défaut Vision ignore le texte de moins de 1/32 de la hauteur de l'image :
        // trop grand pour le lettrage d'une page entière de comics.
        request.minimumTextHeight = 0.005

        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try handler.perform([request])
        let observations = request.results ?? []
        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return OCRLine(text: candidate.string,
                           confidence: Double(candidate.confidence),
                           box: observation.boundingBox)
        }
    }
}
