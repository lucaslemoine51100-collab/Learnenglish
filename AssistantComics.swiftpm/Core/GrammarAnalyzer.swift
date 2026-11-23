import Foundation

/// Un point de grammaire repéré dans une réplique.
struct GrammarPoint: Equatable, Identifiable {
    var id: String { title }
    let title: String
    let explanation: String
    /// Extraits de la réplique concernés (en minuscules).
    let examples: [String]
}

/// Analyse grammaticale par règles, entièrement locale et sans IA.
///
/// Elle sert de repli quand Apple Intelligence n'est pas disponible, et de « repères » complémentaires sinon.
/// Les règles sont volontairement simples : elles signalent des structures probables, pas une analyse complète.
enum GrammarAnalyzer {

    static func analyze(_ text: String) -> [GrammarPoint] {
        let raw = rawTokens(text)
        let tokens = raw.map(normalizeToken).filter { !$0.isEmpty }
        var points: [GrammarPoint] = []
        if let p = contractionsPoint(raw) { points.append(p) }
        points += verbFormPoints(tokens)
        if let p = modalsPoint(tokens) { points.append(p) }
        points += sentencePoints(text)
        if let p = phrasalVerbsPoint(tokens) { points.append(p) }
        if let p = expressionsPoint(tokens) { points.append(p) }
        if points.isEmpty {
            points.append(GrammarPoint(
                title: "Aucune structure particulière repérée",
                explanation: "La phrase est probablement au présent simple, ou ne contient pas de verbe conjugué (exclamation, phrase nominale).",
                examples: []))
        }
        return merged(points)
    }

    // MARK: - Découpage

