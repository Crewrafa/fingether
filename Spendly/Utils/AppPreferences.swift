import SwiftUI

@Observable
final class AppPreferences {
    static let shared = AppPreferences()

    // MARK: - Theme

    var theme: AppTheme {
        didSet { save() }
    }

    // MARK: - Currency

    var currency: AppCurrency {
        didSet { save() }
    }

    // MARK: - Language

    var language: AppLanguage {
        didSet { save() }
    }

    // MARK: - Enums

    enum AppTheme: String, CaseIterable, Codable {
        case system = "system"
        case light = "light"
        case dark = "dark"

        var displayName: String {
            switch self {
            case .system: return "Automatico"
            case .light: return "Claro"
            case .dark: return "Oscuro"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    enum AppCurrency: String, CaseIterable, Codable {
        case mxn = "MXN"
        case usd = "USD"
        case eur = "EUR"
        case cop = "COP"
        case ars = "ARS"
        case clp = "CLP"
        case pen = "PEN"
        case brl = "BRL"

        var displayName: String {
            switch self {
            case .mxn: return "Peso Mexicano (MXN)"
            case .usd: return "Dólar (USD)"
            case .eur: return "Euro (EUR)"
            case .cop: return "Peso Colombiano (COP)"
            case .ars: return "Peso Argentino (ARS)"
            case .clp: return "Peso Chileno (CLP)"
            case .pen: return "Sol Peruano (PEN)"
            case .brl: return "Real Brasileño (BRL)"
            }
        }

        var symbol: String {
            switch self {
            case .mxn, .usd, .cop, .ars, .clp: return "$"
            case .eur: return "\u{20AC}"
            case .pen: return "S/"
            case .brl: return "R$"
            }
        }

        var locale: Locale {
            switch self {
            case .mxn: return Locale(identifier: "es_MX")
            case .usd: return Locale(identifier: "en_US")
            case .eur: return Locale(identifier: "es_ES")
            case .cop: return Locale(identifier: "es_CO")
            case .ars: return Locale(identifier: "es_AR")
            case .clp: return Locale(identifier: "es_CL")
            case .pen: return Locale(identifier: "es_PE")
            case .brl: return Locale(identifier: "pt_BR")
            }
        }
    }

    // MARK: - Mode (couple vs individual)

    var isCoupleMode: Bool = true {
        didSet { save() }
    }

    // MARK: - Tutorial State

    /// Steps 8–11 (Simulador, Score, Calendario, Voz) son informativos —
    /// se marcan como completados cuando el usuario abre su seccion desde el tutorial.
    /// Steps 1–7 se derivan de los datos de MockDataService, no se persisten aqui.
    var tutorialInfoStepsViewed: Set<Int> = [] {
        didSet { save() }
    }

    /// Marca un paso informativo como visto (idempotente).
    func markTutorialInfoStepViewed(_ step: Int) {
        if !tutorialInfoStepsViewed.contains(step) {
            tutorialInfoStepsViewed.insert(step)
        }
    }

    // MARK: - Trial (C1)

    /// Date when the 14-day trial started. Set ONCE after first onboarding completion.
    var trialStartDate: Date? {
        didSet { save() }
    }

    /// Whether the user has seen the value preview screens post-onboarding (C2).
    var hasSeenValuePreview: Bool = false {
        didSet { save() }
    }

    /// Notification toggles (C4)
    var notificationsMorning: Bool = true { didSet { save() } }
    var notificationsPartnerSpend: Bool = true { didSet { save() } }
    var notificationsEvening: Bool = true { didSet { save() } }

    /// Referral code (C6)
    var referralCode: String = "" { didSet { save() } }

    /// Days remaining in the free trial.
    var trialDaysRemaining: Int {
        guard let start = trialStartDate else { return 14 }
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
        return max(0, 14 - elapsed)
    }

    /// True while the 14-day trial hasn't expired.
    var isTrialActive: Bool {
        trialDaysRemaining > 0
    }

    /// True if user has full access: trial active, premium subscriber, OR dev mode.
    var hasFullAccess: Bool {
        // Dev mode ALWAYS has access (never blocked by paywall)
        if MockDataService.shared.isEnabled { return true }
        if MockDataService.shared.mockProfile?.subscriptionTier == .premium { return true }
        return isTrialActive
    }

    /// Resetea TODAS las preferencias al estado de usuario nuevo.
    func resetAll() {
        hasSeenValuePreview = false
        trialStartDate = nil
        isCoupleMode = false
        tutorialInfoStepsViewed = []
        notificationsMorning = true
        notificationsPartnerSpend = true
        notificationsEvening = true
        referralCode = ""
        save()
        UserDefaults.standard.synchronize()
    }

    /// Starts the trial (called once after onboarding completes).
    func startTrialIfNeeded() {
        if trialStartDate == nil {
            trialStartDate = Date()
            AnalyticsService.track(.trialStarted)
        }
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard
        self.theme = AppTheme(rawValue: defaults.string(forKey: "app_theme") ?? "") ?? .system
        self.currency = AppCurrency(rawValue: defaults.string(forKey: "app_currency") ?? "") ?? .cop
        self.language = .es
        self.isCoupleMode = defaults.object(forKey: "app_couple_mode") as? Bool ?? true

        if let array = defaults.array(forKey: "tutorial_info_steps_viewed") as? [Int] {
            self.tutorialInfoStepsViewed = Set(array)
        }
        if let ts = defaults.object(forKey: "fingether_trial_start") as? Date {
            self.trialStartDate = ts
        }
        self.hasSeenValuePreview = defaults.bool(forKey: "fingether_value_preview_seen")
        self.notificationsMorning = defaults.object(forKey: "fingether_notif_morning") as? Bool ?? true
        self.notificationsPartnerSpend = defaults.object(forKey: "fingether_notif_partner") as? Bool ?? true
        self.notificationsEvening = defaults.object(forKey: "fingether_notif_evening") as? Bool ?? true
        self.referralCode = defaults.string(forKey: "fingether_referral_code") ?? ""
    }

    // MARK: - Persistence

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(theme.rawValue, forKey: "app_theme")
        defaults.set(currency.rawValue, forKey: "app_currency")
        defaults.set(language.rawValue, forKey: "app_language")
        defaults.set(isCoupleMode, forKey: "app_couple_mode")
        defaults.set(Array(tutorialInfoStepsViewed), forKey: "tutorial_info_steps_viewed")
        defaults.set(trialStartDate, forKey: "fingether_trial_start")
        defaults.set(hasSeenValuePreview, forKey: "fingether_value_preview_seen")
        defaults.set(notificationsMorning, forKey: "fingether_notif_morning")
        defaults.set(notificationsPartnerSpend, forKey: "fingether_notif_partner")
        defaults.set(notificationsEvening, forKey: "fingether_notif_evening")
        defaults.set(referralCode, forKey: "fingether_referral_code")
    }
}

// MARK: - Tutorial Navigation Notification

extension Notification.Name {
    /// Posted by the tutorial when the user taps "Go to [section]".
    /// userInfo["tab"]: String — must match a Tab raw value of MainTabView.Tab
    /// (transactions, fixedExpenses, dashboard, savings, settings).
    static let fingetherTutorialNavigateToTab = Notification.Name("FingetherTutorialNavigateToTab")
}
