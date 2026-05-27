import Foundation
import SwiftUI

// MARK: - Date Extensions

extension Date {

    /// Primer día del mes de esta fecha
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }

    /// Último día del mes de esta fecha
    var endOfMonth: Date {
        let calendar = Calendar.current
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return self
        }
        return calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? self
    }

    /// Formato largo en español: "5 de abril, 2026"
    var formattedSpanishLong: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = Constants.DateFormat.displayDate
        return formatter.string(from: self)
    }

    /// Formato corto en español: "5 abr"
    var formattedSpanishShort: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = Constants.DateFormat.displayShortDate
        return formatter.string(from: self)
    }

    /// Formato de mes: "abril 2026"
    var formattedMonth: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = Constants.DateFormat.displayMonth
        return formatter.string(from: self)
    }

    /// Tiempo relativo en español: "hace 2 horas", "ayer", etc.
    var relativeTimeSpanish: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Formato para enviar a la API: "2026-04-05"
    var apiFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = Constants.DateFormat.apiDate
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: self)
    }
}

// MARK: - Double Extensions

extension Double {

    /// Formato de moneda usando la preferencia del usuario
    var currencyFormatted: String {
        let prefs = AppPreferences.shared
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = prefs.currency.rawValue
        formatter.locale = prefs.currency.locale
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "\(prefs.currency.symbol)\(self)"
    }

    /// Formato compacto: "$1.2K", "$3.5M"
    var currencyCompact: String {
        let prefs = AppPreferences.shared
        let absValue = abs(self)
        let sign = self < 0 ? "-" : ""

        if absValue >= 1_000_000 {
            return "\(sign)\(prefs.currency.symbol)\(String(format: "%.1f", absValue / 1_000_000))M"
        } else if absValue >= 1_000 {
            return "\(sign)\(prefs.currency.symbol)\(String(format: "%.1f", absValue / 1_000))K"
        } else {
            return currencyFormatted
        }
    }
}

// MARK: - Decimal Extensions

extension Decimal {

    /// Formato de moneda usando la preferencia del usuario
    var currencyFormatted: String {
        let prefs = AppPreferences.shared
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = prefs.currency.rawValue
        formatter.locale = prefs.currency.locale
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: self as NSDecimalNumber) ?? "\(prefs.currency.symbol)\(self)"
    }

    /// Formato de porcentaje: "85.5%"
    var percentFormatted: String {
        let doubleValue = NSDecimalNumber(decimal: self * 100).doubleValue
        return String(format: "%.1f%%", doubleValue)
    }

    /// Convierte a Double
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}

// MARK: - Color Extensions

extension Color {

    /// Crea un Color desde un string hexadecimal, e.g. "#FF5733" o "FF5733"
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    // MARK: - Fingether Official Palette (v1.6 — Electric Indigo Primary)
    //
    // Design principles:
    // - Primary is electric indigo — modern, confident, tech, premium
    // - Teal is SECONDARY (income, positive, informational)
    // - Rose (#F4A5AE) is ONLY for couple-mode accents
    // - Danger is deep pink. NO red anywhere.
    // - Expenses neutral (slate). Income emerald green.

    // ── Primary (electric indigo) ──
    static let fingetherPrimary     = Color(hex: "4F46E5")  // Main action color, brand
    static let fingetherPrimaryDark = Color(hex: "4338CA")  // Pressed states, gradient endpoint
    static let fingetherPrimaryLight = fingetherPrimary.opacity(0.10)  // Card highlights, hover

    // ── Secondary ──
    static let fingetherTeal      = Color(hex: "00C9A7")  // Income, positive, informational
    static let fingetherTealDark  = Color(hex: "00A88A")  // Teal pressed/dark variant
    static let fingetherSky       = Color(hex: "0EA5E9")  // Individual mode, clarity
    static let fingetherRose      = Color(hex: "F4A5AE")  // Couple mode cards

    // ── Funcionales ──
    static let fingetherExpense   = Color(hex: "64748B")  // Expenses = neutral fact
    static let fingetherIncome    = Color(hex: "10B981")  // Income = emerald growth
    static let fingetherForest    = Color(hex: "2D6A4F")  // Excellent / completed

    // ── Feedback ──
    static let fingetherAmber     = Color(hex: "F59E0B")  // Achievements, celebration
    static let fingetherWarning   = Color(hex: "FB923C")  // Attention without panic
    static let fingetherDanger    = Color(hex: "DB2777")  // Critical alerts (deep pink)

