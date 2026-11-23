import XCTest
import CoreGraphics
@testable import ComicsCore

final class PageGeometryTests: XCTestCase {

    func testNormalizedRotation() {
        XCTAssertEqual(PageGeometry.normalizedRotation(0), 0)
        XCTAssertEqual(PageGeometry.normalizedRotation(-90), 270)
        XCTAssertEqual(PageGeometry.normalizedRotation(450), 90)
        XCTAssertEqual(PageGeometry.normalizedRotation(180), 180)
    }

    func testRenderSizeKeepsAspectRatio() {
        let box = CGRect(x: 0, y: 0, width: 600, height: 900)
        XCTAssertEqual(PageGeometry.renderSize(box: box, rotation: 0, maxDimension: 2800),
                       CGSize(width: 1867, height: 2800))
        XCTAssertEqual(PageGeometry.renderSize(box: box, rotation: 90, maxDimension: 2800),
                       CGSize(width: 2800, height: 1867))
        XCTAssertEqual(PageGeometry.renderSize(box: .zero, rotation: 0, maxDimension: 2800), .zero)
    }

    func testPageRectWithoutRotation() {
        let box = CGRect(x: 0, y: 0, width: 600, height: 900)
        let rect = PageGeometry.pageRect(fromNormalized: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.1),
                                         box: box, rotation: 0)
        XCTAssertEqual(rect.minX, 60, accuracy: 0.001)
        XCTAssertEqual(rect.minY, 180, accuracy: 0.001)
        XCTAssertEqual(rect.width, 180, accuracy: 0.001)
        XCTAssertEqual(rect.height, 90, accuracy: 0.001)
    }

    func testPageRectHonoursBoxOrigin() {
        let box = CGRect(x: 10, y: 20, width: 100, height: 200)
        let rect = PageGeometry.pageRect(fromNormalized: CGRect(x: 0, y: 0, width: 1, height: 1),
                                         box: box, rotation: 0)
        XCTAssertEqual(rect, box)
    }

    func testRotatedPagesMapCornersCorrectly() {
        // Page portrait 100 × 200 ; le coin haut-gauche de la page est (0, 200).
        let box = CGRect(x: 0, y: 0, width: 100, height: 200)
        // Tournée de 90° (sens horaire), le haut-gauche de la page apparaît en haut à droite de l'affichage.
        XCTAssertEqual(PageGeometry.pagePoint(u: 1, v: 1, box: box, rotation: 90), CGPoint(x: 0, y: 200))
        // Tournée de 180°, le bas-gauche de l'affichage correspond au haut-droit de la page.
        XCTAssertEqual(PageGeometry.pagePoint(u: 0, v: 0, box: box, rotation: 180), CGPoint(x: 100, y: 200))
        // Tournée de 270°, le haut-gauche de la page apparaît en bas à gauche de l'affichage.
        XCTAssertEqual(PageGeometry.pagePoint(u: 0, v: 0, box: box, rotation: 270), CGPoint(x: 0, y: 200))
    }

    func testRotatedRectStaysInsidePage() {
        let box = CGRect(x: 0, y: 0, width: 100, height: 200)
        for rotation in [0, 90, 180, 270] {
            let rect = PageGeometry.pageRect(fromNormalized: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.2),
                                             box: box, rotation: rotation)
            XCTAssertTrue(box.contains(rect), "rotation \(rotation) : \(rect)")
        }
    }
}
