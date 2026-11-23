import XCTest
import CoreGraphics
@testable import ComicsCore

final class BubbleGrouperTests: XCTestCase {

    /// Ligne OCR à partir de coordonnées normalisées Vision (origine en bas à gauche).
    private func line(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                      confidence: Double = 0.9) -> OCRLine {
        OCRLine(text: text, confidence: confidence, box: CGRect(x: x, y: y, width: w, height: h))
    }

    private var samplePage: [OCRLine] {
        [
            // Bulle A, en haut à gauche, deux lignes centrées.
            line("I'M GONNA", x: 0.15, y: 0.880, w: 0.20, h: 0.02),
            line("FIND HIM!", x: 0.17, y: 0.855, w: 0.16, h: 0.02),
            // Bulle B, en haut à droite, à la même hauteur.
            line("WHO ARE YOU?", x: 0.60, y: 0.860, w: 0.25, h: 0.02),
            // Bulle C, au milieu.
            line("LOOK OUT!", x: 0.30, y: 0.400, w: 0.20, h: 0.02),
            // Onomatopée géante.
            line("BOOM", x: 0.60, y: 0.200, w: 0.30, h: 0.08),
            // Numéro de page et ligne peu fiable : ignorés.
            line("12", x: 0.48, y: 0.020, w: 0.04, h: 0.015),
            line("XYZ", x: 0.10, y: 0.100, w: 0.05, h: 0.02, confidence: 0.1)
        ]
    }

    func testGroupsLinesIntoBubblesInReadingOrder() {
        let bubbles = BubbleGrouper().group(samplePage, imageAspectRatio: 2.0 / 3.0)
        XCTAssertEqual(bubbles.map(\.id), [1, 2, 3, 4])
        XCTAssertEqual(bubbles.map(\.rawText), ["I'M GONNA FIND HIM!", "WHO ARE YOU?", "LOOK OUT!", "BOOM"])
        XCTAssertEqual(bubbles[0].displayText, "I'm gonna find him!")
        XCTAssertEqual(bubbles[0].lines, ["I'M GONNA", "FIND HIM!"])
    }

    func testLargeTextIsFlagged() {
        let bubbles = BubbleGrouper().group(samplePage, imageAspectRatio: 2.0 / 3.0)
        XCTAssertEqual(bubbles.last?.kind, .largeText)
        XCTAssertEqual(bubbles.first?.kind, .dialogue)
    }

    func testBubbleBoxIsUnionOfLines() {
        let bubbles = BubbleGrouper().group(samplePage, imageAspectRatio: 2.0 / 3.0)
        let box = bubbles[0].box
        XCTAssertEqual(box.minX, 0.15, accuracy: 0.0001)
        XCTAssertEqual(box.maxX, 0.35, accuracy: 0.0001)
        XCTAssertEqual(box.minY, 0.855, accuracy: 0.0001)
        XCTAssertEqual(box.maxY, 0.90, accuracy: 0.0001)
    }

    func testFragmentsOfTheSameLineAreMerged() {
        let lines = [
            line("THERE", x: 0.21, y: 0.5, w: 0.09, h: 0.02),
            line("HELLO", x: 0.10, y: 0.5, w: 0.10, h: 0.02)
        ]
        let bubbles = BubbleGrouper().group(lines, imageAspectRatio: 1)
        XCTAssertEqual(bubbles.count, 1)
        XCTAssertEqual(bubbles.first?.rawText, "HELLO THERE")
    }

    func testDistantStackedBubblesStaySeparate() {
        let lines = [
            line("FIRST BUBBLE", x: 0.30, y: 0.70, w: 0.30, h: 0.02),
            line("SECOND BUBBLE", x: 0.30, y: 0.62, w: 0.30, h: 0.02)
        ]
        let bubbles = BubbleGrouper().group(lines, imageAspectRatio: 1)
        XCTAssertEqual(bubbles.map(\.rawText), ["FIRST BUBBLE", "SECOND BUBBLE"])
    }

    func testEmptyInput() {
        XCTAssertTrue(BubbleGrouper().group([], imageAspectRatio: 1).isEmpty)
    }

    func testJoinLinesHandlesHyphens() {
        XCTAssertEqual(BubbleGrouper.joinLines(["AMAZ-", "ING!"]), "AMAZ-ING!")
        XCTAssertEqual(BubbleGrouper.joinLines(["WAIT--", "WHAT?"]), "WAIT-- WHAT?")
        XCTAssertEqual(BubbleGrouper.joinLines(["  HELLO ", "", "YOU"]), "HELLO YOU")
    }
}
