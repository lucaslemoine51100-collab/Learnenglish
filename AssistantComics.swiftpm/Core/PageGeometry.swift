import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Conversions entre l'image analysée d'une page et l'espace de coordonnées PDF de cette page.
///
/// Conventions :
/// - les rectangles « normalisés » sont exprimés entre 0 et 1, origine en bas à gauche
///   (convention de Vision), relativement à la page telle qu'elle est affichée (rotation appliquée) ;
/// - l'espace PDF a lui aussi son origine en bas à gauche ; la rotation PDF est donnée en degrés,
///   dans le sens horaire, comme `PDFPage.rotation`.
enum PageGeometry {

    /// Rotation ramenée à 0, 90, 180 ou 270.
    static func normalizedRotation(_ rotation: Int) -> Int {
        let r = ((rotation % 360) + 360) % 360
        return (r / 90) * 90
    }

    /// Taille de la page telle qu'affichée (après rotation), en points PDF.
    static func displayedSize(box: CGRect, rotation: Int) -> CGSize {
        switch normalizedRotation(rotation) {
        case 90, 270: return CGSize(width: box.height, height: box.width)
        default: return box.size
        }
    }

    /// Taille en pixels de l'image à produire pour que son plus grand côté mesure `maxDimension`.
    static func renderSize(box: CGRect, rotation: Int, maxDimension: CGFloat) -> CGSize {
        let size = displayedSize(box: box, rotation: rotation)
        let longest = max(size.width, size.height)
        guard longest > 0, maxDimension > 0 else { return .zero }
        let scale = maxDimension / longest
        return CGSize(width: max(1, (size.width * scale).rounded()),
                      height: max(1, (size.height * scale).rounded()))
    }

    /// Convertit un point normalisé (u, v) de l'image affichée en point de l'espace PDF.
    static func pagePoint(u: CGFloat, v: CGFloat, box: CGRect, rotation: Int) -> CGPoint {
        switch normalizedRotation(rotation) {
        case 90:
            return CGPoint(x: box.maxX - v * box.width, y: box.minY + u * box.height)
        case 180:
            return CGPoint(x: box.maxX - u * box.width, y: box.maxY - v * box.height)
        case 270:
            return CGPoint(x: box.minX + v * box.width, y: box.maxY - u * box.height)
        default:
            return CGPoint(x: box.minX + u * box.width, y: box.minY + v * box.height)
        }
    }

    /// Convertit un rectangle normalisé de l'image affichée en rectangle de l'espace PDF.
    static func pageRect(fromNormalized rect: CGRect, box: CGRect, rotation: Int) -> CGRect {
        let a = pagePoint(u: rect.minX, v: rect.minY, box: box, rotation: rotation)
        let b = pagePoint(u: rect.maxX, v: rect.maxY, box: box, rotation: rotation)
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                      width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
}
