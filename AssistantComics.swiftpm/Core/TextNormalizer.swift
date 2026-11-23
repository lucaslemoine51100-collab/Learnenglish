import Foundation

/// Mise en forme du texte reconnu dans les bulles (les comics sont presque toujours écrits en majuscules).
enum TextNormalizer {

    /// Vrai si au moins 80 % des lettres sont des majuscules.
    static func isMostlyUppercase(_ text: String) -> Bool {
        let letters = text.filter { $0.isLetter }
        guard letters.count >= 2 else { return false }
        let upper = letters.filter { $0.isUppercase }.count
        return Double(upper) / Double(letters.count) >= 0.8
    }

    /// Nettoyage commun : apostrophes typographiques, tirets doubles, espaces.
    static func clean(_ text: String) -> String {
        var s = text
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "--", with: "\u{2014}")
            .replacingOccurrences(of: "\n", with: " ")
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        for mark in ["?", "!", ",", "."] {
            s = s.replacingOccurrences(of: " " + mark, with: mark)
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Passe un texte en « casse de phrase » : minuscules, majuscule en début de phrase et pour « I ».
    /// Les points de suspension (« ... ») ne déclenchent pas de majuscule : en comics ils prolongent la phrase.
    static func sentenceCase(_ text: String) -> String {
        let chars = Array(text.lowercased())
        var out = ""
        out.reserveCapacity(chars.count)
        var capitalizeNext = true
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if capitalizeNext && ch.isLetter {
                out += String(ch).uppercased()
                capitalizeNext = false
            } else {
                out.append(ch)
            }
            if ch == "!" || ch == "?" {
                capitalizeNext = true
            } else if ch == "." {
                let previousIsDot = i > 0 && chars[i - 1] == "."
                let nextIsDot = i + 1 < chars.count && chars[i + 1] == "."
                if !previousIsDot && !nextIsDot { capitalizeNext = true }
            }
            i += 1
        }
        return capitalizePronounI(out)
    }

    /// Texte affiché à l'utilisateur et envoyé à la traduction.
    static func display(_ raw: String) -> String {
        let cleaned = clean(raw)
        return isMostlyUppercase(cleaned) ? sentenceCase(cleaned) : cleaned
    }

    /// Texte prêt pour la traduction (identique à l'affichage, après une éventuelle correction manuelle).
    static func forTranslation(_ text: String) -> String {
        clean(text)
    }

    private static func capitalizePronounI(_ text: String) -> String {
        let chars = Array(text)
        var out = chars
        for (index, ch) in chars.enumerated() where ch == "i" {
            let before: Character? = index > 0 ? chars[index - 1] : nil
            let after: Character? = index + 1 < chars.count ? chars[index + 1] : nil
            let isolatedBefore = before.map { !$0.isLetter && $0 != "'" } ?? true
            let isolatedAfter = after.map { !$0.isLetter } ?? true
            if isolatedBefore && isolatedAfter { out[index] = "I" }
        }
        return String(out)
    }
}
