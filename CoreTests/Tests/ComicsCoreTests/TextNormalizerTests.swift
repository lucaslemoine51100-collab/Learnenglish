import XCTest
@testable import ComicsCore

final class TextNormalizerTests: XCTestCase {

    func testUppercaseDetection() {
        XCTAssertTrue(TextNormalizer.isMostlyUppercase("HELLO THERE!"))
        XCTAssertTrue(TextNormalizer.isMostlyUppercase("I'M SPIDER-MAN, OK?"))
        XCTAssertFalse(TextNormalizer.isMostlyUppercase("Hello there"))
        XCTAssertFalse(TextNormalizer.isMostlyUppercase("!?"))
    }

    func testSentenceCase() {
        XCTAssertEqual(TextNormalizer.sentenceCase("WHERE IS SHE? TELL ME!"), "Where is she? Tell me!")
        XCTAssertEqual(TextNormalizer.sentenceCase("THIS IS IT."), "This is it.")
    }

    func testEllipsisDoesNotCapitalizeAndPronounIIsCapitalized() {
        XCTAssertEqual(TextNormalizer.sentenceCase("I'M GONNA FIND HIM... AND I'LL STOP HIM!"),
                       "I'm gonna find him... and I'll stop him!")
    }

    func testDisplayCleansAndConvertsUppercaseText() {
        XCTAssertEqual(TextNormalizer.display("WAIT--WHAT ?"), "Wait\u{2014}what?")
        XCTAssertEqual(TextNormalizer.display("It\u{2019}s  fine ."), "It's fine.")
    }

    func testMixedCaseTextIsKept() {
        XCTAssertEqual(TextNormalizer.display("Hello, Peter."), "Hello, Peter.")
    }
}
