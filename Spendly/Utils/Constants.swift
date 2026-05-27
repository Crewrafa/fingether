import Foundation
import SwiftUI

// MARK: - Constants

enum Constants {

    // MARK: - Supabase Configuration

    static let supabaseURL: String = {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !url.isEmpty else {
            fatalError("SUPABASE_URL no encontrada en Info.plist / xcconfig")
        }
        return url
    }()

    static let supabaseAnonKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty else {
            fatalError("SUPABASE_ANON_KEY no encontrada en Info.plist / xcconfig")
        }
        return key
    }()

    // MARK: - Category Colors

    static let categoryColors: [TransactionCategory: Color] = [
        .food: .orange,
        .transport: .blue,
        .housing: .brown,
        .utilities: .yellow,
        .entertainment: .purple,
        .health: Color.fingetherDanger,
        .education: .indigo,
        .shopping: .pink,
        .travel: .cyan,
        .gifts: .mint,
        .savings: .green,
        .debt: Color.fingetherDanger,
        .investments: .teal,
        .salary: .gray,
        .freelance: .orange,
        .other: .secondary
    ]

    // MARK: - Pet Evolution XP Thresholds

    enum PetEvolutionThreshold {
        static let egg = 0
        static let baby = 500
        static let teen = 2_000
        static let adult = 5_000
        static let legendary = 10_000
    }

    // MARK: - Pet Health Ranges

    enum PetHealthRange {
        static let critical = 0...25
        static let warning = 26...50
        static let good = 51...75
        static let excellent = 76...100
    }

    // MARK: - Budget Alert Thresholds

    enum BudgetAlertThreshold {
        /// Porcentaje para mostrar advertencia amarilla
        static let warning: Decimal = 0.80
        /// Porcentaje para mostrar alerta roja
        static let danger: Decimal = 0.95
        /// Presupuesto excedido
        static let exceeded: Decimal = 1.0
    }

    // MARK: - Streak Milestones

    enum StreakMilestone {
        static let week = 7
        static let twoWeeks = 14
        static let month = 30
        static let quarter = 90
    }

    // MARK: - StoreKit Product Identifiers

    enum StoreKit {
        static let premiumMonthly = "com.fingether.premium.monthly"
        static let premiumYearly = "com.fingether.premium.yearly"
        static let allProductIds: Set<String> = [premiumMonthly, premiumYearly]
    }

    // MARK: - Free Tier Limits

    enum FreeTierLimits {
        /// Transacciones por mes en plan gratuito
        static let monthlyTransactions = 50
        /// Presupuestos activos en plan gratuito
        static let activeBudgets = 3
        /// Metas de ahorro activas en plan gratuito
        static let activeSavingsGoals = 2
        /// Insights de IA por mes en plan gratuito
        static let monthlyInsights = 5
    }

    // MARK: - Date Formatting

    enum DateFormat {
        static let apiDate = "yyyy-MM-dd"
        static let apiDateTime = "yyyy-MM-dd'T'HH:mm:ssZ"
        static let displayDate = "d 'de' MMMM, yyyy"
        static let displayShortDate = "d MMM"
        static let displayMonth = "MMMM yyyy"
    }

    // MARK: - Currency

    enum Currency {
        static let defaultCode = "COP"
        static let defaultLocale = Locale(identifier: "es_CO")
    }

    // MARK: - Animation

    enum Animation {
        static let petIdleAnimation = "pet_idle"
        static let petHappyAnimation = "pet_happy"
        static let petSadAnimation = "pet_sad"
        static let petEatAnimation = "pet_eat"
        static let petLevelUpAnimation = "pet_levelup"
    }

    // MARK: - Keychain Keys

    enum KeychainKey {
        static let accessToken = "fingether_access_token"
        static let refreshToken = "fingether_refresh_token"
    }

    // MARK: - Edge Functions

    enum EdgeFunction {
        static let generateInsights = "generate-insights"
    }
}
