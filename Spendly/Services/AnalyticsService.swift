import Foundation

// MARK: - Analytics Event Catalog

enum AnalyticsEvent: String, Codable, Sendable {
    // Onboarding
    case onboardingStarted
    case onboardingCompleted
    case coupleLinked
    case firstTransaction
    // Paywall
    case paywallViewed
    case paywallDismissed
    case trialStarted
    case trialExpired
    case purchaseStarted
    case purchaseCompleted
    case purchaseRestored
    // Core features
    case transactionAdded
    case transactionReacted
    case fixedExpensePaid
    case budgetCreated
    case savingsGoalCreated
    case challengeAccepted
    case tripCreated
    case insightGenerated
    case voiceInputUsed
    case scoreViewed
    case calendarViewed
    // Social
    case moneyDateViewed
    case moneyDateShared
    case referralShared
    case partnerInviteSent
    // Tutorial
    case tutorialModuleCompleted
    // Settings
    case languageChanged
    case themeChanged
    case notificationPermissionGranted
    case notificationPermissionDenied
    // Session
    case appOpened
    case sessionStarted
}

// MARK: - Analytics Entry

struct AnalyticsEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let event: String
    let properties: [String: String]
    let timestamp: Date

    init(event: String, properties: [String: String] = [:], timestamp: Date = Date()) {
        self.id = UUID()
        self.event = event
        self.properties = properties
        self.timestamp = timestamp
    }
}

// MARK: - Analytics Service

/// Lightweight event tracking. Stores events locally in MockDataService.
/// Future: replace the body of track() with Mixpanel/Amplitude/Supabase call.
enum AnalyticsService {

    static func track(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
        let entry = AnalyticsEntry(
            event: event.rawValue,
            properties: properties,
            timestamp: Date()
        )
        MockDataService.shared.trackEvent(entry)
    }
}
