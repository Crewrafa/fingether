import Foundation

struct ParsedExpense {
    var amount: Decimal?
    var merchant: String?
    var category: TransactionCategory?
}

enum VoiceExpenseParser {

    // MARK: - Main Parse

    static func parse(text: String, language: AppLanguage) -> ParsedExpense {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lower.isEmpty else { return ParsedExpense() }

        var result = ParsedExpense()
        result.amount = extractAmount(from: lower, language: language)
        result.category = detectCategory(from: lower, language: language)
        result.merchant = extractMerchant(from: lower, language: language, amount: result.amount)
        return result
    }

    // MARK: - Amount Extraction

    private static func extractAmount(from text: String, language: AppLanguage) -> Decimal? {
        // Try pattern: number + multiplier word ("30 mil", "30 thousand")
        if let amount = extractWithMultiplier(text, language: language) {
            return amount
        }

        // Try direct numbers: "30000", "30.000", "30,000"
        if let amount = extractDirectNumber(text) {
            return amount
        }

        return nil
    }

    private static func extractWithMultiplier(_ text: String, language: AppLanguage) -> Decimal? {
        let multipliers = multipliersFor(language)

        for (word, multiplier) in multipliers {
            // Pattern: "{number} {multiplier}" optionally followed by "{number}" (e.g. "30 mil quinientos")
            let pattern = "(\\d+[.,]?\\d*)\\s*\(word)"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(text.startIndex..., in: text)

            if let match = regex.firstMatch(in: text, range: range),
               let numRange = Range(match.range(at: 1), in: text) {
                let numStr = String(text[numRange]).replacingOccurrences(of: ",", with: ".")
                guard let base = Double(numStr) else { continue }
                var total = Decimal(base * Double(multiplier))

                // Check for remainder after multiplier: "30 mil quinientos" → +500
                let afterMultiplier = text.suffix(from: text.index(text.startIndex, offsetBy: match.range.upperBound, limitedBy: text.endIndex) ?? text.endIndex)
                if let remainder = extractSmallNumber(String(afterMultiplier), language: language) {
                    total += remainder
                }

                return total
            }
        }

        // Check word numbers: "treinta mil", "twenty thousand"
        if let wordAmount = extractWordNumber(text, language: language) {
            return wordAmount
        }

        return nil
    }

    private static func extractDirectNumber(_ text: String) -> Decimal? {
        // Find sequences of digits potentially with . or , separators
        let pattern = "\\$?\\s*(\\d{1,3}(?:[.,]\\d{3})*|\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)

        if let match = regex.firstMatch(in: text, range: range),
           let numRange = Range(match.range(at: 1), in: text) {
            let numStr = String(text[numRange])
            // If it has dots as thousands separator (common in LATAM): 30.000 → 30000
            let cleaned = numStr.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
            if let val = Decimal(string: cleaned), val > 0 {
                return val
            }
        }
        return nil
    }

    private static func extractSmallNumber(_ text: String, language: AppLanguage) -> Decimal? {
        let smallWords: [String: Decimal]
        switch language {
        case .es:
            smallWords = ["quinientos": 500, "quinientas": 500, "doscientos": 200, "trescientos": 300, "cuatrocientos": 400, "seiscientos": 600, "setecientos": 700, "ochocientos": 800, "novecientos": 900, "cien": 100, "ciento": 100]
        case .en:
            smallWords = ["hundred": 100, "five hundred": 500, "two hundred": 200]
        default:
            smallWords = [:]
        }

        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for (word, value) in smallWords {
            if lower.contains(word) { return value }
        }

        // Direct small number
        let pattern = "(\\d+)"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let range = Range(match.range(at: 1), in: lower),
           let val = Decimal(string: String(lower[range])), val > 0, val < 1000 {
            return val
        }

        return nil
    }

    private static func extractWordNumber(_ text: String, language: AppLanguage) -> Decimal? {
        // Basic word-to-number for common amounts
        let patterns: [(String, Decimal)]
        switch language {
        case .es:
            patterns = [
                ("un millon", 1_000_000), ("dos millones", 2_000_000),
                ("medio millon", 500_000), ("cien mil", 100_000),
                ("cincuenta mil", 50_000), ("veinte mil", 20_000),
                ("diez mil", 10_000), ("cinco mil", 5_000),
            ]
        case .en:
            patterns = [
                ("a million", 1_000_000), ("one million", 1_000_000),
                ("half a million", 500_000), ("hundred thousand", 100_000),
                ("fifty thousand", 50_000), ("twenty thousand", 20_000),
                ("ten thousand", 10_000), ("five thousand", 5_000),
                ("a grand", 1_000), ("a thousand", 1_000),
            ]
        default:
            patterns = []
        }

        for (word, value) in patterns {
            if text.contains(word) { return value }
        }
        return nil
    }

