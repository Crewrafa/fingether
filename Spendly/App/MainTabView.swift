import SwiftUI

struct MainTabView: View {
    let userId: UUID
    let coupleId: UUID?
    @Bindable var authViewModel: AuthViewModel

    @State private var selectedTab: Tab = .dashboard
    @State private var preferences = AppPreferences.shared

    enum Tab: String, CaseIterable {
        case transactions, fixedExpenses, dashboard, savings, settings

        var iconName: String {
            switch self {
            case .dashboard: return "heart.circle.fill"
            case .transactions: return "creditcard.fill"
            case .fixedExpenses: return "pin.circle.fill"
            case .savings: return "target"
            case .settings: return "ellipsis.circle.fill"
            }
        }

        func title(coupleMode: Bool, lang: AppLanguage) -> String {
            switch self {
            case .dashboard: return coupleMode ? L10n.t("tab_dashboard_couple", lang) : L10n.t("tab_dashboard_solo", lang)
            case .transactions: return L10n.t("tab_transactions", lang)
            case .fixedExpenses: return L10n.t("tab_fixed", lang)
            case .savings: return L10n.t("tab_savings", lang)
            case .settings: return L10n.t("tab_settings", lang)
            }
        }

        func icon(coupleMode: Bool) -> String {
            if self == .dashboard {
                return coupleMode ? "heart.circle.fill" : "person.circle.fill"
            }
            return iconName
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(
                            tab.title(coupleMode: preferences.isCoupleMode, lang: preferences.language),
                            systemImage: tab.icon(coupleMode: preferences.isCoupleMode)
                        )
                    }
                    .tag(tab)
            }
        }
        .tint(Color.fingetherPrimary)
        .onReceive(NotificationCenter.default.publisher(for: .fingetherTutorialNavigateToTab)) { note in
            // Tutorial requested a tab switch.
            guard
                let raw = note.userInfo?["tab"] as? String,
                let target = Tab(rawValue: raw)
            else { return }
            withAnimation {
                selectedTab = target
            }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .dashboard:
            DashboardView(userId: userId, coupleId: coupleId)
        case .transactions:
            TransactionListView(userId: userId, coupleId: coupleId)
        case .fixedExpenses:
            FixedExpensesView(userId: userId, coupleId: coupleId)
        case .savings:
            if let cid = coupleId {
                SavingsGoalListView(coupleId: cid)
            } else {
                EmptyStateView(icon: "target", title: "Sin pareja", subtitle: "Vincula tu pareja para crear metas juntos")
            }
        case .settings:
            MasView(userId: userId, coupleId: coupleId, authViewModel: authViewModel)
        }
    }
}