    // ── Neutros ──
    static let fingetherSlate      = Color(hex: "475569")
    static let fingetherSlateLight = Color(hex: "94A3B8")
    static let fingetherBg         = Color(hex: "F8FAFC")
    static let fingetherDarkBg     = Color(hex: "1A1A2E")
    static let fingetherDarkCard   = Color(hex: "1E1E2E")

    // ── Legacy aliases ──
    static let fingetherCoral  = fingetherExpense
    static let fingetherPurple = fingetherSky
    static let fingetherGold   = fingetherAmber
    static let fingetherHoney  = fingetherWarning
    static let fingetherCream  = fingetherBg

    // ── Gradients ──
    static let primaryGradient = LinearGradient(
        colors: [fingetherPrimary, fingetherPrimaryDark],
        startPoint: .leading, endPoint: .trailing
    )
    static let tealGradient = LinearGradient(
        colors: [Color(hex: "00C9A7"), Color(hex: "00A88A")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let coupleGradient = LinearGradient(
        colors: [fingetherRose, fingetherPrimary],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let incomeGradient = LinearGradient(
        colors: [Color(hex: "10B981"), Color(hex: "2D6A4F")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let coralGradient  = primaryGradient
    static let purpleGradient = LinearGradient(
        colors: [Color(hex: "0EA5E9"), Color(hex: "0284C7")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let goldGradient = LinearGradient(
        colors: [Color(hex: "F59E0B"), Color(hex: "D97706")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - View Extensions

extension View {

    /// Forces SwiftUI to re-render the view when the user changes currency in preferences.
    /// Apply to any view that displays `.currencyFormatted` amounts.
    func trackCurrency() -> some View {
        modifier(CurrencyTracker())
    }
}

/// A ViewModifier that reads `AppPreferences.shared.currency`, causing SwiftUI
/// to observe it and invalidate the view whenever the currency setting changes.
private struct CurrencyTracker: ViewModifier {
    @State private var preferences = AppPreferences.shared
    func body(content: Content) -> some View {
        content
            .id(preferences.currency.rawValue)
    }
}

extension View {

    /// Aplica un modificador condicionalmente
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Aplica un modificador condicionalmente con else
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        then trueTransform: (Self) -> TrueContent,
        else falseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            trueTransform(self)
        } else {
            falseTransform(self)
        }
    }

    /// Oculta la vista condicionalmente
    @ViewBuilder
    func hidden(_ shouldHide: Bool) -> some View {
        if shouldHide {
            self.hidden()
        } else {
            self
        }
    }
}

// MARK: - String Extensions

extension String {

    /// Capitaliza la primera letra
    var capitalizedFirst: String {
        guard let first = first else { return self }
        return String(first).uppercased() + dropFirst()
    }

    /// Valida formato de email
    var isValidEmail: Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        return predicate.evaluate(with: self)
    }
}

// MARK: - Global Formatting

/// Formatea un string numérico con separadores de miles (punto)
/// "4600000" → "4.600.000", "500000" → "500.000"
func formatWithThousands(_ input: String) -> String {
    let digits = String(input.filter(\.isNumber).prefix(15))
    guard !digits.isEmpty else { return "" }
    guard let number = Int(digits) else { return digits }
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = "."
    formatter.usesGroupingSeparator = true
    return formatter.string(from: NSNumber(value: number)) ?? digits
}

/// Extrae solo dígitos de un string formateado con miles y lo convierte a Decimal
func parseAmountFromFormatted(_ text: String) -> Decimal {
    let digits = text.filter(\.isNumber)
    return Decimal(string: digits) ?? Decimal.zero
}

// MARK: - Input Sanitization

extension String {
    /// Limita la longitud del string y recorta whitespace
    func sanitized(maxLength: Int) -> String {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(maxLength))
    }

    /// Sanitiza nombre de persona: max 50, trim whitespace
    var sanitizedName: String { sanitized(maxLength: 50) }

    /// Sanitiza texto general: max 200, trim whitespace
    var sanitizedText: String { sanitized(maxLength: 200) }

    /// Sanitiza monto: solo dígitos, max 15
    var sanitizedAmount: String {
        let digits = self.filter(\.isNumber)
        return String(digits.prefix(15))
    }
}

// MARK: - SwiftUI Input Limit Modifier

extension View {
    /// Limita longitud de un Binding<String> y aplica sanitización
    func limitInput(_ binding: Binding<String>, maxLength: Int) -> some View {
        self.onChange(of: binding.wrappedValue) { _, newValue in
            if newValue.count > maxLength {
                binding.wrappedValue = String(newValue.prefix(maxLength))
            }
        }
    }
}