    /// Mots en minuscules, apostrophes conservées (« i'm », « goin' »).
    static func rawTokens(_ text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .lowercased()
        var tokens: [String] = []
        var current = ""
        for ch in normalized {
            if ch.isLetter || ch == "'" {
                current.append(ch)
            } else if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// « goin' » → « going », apostrophes de début et de fin retirées (sauf « 'em »).
    static func normalizeToken(_ token: String) -> String {
        if token == "'em" { return "them" }
        var t = token
        if t.count >= 4 && t.hasSuffix("in'") { t = String(t.dropLast()) + "g" }
        while t.hasPrefix("'") { t.removeFirst() }
        while t.hasSuffix("'") { t.removeLast() }
        return t
    }

    // MARK: - Contractions et formes familières

    static let contractions: [String: String] = [
        "i'm": "I am", "you're": "you are", "we're": "we are", "they're": "they are",
        "he's": "he is / he has", "she's": "she is / she has", "it's": "it is / it has",
        "that's": "that is", "what's": "what is / what has", "there's": "there is",
        "here's": "here is", "who's": "who is / who has", "where's": "where is",
        "let's": "let us (proposition : « allons… »)",
        "i'll": "I will", "you'll": "you will", "he'll": "he will", "she'll": "she will",
        "we'll": "we will", "they'll": "they will", "it'll": "it will", "that'll": "that will",
        "i've": "I have", "you've": "you have", "we've": "we have", "they've": "they have",
        "i'd": "I would / I had", "you'd": "you would / you had", "he'd": "he would / he had",
        "she'd": "she would / she had", "we'd": "we would / we had", "they'd": "they would / they had",
        "don't": "do not", "doesn't": "does not", "didn't": "did not", "can't": "cannot",
        "won't": "will not", "isn't": "is not", "aren't": "are not", "wasn't": "was not",
        "weren't": "were not", "haven't": "have not", "hasn't": "has not", "hadn't": "had not",
        "couldn't": "could not", "shouldn't": "should not", "wouldn't": "would not",
        "mustn't": "must not", "ain't": "am not / is not / have not (très familier)",
        "y'all": "you all (familier)", "'em": "them", "c'mon": "come on", "ma'am": "madam"
    ]

    static let informalWords: [String: String] = [
        "gonna": "going to (futur proche, oral)", "wanna": "want to (vouloir)",
        "gotta": "have got to / got to (devoir)", "gimme": "give me", "lemme": "let me",
        "kinda": "kind of (plutôt, un peu)", "sorta": "sort of (plutôt)", "outta": "out of",
        "dunno": "don't know (sais pas)", "ya": "you", "yeah": "yes", "yep": "yes", "nope": "no",
        "cuz": "because", "'cause": "because", "whaddya": "what do you",
        "gotcha": "got you (compris ! / je te tiens !)", "betcha": "bet you (je parie que)",
        "lotta": "lot of", "hafta": "have to", "oughta": "ought to (devrait)",
        "shoulda": "should have", "coulda": "could have", "woulda": "would have",
        "musta": "must have", "y'know": "you know"
    ]

    private static func contractionsPoint(_ raw: [String]) -> GrammarPoint? {
        var found: [String] = []
        func add(_ s: String) { if !found.contains(s) { found.append(s) } }
        for token in raw {
            if let full = contractions[token] {
                add("\(token) → \(full)")
            } else if let full = informalWords[token] {
                add("\(token) → \(full)")
            } else if token.count >= 4 && token.hasSuffix("in'") {
                add("\(token) → \(String(token.dropLast()) + "g") (-in' = -ing, prononciation familière)")
            } else if token.hasSuffix("n't") {
                add("\(token) → \(token.dropLast(3)) not")
            } else if token.hasSuffix("'ll") {
                add("\(token) → \(token.dropLast(3)) will")
            } else if token.hasSuffix("'ve") {
                add("\(token) → \(token.dropLast(3)) have")
            } else if token.hasSuffix("'re") {
                add("\(token) → \(token.dropLast(3)) are")
            } else if token.hasSuffix("'s") && token.count > 2 {
                add("\(token) → « 's » = is / has, ou marque du possessif (Tony's = de Tony)")
            }
        }
        guard !found.isEmpty else { return nil }
        return GrammarPoint(
            title: "Contractions et formes familières",
            explanation: "L'anglais oral (et donc les comics) contracte souvent les mots. Forme complète : " + found.joined(separator: " ; ") + ".",
            examples: [])
    }

    // MARK: - Formes verbales

    static let beForms: Set<String> = ["am", "is", "are", "was", "were", "be", "been", "being",
                                       "isn't", "aren't", "wasn't", "weren't", "ain't"]
    static let pastBeForms: Set<String> = ["was", "were", "wasn't", "weren't"]

    static func isBe(_ t: String) -> Bool {
        beForms.contains(t) || t.hasSuffix("'m") || t.hasSuffix("'re") || (t.hasSuffix("'s") && t != "let's")
    }
    static func isHave(_ t: String) -> Bool {
        ["have", "has", "haven't", "hasn't"].contains(t) || t.hasSuffix("'ve")
    }
    static func isHad(_ t: String) -> Bool {
        ["had", "hadn't"].contains(t) || t.hasSuffix("'d")
    }
    static func isWill(_ t: String) -> Bool {
        ["will", "won't", "shall"].contains(t) || t.hasSuffix("'ll")
    }

    /// Adverbes pouvant s'intercaler entre l'auxiliaire et le verbe (« is still running »).
    static let insertableAdverbs: Set<String> = [
        "not", "never", "really", "still", "just", "always", "already", "also", "even", "only",
        "so", "all", "now", "finally", "actually", "probably", "definitely", "totally", "seriously",
        "ever", "barely", "almost", "truly", "sure", "certainly", "clearly", "obviously", "simply"
    ]

    /// Index du mot suivant l'auxiliaire en sautant au plus deux adverbes et un pronom sujet
    /// (questions avec inversion : « are you going », « have you seen »).
    static func nextVerbIndex(after i: Int, in tokens: [String]) -> Int? {
        var j = i + 1
        var skippedAdverbs = 0
        var skippedPronoun = false
        while j < tokens.count {
            if insertableAdverbs.contains(tokens[j]) && skippedAdverbs < 2 {
                skippedAdverbs += 1
            } else if !skippedPronoun && subjectPronouns.contains(tokens[j]) && j + 1 < tokens.count {
                skippedPronoun = true
            } else {
                break
            }
            j += 1
        }
        return j < tokens.count ? j : nil
    }

    static let ingExclusions: Set<String> = [
        "thing", "something", "nothing", "anything", "everything", "king", "ring", "sing", "bring",
        "sting", "wing", "spring", "string", "swing", "morning", "evening", "ceiling", "during",
        "darling", "pudding", "wedding", "sibling", "viking", "fling", "cling", "sling", "wring",
        "awning", "lightning"
    ]

    static func isIng(_ t: String) -> Bool {
        t.count >= 5 && t.hasSuffix("ing") && !ingExclusions.contains(t)
    }

    static let edExclusions: Set<String> = [
        "bed", "red", "shed", "sled", "wed", "hundred", "naked", "wicked", "sacred", "ted", "ned",
        "fred", "jed", "embed", "shred", "infrared", "seabed", "biped", "rugged", "jagged",
        "ragged", "crooked", "beloved", "kindred"
    ]
    static let eedAllowed: Set<String> = ["freed", "agreed", "guaranteed", "decreed", "disagreed", "refereed"]

    static func isRegularEd(_ t: String) -> Bool {
        guard t.count >= 4, t.hasSuffix("ed"), !t.contains("'"), !edExclusions.contains(t) else { return false }
        if t.hasSuffix("eed") { return eedAllowed.contains(t) }
        return true
    }

    /// Verbes irréguliers courants : base → (prétérits, participes passés).
    static let irregularVerbs: [String: (past: [String], participle: [String])] = [
        "be": (["was", "were"], ["been"]), "beat": (["beat"], ["beaten"]),
        "become": (["became"], ["become"]), "begin": (["began"], ["begun"]),
        "bite": (["bit"], ["bitten"]), "blow": (["blew"], ["blown"]),
        "break": (["broke"], ["broken"]), "bring": (["brought"], ["brought"]),
        "build": (["built"], ["built"]), "buy": (["bought"], ["bought"]),
        "catch": (["caught"], ["caught"]), "choose": (["chose"], ["chosen"]),
        "come": (["came"], ["come"]), "cut": (["cut"], ["cut"]),
        "dig": (["dug"], ["dug"]), "do": (["did"], ["done"]),
        "draw": (["drew"], ["drawn"]), "drink": (["drank"], ["drunk"]),
        "drive": (["drove"], ["driven"]), "eat": (["ate"], ["eaten"]),
        "fall": (["fell"], ["fallen"]), "feel": (["felt"], ["felt"]),
        "fight": (["fought"], ["fought"]), "find": (["found"], ["found"]),
        "fly": (["flew"], ["flown"]), "forget": (["forgot"], ["forgotten"]),
        "freeze": (["froze"], ["frozen"]), "get": (["got"], ["got", "gotten"]),
        "give": (["gave"], ["given"]), "go": (["went"], ["gone"]),
        "grow": (["grew"], ["grown"]), "hang": (["hung"], ["hung"]),
        "have": (["had"], ["had"]), "hear": (["heard"], ["heard"]),
        "hide": (["hid"], ["hidden"]), "hit": (["hit"], ["hit"]),
        "hold": (["held"], ["held"]), "hurt": (["hurt"], ["hurt"]),
        "keep": (["kept"], ["kept"]), "know": (["knew"], ["known"]),
        "lead": (["led"], ["led"]), "leave": (["left"], ["left"]),
        "let": (["let"], ["let"]), "lose": (["lost"], ["lost"]),
        "make": (["made"], ["made"]), "mean": (["meant"], ["meant"]),
        "meet": (["met"], ["met"]), "pay": (["paid"], ["paid"]),
        "put": (["put"], ["put"]), "read": (["read"], ["read"]),
        "ride": (["rode"], ["ridden"]), "ring": (["rang"], ["rung"]),
        "rise": (["rose"], ["risen"]), "run": (["ran"], ["run"]),
        "say": (["said"], ["said"]), "see": (["saw"], ["seen"]),
        "sell": (["sold"], ["sold"]), "send": (["sent"], ["sent"]),
        "set": (["set"], ["set"]), "shake": (["shook"], ["shaken"]),
        "shoot": (["shot"], ["shot"]), "show": (["showed"], ["shown"]),
        "shut": (["shut"], ["shut"]), "sing": (["sang"], ["sung"]),
        "sit": (["sat"], ["sat"]), "sleep": (["slept"], ["slept"]),
        "speak": (["spoke"], ["spoken"]), "stand": (["stood"], ["stood"]),
        "steal": (["stole"], ["stolen"]), "strike": (["struck"], ["struck"]),
        "swear": (["swore"], ["sworn"]), "swim": (["swam"], ["swum"]),
        "take": (["took"], ["taken"]), "teach": (["taught"], ["taught"]),
        "tear": (["tore"], ["torn"]), "tell": (["told"], ["told"]),
        "think": (["thought"], ["thought"]), "throw": (["threw"], ["thrown"]),
        "understand": (["understood"], ["understood"]), "wake": (["woke"], ["woken"]),
        "wear": (["wore"], ["worn"]), "win": (["won"], ["won"]),
        "write": (["wrote"], ["written"])
    ]

    static let irregularPasts: Set<String> = Set(irregularVerbs.values.flatMap { $0.past })
    static let irregularParticiples: Set<String> = Set(irregularVerbs.values.flatMap { $0.participle })
    /// Formes identiques à la base ou trop ambiguës pour signaler un prétérit seules.
    static let ambiguousPasts: Set<String> = ["cut", "hit", "let", "put", "read", "set", "shut", "hurt",
                                               "left", "rose", "bit", "saw", "beat"]

    static func isParticiple(_ t: String) -> Bool { irregularParticiples.contains(t) || isRegularEd(t) }
    static func isPastSimple(_ t: String) -> Bool {
        (irregularPasts.contains(t) && !ambiguousPasts.contains(t)) || isRegularEd(t)
    }

    private static func excerpt(_ tokens: [String], _ range: ClosedRange<Int>) -> String {
        let upper = min(range.upperBound, tokens.count - 1)
        guard range.lowerBound <= upper else { return "" }
        return tokens[range.lowerBound...upper].joined(separator: " ")
    }

    private static func verbFormPoints(_ tokens: [String]) -> [GrammarPoint] {
        var points: [GrammarPoint] = []
        var used = Set<Int>()
        func add(_ title: String, _ explanation: String, _ example: String) {
            points.append(GrammarPoint(title: title, explanation: explanation, examples: example.isEmpty ? [] : [example]))
        }

        for i in tokens.indices where !used.contains(i) {
            let t = tokens[i]
            let j = nextVerbIndex(after: i, in: tokens)

            // have got / 's got : possession.
            if (isHave(t) || t.hasSuffix("'s")), let j, tokens[j] == "got" {
                let toFollows = j + 1 < tokens.count && tokens[j + 1] == "to"
                add(toFollows ? "Have got to : obligation" : "Have got : possession",
                    toFollows ? "« have got to + verbe » = devoir (obligation), très courant à l'oral."
                              : "« have got » = avoir, posséder (anglais oral). « 's got » = « has got ».",
                    excerpt(tokens, i...(toFollows ? j + 1 : j)))
                used.formUnion([i, j]); continue
            }
            // Futur proche : be going to.
            if isBe(t), let j, tokens[j] == "going", j + 1 < tokens.count, tokens[j + 1] == "to" {
                add("Futur proche (be going to)",
                    "Intention ou prévision fondée sur des indices présents : « je vais… ». Forme : am/is/are going to + verbe à la base.",
                    excerpt(tokens, i...(j + 2)))
                used.formUnion([i, j, j + 1]); continue
            }
            if t == "gonna" {
                add("Futur proche (be going to)",
                    "« gonna » est la forme orale de « going to » : intention, « je vais… ».",
                    excerpt(tokens, max(0, i - 1)...(i + 1)))
                used.insert(i); continue
            }
            // Present perfect continu / past perfect continu.
            if isHave(t) || isHad(t), let j, tokens[j] == "been", j + 1 < tokens.count, isIng(tokens[j + 1]) {
                if isHave(t) {
                    add("Present perfect continu (have been + V-ing)",
                        "Action commencée dans le passé et toujours en cours (souvent avec for/since) : « ça fait… que je… ».",
                        excerpt(tokens, i...(j + 1)))
                } else {
                    add("Past perfect continu (had been + V-ing)",
                        "Action qui durait jusqu'à un moment du passé : « je… depuis… ».",
                        excerpt(tokens, i...(j + 1)))
                }
                used.formUnion([i, j, j + 1]); continue
            }
            // Futur avec will.
            if isWill(t), let j, !isParticiple(tokens[j]) || irregularVerbs[tokens[j]] != nil {
                add("Futur avec will",
                    "Décision prise sur le moment, promesse ou prédiction : « je ferai / je vais… ». Forme : will + verbe à la base ; négation : won't.",
                    excerpt(tokens, i...j))
                used.formUnion([i, j]); continue
            }
            // Formes continues.
            if isBe(t), let j, isIng(tokens[j]) {
                if pastBeForms.contains(t) {
                    add("Prétérit continu (was/were + V-ing)",
                        "Action qui était en cours à un moment du passé : « j'étais en train de… ».",
                        excerpt(tokens, i...j))
                } else {
                    add("Présent continu (be + V-ing)",
                        "Action en cours au moment où l'on parle (ou projet proche) : « je suis en train de… ». Forme : am/is/are + verbe en -ing.",
                        excerpt(tokens, i...j))
                }
                used.formUnion([i, j]); continue
            }
            // Present perfect / past perfect.
            if isHave(t), let j, isParticiple(tokens[j]) {
                add("Present perfect (have/has + participe passé)",
                    "Lien entre le passé et le présent : expérience, résultat visible maintenant, action qui dure. Souvent traduit par le passé composé.",
                    excerpt(tokens, i...j))
                used.formUnion([i, j]); continue
            }
            if isHad(t), let j, isParticiple(tokens[j]) {
                add("Past perfect (had + participe passé)",
                    "Action antérieure à un autre moment du passé : « j'avais fait ».",
                    excerpt(tokens, i...j))
                used.formUnion([i, j]); continue
            }
            // Be + participe passé.
            if isBe(t), let j, isParticiple(tokens[j]) {
                add("Be + participe passé (passif ou adjectif)",
                    "Voix passive (« être + participe » : the city was destroyed = la ville a été détruite) ou participe employé comme adjectif (I'm scared = j'ai peur).",
                    excerpt(tokens, i...j))
                used.formUnion([i, j]); continue
            }
            // Prétérit avec did.
            if t == "did" || t == "didn't" {
                add("Prétérit (passé simple)",
                    "Action terminée dans le passé. Questions et négations : did / didn't + verbe à la base.",
                    excerpt(tokens, i...(i + 2)))
                used.insert(i); continue
            }
        }

        // Prétérit simple (formes isolées).
        var pastExamples: [String] = []
        for i in tokens.indices where !used.contains(i) {
            let t = tokens[i]
            if isPastSimple(t) || pastBeForms.contains(t) || t == "had" {
                pastExamples.append(t)
            }
        }
        if !pastExamples.isEmpty {
            points.append(GrammarPoint(
                title: "Prétérit (passé simple)",
                explanation: "Action terminée dans le passé. Verbes réguliers en -ed ; irréguliers à apprendre (went, saw, took…). Souvent traduit par le passé composé ou l'imparfait.",
                examples: pastExamples))
        }
        return points
    }

    // MARK: - Modaux

    static let modalMeanings: [(String, String)] = [
        ("can", "can → capacité ou permission (pouvoir)"),
        ("can't", "can't → impossibilité, interdiction"),
        ("could", "could → capacité passée, possibilité, demande polie"),
        ("couldn't", "couldn't → impossibilité (passé ou hypothèse)"),
        ("should", "should → conseil (« devrait »)"),
        ("shouldn't", "shouldn't → conseil négatif (« ne devrait pas »)"),
        ("must", "must → obligation forte ou déduction (« doit sûrement »)"),
        ("mustn't", "mustn't → interdiction"),
        ("might", "might → possibilité faible (« peut-être »)"),
        ("may", "may → possibilité ou permission"),
        ("would", "would → conditionnel (« ferait »), demande polie, habitude passée"),
        ("wouldn't", "wouldn't → conditionnel négatif, refus"),
        ("ought", "ought to → conseil, devoir moral")
    ]

    private static func modalsPoint(_ tokens: [String]) -> GrammarPoint? {
        var found: [String] = []
        func add(_ s: String) { if !found.contains(s) { found.append(s) } }
        let set = Set(tokens)
        for (word, meaning) in modalMeanings where set.contains(word) { add(meaning) }
        for (i, t) in tokens.enumerated() {
            let next = i + 1 < tokens.count ? tokens[i + 1] : ""
            if (t == "have" || t == "has" || t == "had") && next == "to" {
                add("\(t) to → obligation (« devoir », souvent imposée de l'extérieur)")
            }
            if (t == "need" || t == "needs") && next == "to" { add("need to → nécessité (« avoir besoin de »)") }
            if t == "gotta" { add("gotta → « got to » : devoir (familier)") }
            if t.hasSuffix("'d"), t != "'d", !next.isEmpty, !isParticiple(next), !insertableAdverbs.contains(next) || next == "rather" {
                add("'d + verbe → would (conditionnel)")
            }
            if t == "rather" && i > 0 && tokens[i - 1].hasSuffix("'d") { add("'d rather → préférer (« je préférerais »)") }
            if t == "able" && next == "to" { add("be able to → être capable de (remplace can aux autres temps)") }
        }
        guard !found.isEmpty else { return nil }
        return GrammarPoint(
            title: "Verbes modaux et obligation",
            explanation: found.joined(separator: " ; ") + ". Après un modal, le verbe est à la base (sans to, sans -s).",
            examples: [])
    }

    // MARK: - Types de phrases

    static let whWords: Set<String> = ["what", "who", "where", "when", "why", "how", "which", "whose", "whom",
                                       "what's", "who's", "where's", "how's", "whaddya"]
    static let auxiliaries: Set<String> = ["do", "does", "did", "is", "are", "am", "was", "were", "can", "could",
                                           "will", "would", "have", "has", "had", "should", "shall", "may", "might",
                                           "must", "don't", "doesn't", "didn't", "isn't", "aren't", "wasn't",
                                           "weren't", "can't", "couldn't", "won't", "wouldn't", "haven't",
                                           "hasn't", "shouldn't"]
    static let imperativeVerbs: Set<String> = [
        "look", "come", "go", "get", "stop", "wait", "run", "help", "take", "give", "tell", "listen",
        "watch", "stay", "leave", "hold", "move", "keep", "back", "shut", "stand", "sit", "put", "try",
        "call", "follow", "hurry", "drop", "freeze", "duck", "catch", "grab", "open", "close", "think",
        "remember", "forget", "trust", "let", "calm", "relax", "hang", "step", "turn", "jump", "fire",
        "kill", "save", "find", "bring", "show", "make", "check", "answer", "say", "eat", "do"
    ]
    static let interjections: Set<String> = ["hey", "oh", "ok", "okay", "now", "so", "well", "please", "quick",
                                             "alright", "quickly", "guys", "man", "c'mon", "ah", "uh", "um", "and", "but"]

    private static func sentencePoints(_ text: String) -> [GrammarPoint] {
        var points: [GrammarPoint] = []
        var seen = Set<String>()
        func add(_ title: String, _ explanation: String, _ example: String) {
            guard !seen.contains(title) else { return }
            seen.insert(title)
            points.append(GrammarPoint(title: title, explanation: explanation, examples: example.isEmpty ? [] : [example]))
        }

        for sentence in splitSentences(text) {
            let tokens = rawTokens(sentence).map(normalizeToken).filter { !$0.isEmpty }
            guard !tokens.isEmpty else { continue }
            let firstIndex = tokens.firstIndex { !interjections.contains($0) } ?? 0
            let first = tokens[firstIndex]
            let isQuestion = sentence.contains("?")

            if isQuestion {
                let lower = sentence.lowercased()
                if lower.range(of: #",\s*(right|huh|eh)\s*\?"#, options: .regularExpression) != nil
                    || lower.range(of: #",\s*\w+n'?t\s+(it|you|he|she|they|we|i|there)\s*\?"#, options: .regularExpression) != nil {
                    add("Question-tag",
                        "Petite question ajoutée en fin de phrase pour demander confirmation : « …, n'est-ce pas ? », « hein ? ».",
                        sentence.trimmingCharacters(in: .whitespaces))
                } else if whWords.contains(first) {
                    add("Question ouverte (mot interrogatif)",
                        "Mot interrogatif (what, who, where, why, how…) + auxiliaire + sujet + verbe : « What are you doing? ».",
                        first)
                } else if auxiliaries.contains(first) {
                    add("Question fermée (inversion)",
                        "L'auxiliaire passe avant le sujet ; on répond par oui ou non : « Are you OK? », « Did you see that? ».",
                        first)
                } else {
                    add("Question par l'intonation",
                        "Ordre de la phrase affirmative + point d'interrogation : tournure orale et familière.",
                        "")
                }
            } else if first == "let's" {
                add("Let's + verbe : proposition",
                    "« Let's go! » = « Allons-y ! ». Let's (= let us) + verbe à la base propose une action commune.",
                    excerpt(tokens, firstIndex...(firstIndex + 1)))
            } else if first == "don't" && firstIndex + 1 < tokens.count && tokens[firstIndex + 1] != "you" {
                add("Impératif négatif",
                    "Don't + verbe à la base, sans sujet : interdiction ou mise en garde (« Ne bouge pas ! »).",
                    excerpt(tokens, firstIndex...(firstIndex + 1)))
            } else if imperativeVerbs.contains(first) && !isFollowedBySubject(tokens, firstIndex) {
                add("Impératif",
                    "Verbe à la base sans sujet pour donner un ordre ou un conseil : « Look out! », « Run! ».",
                    excerpt(tokens, firstIndex...(firstIndex + 1)))
            }

            if tokens.contains("if") {
                let withWould = tokens.contains { $0 == "would" || $0 == "wouldn't" || $0.hasSuffix("'d") }
                add("Condition avec if",
                    withWould
                    ? "Hypothèse : if + prétérit, puis would + verbe (« Si j'étais toi, je ne ferais pas ça »). Au conditionnel, on dit souvent « if I were »."
                    : "Proposition de condition : if + présent, puis présent ou will (« If you move, I'll shoot »).",
                    "if")
            }
            if tokens.contains("than") {
                add("Comparatif",
                    "Adjectif court + -er + than (faster than), ou more + adjectif long + than (more dangerous than).",
                    "than")
            }
        }
        return points
    }

    static let subjectPronouns: Set<String> = ["i", "you", "we", "they", "he", "she", "it"]

    /// « Look, I… » n'est pas un impératif au sens grammatical : le verbe est suivi d'un sujet.
    private static func isFollowedBySubject(_ tokens: [String], _ index: Int) -> Bool {
        index + 1 < tokens.count && subjectPronouns.contains(tokens[index + 1])
    }

    static func splitSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if ch == "?" || ch == "!" || ch == "." || ch == "\u{2026}" {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.contains(where: { $0.isLetter }) {
                    sentences.append(trimmed)
                    current = ""
                }
            }
        }
        let rest = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if rest.contains(where: { $0.isLetter }) { sentences.append(rest) }
        return sentences
    }

    // MARK: - Verbes à particule

    static let phrasalVerbs: [(verb: String, particle: String, meaning: String)] = [
        ("get", "out", "sortir, dégager"), ("get", "away", "s'échapper"), ("get", "back", "revenir, reculer"),
        ("get", "up", "se lever"), ("get", "in", "entrer, monter"), ("give", "up", "abandonner"),
        ("give", "in", "céder"), ("look", "out", "attention !"), ("look", "for", "chercher"),
        ("look", "after", "s'occuper de"), ("come", "on", "allez ! / viens !"), ("come", "back", "revenir"),
        ("come", "in", "entrer"), ("go", "on", "continuer"), ("go", "back", "retourner"),
        ("hold", "on", "attendre, tenir bon"), ("watch", "out", "faire attention"), ("back", "off", "reculer, lâcher l'affaire"),
        ("shut", "up", "se taire"), ("take", "off", "décoller, enlever"), ("take", "down", "abattre, neutraliser"),
        ("take", "over", "prendre le contrôle"), ("find", "out", "découvrir"), ("figure", "out", "comprendre, trouver"),
        ("pick", "up", "ramasser, passer prendre"), ("show", "up", "se pointer, arriver"), ("run", "away", "s'enfuir"),
        ("blow", "up", "exploser, faire sauter"), ("calm", "down", "se calmer"), ("hang", "on", "attendre"),
        ("knock", "out", "assommer"), ("turn", "around", "se retourner"), ("wake", "up", "se réveiller"),
        ("stand", "back", "reculer"), ("step", "back", "reculer"), ("break", "in", "entrer par effraction"),
        ("break", "out", "s'évader, éclater"), ("let", "go", "lâcher"), ("fall", "apart", "s'effondrer"),
        ("set", "up", "installer, piéger"), ("put", "on", "mettre (un vêtement)"), ("put", "down", "poser"),
        ("sit", "down", "s'asseoir"), ("stand", "up", "se lever"), ("check", "out", "regarder, vérifier"),
        ("mess", "up", "tout gâcher"), ("screw", "up", "tout rater"), ("beat", "up", "tabasser"),
        ("run", "into", "tomber sur"), ("catch", "up", "rattraper"), ("keep", "up", "suivre le rythme"),
        ("move", "on", "passer à autre chose"), ("head", "out", "partir"), ("cut", "off", "couper, interrompre"),
        ("give", "back", "rendre"), ("bring", "back", "ramener"), ("go", "away", "partir, s'en aller"),
        ("get", "off", "descendre, lâcher"), ("take", "care", "prendre soin")
    ]

    static func matchesVerb(_ token: String, base: String) -> Bool {
        if token == base || token == base + "s" || token == base + "es" || token == base + "ing"
            || token == base + "ed" || token == base + "d" { return true }
        if base.hasSuffix("e"), token == String(base.dropLast()) + "ing" { return true }
        if let last = base.last, token == base + String(last) + "ing" || token == base + String(last) + "ed" { return true }
        if let forms = irregularVerbs[base], forms.past.contains(token) || forms.participle.contains(token) { return true }
        return false
    }

    private static func phrasalVerbsPoint(_ tokens: [String]) -> GrammarPoint? {
        var found: [String] = []
        for i in 0..<max(0, tokens.count - 1) {
            for entry in phrasalVerbs where tokens[i + 1] == entry.particle && matchesVerb(tokens[i], base: entry.verb) {
                let line = "\(entry.verb) \(entry.particle) → \(entry.meaning)"
                if !found.contains(line) { found.append(line) }
            }
        }
        guard !found.isEmpty else { return nil }
        return GrammarPoint(
            title: "Verbes à particule (phrasal verbs)",
            explanation: "Verbe + particule dont le sens est souvent différent du verbe seul : " + found.joined(separator: " ; ") + ".",
            examples: [])
    }

    // MARK: - Expressions

    static let expressions: [(String, String)] = [
        ("no way", "pas question ! / c'est pas vrai !"), ("what the hell", "qu'est-ce que… ? (juron)"),
        ("big deal", "la belle affaire !"), ("my bad", "ma faute, désolé"), ("for real", "sérieusement ?"),
        ("never mind", "laisse tomber"), ("what's up", "quoi de neuf ? / qu'est-ce qui se passe ?"),
        ("you bet", "et comment !"), ("take it easy", "du calme / vas-y doucement"),
        ("give me a break", "lâche-moi / tu plaisantes ?"), ("out of the way", "pousse-toi !"),
        ("so what", "et alors ?"), ("no kidding", "sans blague"), ("of course", "bien sûr"),
        ("i mean", "je veux dire"), ("you know", "tu sais (tic de langage)"), ("hang in there", "tiens bon"),
        ("piece of cake", "du gâteau, facile"), ("on my way", "j'arrive / en route"), ("at last", "enfin"),
        ("right now", "tout de suite"), ("let's go", "allons-y"), ("look who's", "tiens, voilà…"),
        ("what are you doing", "qu'est-ce que tu fais ?"), ("thank god", "Dieu merci"),
        ("oh my god", "oh mon Dieu"), ("come on", "allez ! / voyons !"), ("watch out", "attention !"),
        ("look out", "attention !"), ("hold it", "stop ! ne bouge pas !"), ("get a load of", "regarde-moi ça"),
        ("in the nick of time", "juste à temps"), ("it's over", "c'est fini"), ("bring it on", "vas-y, je t'attends")
    ]

    private static func expressionsPoint(_ tokens: [String]) -> GrammarPoint? {
        let joined = " " + tokens.joined(separator: " ") + " "
        var found: [String] = []
        for (expression, meaning) in expressions {
            let normalized = expression.split(separator: " ").map { normalizeToken(String($0)) }.joined(separator: " ")
            if joined.contains(" " + normalized + " ") { found.append("« \(expression) » → \(meaning)") }
        }
        guard !found.isEmpty else { return nil }
        return GrammarPoint(
            title: "Expressions courantes",
            explanation: found.joined(separator: " ; ") + ".",
            examples: [])
    }

    // MARK: - Fusion

    /// Fusionne les points de même titre (et réunit leurs exemples).
    private static func merged(_ points: [GrammarPoint]) -> [GrammarPoint] {
        var order: [String] = []
        var byTitle: [String: GrammarPoint] = [:]
        for p in points {
            if let existing = byTitle[p.title] {
                var examples = existing.examples
                for e in p.examples where !examples.contains(e) { examples.append(e) }
                byTitle[p.title] = GrammarPoint(title: p.title, explanation: existing.explanation, examples: examples)
            } else {
                order.append(p.title)
                byTitle[p.title] = p
            }
        }
        return order.compactMap { byTitle[$0] }
    }
}
