import XCTest
@testable import ComicsCore

final class GrammarAnalyzerTests: XCTestCase {

    private func titles(_ text: String) -> [String] {
        GrammarAnalyzer.analyze(text).map(\.title)
    }

    func testTablesAreConsistent() {
        // Accéder aux tables statiques vérifie qu'elles se construisent sans erreur.
        XCTAssertTrue(GrammarAnalyzer.irregularPasts.contains("went"))
        XCTAssertTrue(GrammarAnalyzer.irregularParticiples.contains("gone"))
        XCTAssertFalse(GrammarAnalyzer.contractions.isEmpty)
        XCTAssertFalse(GrammarAnalyzer.informalWords.isEmpty)
    }

    func testTokenization() {
        XCTAssertEqual(GrammarAnalyzer.rawTokens("I\u{2019}M GOIN' HOME!"), ["i'm", "goin'", "home"])
        XCTAssertEqual(GrammarAnalyzer.normalizeToken("goin'"), "going")
        XCTAssertEqual(GrammarAnalyzer.normalizeToken("'em"), "them")
    }

    func testGonnaAndContractions() {
        let t = titles("I'm gonna find him!")
        XCTAssertTrue(t.contains("Contractions et formes familières"))
        XCTAssertTrue(t.contains("Futur proche (be going to)"))
    }

    func testPresentPerfectContinuous() {
        let t = titles("We've been waiting for hours.")
        XCTAssertTrue(t.contains("Present perfect continu (have been + V-ing)"))
        XCTAssertFalse(t.contains("Présent continu (be + V-ing)"))
    }

    func testPastSimpleQuestion() {
        let t = titles("Did you see that?")
        XCTAssertTrue(t.contains("Prétérit (passé simple)"))
        XCTAssertTrue(t.contains("Question fermée (inversion)"))
    }

    func testOpenQuestionWithContinuous() {
        let t = titles("Where are you going?")
        XCTAssertTrue(t.contains("Question ouverte (mot interrogatif)"))
        XCTAssertTrue(t.contains("Présent continu (be + V-ing)"))
    }

    func testImperativeAndPhrasalVerb() {
        let t = titles("Look out!")
        XCTAssertTrue(t.contains("Impératif"))
        XCTAssertTrue(t.contains("Verbes à particule (phrasal verbs)"))
    }

    func testConditional() {
        let points = GrammarAnalyzer.analyze("If I were you, I wouldn't do that.")
        XCTAssertTrue(points.map(\.title).contains("Condition avec if"))
        let modals = points.first { $0.title == "Verbes modaux et obligation" }
        XCTAssertNotNil(modals)
        XCTAssertTrue(modals?.explanation.contains("wouldn't") ?? false)
    }

    func testPassive() {
        XCTAssertTrue(titles("The city was destroyed.").contains("Be + participe passé (passif ou adjectif)"))
    }

    func testHaveGot() {
        XCTAssertTrue(titles("He's got a gun.").contains("Have got : possession"))
    }

    func testFutureWithWill() {
        XCTAssertTrue(titles("I'll stop him.").contains("Futur avec will"))
    }

    func testLetsGo() {
        let t = titles("Let's go!")
        XCTAssertTrue(t.contains("Let's + verbe : proposition"))
        XCTAssertTrue(t.contains("Expressions courantes"))
    }

    func testNothingSpecial() {
        XCTAssertEqual(titles("Hello."), ["Aucune structure particulière repérée"])
    }

    func testTitlesAreUnique() {
        let t = titles("Did you see that? I saw him. He ran away and I didn't follow him!")
        XCTAssertEqual(t.count, Set(t).count)
    }

    func testVerbMatching() {
        XCTAssertTrue(GrammarAnalyzer.matchesVerb("getting", base: "get"))
        XCTAssertTrue(GrammarAnalyzer.matchesVerb("came", base: "come"))
        XCTAssertTrue(GrammarAnalyzer.matchesVerb("coming", base: "come"))
        XCTAssertTrue(GrammarAnalyzer.matchesVerb("backed", base: "back"))
        XCTAssertFalse(GrammarAnalyzer.matchesVerb("gate", base: "get"))
    }
}