    // MARK: - Multiplier Words

    private static func multipliersFor(_ language: AppLanguage) -> [(String, Int)] {
        switch language {
        case .es: return [("millones", 1_000_000), ("millon", 1_000_000), ("mil", 1_000)]
        case .en: return [("million", 1_000_000), ("thousand", 1_000), ("grand", 1_000), ("k", 1_000)]
        case .de: return [("million", 1_000_000), ("millionen", 1_000_000), ("tausend", 1_000)]
        case .fr: return [("million", 1_000_000), ("millions", 1_000_000), ("mille", 1_000)]
        case .pt: return [("milhao", 1_000_000), ("milhoes", 1_000_000), ("mil", 1_000)]
        }
    }

    // MARK: - Category Detection

    private static func detectCategory(from text: String, language: AppLanguage) -> TransactionCategory? {
        let rules: [(keywords: [String], category: TransactionCategory)] = [
            // Food (check before transport — "supermercado" contains "bus")
            (["supermercado", "mercado", "almuerzo", "cena", "desayuno", "restaurante", "comida",
              "grocery", "supermarket", "lunch", "dinner", "breakfast", "restaurant", "food",
              "lebensmittel", "supermarkt", "déjeuner", "dîner"], .food),
            // Transport
            (["uber", "didi", "taxi", "cabify", "rappi", "autobus", "metro", "gasolina", "parking",
              "cab", "lyft", "fuel", "petrol", "benzin", "essence", "transporte", "transport"], .transport),
            // Entertainment
            (["netflix", "spotify", "cine", "movie", "cinema", "juego", "game", "streaming",
              "disney", "hbo", "youtube", "amazon prime", "kino", "film"], .entertainment),
            // Health
            (["farmacia", "medico", "doctor", "hospital", "salud", "pharmacy", "medicine",
              "apotheke", "arzt", "pharmacie", "médecin", "dentista", "dentist"], .health),
            // Housing
            (["arriendo", "renta", "alquiler", "rent", "miete", "loyer", "aluguel"], .housing),
            // Utilities
            (["luz", "agua", "gas natural", "internet", "telefono", "celular",
              "electricity", "water", "phone", "strom", "wasser"], .utilities),
            // Shopping
            (["ropa", "zapatos", "tienda", "shopping", "clothes", "shoes", "store",
              "kleidung", "schuhe", "laden", "vêtements", "magasin", "roupa", "loja"], .shopping),
            // Education
            (["curso", "clase", "universidad", "colegio", "libro", "course", "class",
              "university", "book", "kurs", "buch", "livre", "universidade"], .education),
        ]

        for rule in rules {
            for keyword in rule.keywords {
                if text.contains(keyword) {
                    return rule.category
                }
            }
        }

        return nil
    }

    // MARK: - Merchant Extraction

    private static func extractMerchant(from text: String, language: AppLanguage, amount: Decimal?) -> String? {
        var cleaned = text

        // Remove amount-related words
        let amountWords: [String]
        switch language {
        case .es: amountWords = ["gaste", "gasté", "pague", "pagué", "mil", "millon", "millones", "pesos", "dolares", "euros", "en", "de", "por", "fueron"]
        case .en: amountWords = ["spent", "paid", "thousand", "million", "dollars", "euros", "pounds", "at", "for", "in", "on"]
        case .de: amountWords = ["ausgegeben", "bezahlt", "tausend", "million", "euro", "für", "bei", "in"]
        case .fr: amountWords = ["dépensé", "payé", "mille", "million", "euros", "pour", "chez", "dans"]
        case .pt: amountWords = ["gastei", "paguei", "mil", "milhao", "milhoes", "reais", "dolares", "euros", "em", "de", "por", "no", "na"]
        }

        // Remove numbers
        cleaned = cleaned.replacingOccurrences(of: "\\$?\\d+[.,]?\\d*", with: "", options: .regularExpression)

        // Remove amount words
        for word in amountWords {
            cleaned = cleaned.replacingOccurrences(of: "\\b\(word)\\b", with: "", options: [.regularExpression, .caseInsensitive])
        }

        // Clean up
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:-"))

        guard !cleaned.isEmpty, cleaned.count >= 2 else { return nil }

        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }
}
