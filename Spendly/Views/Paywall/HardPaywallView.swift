import SwiftUI

// MARK: - Hard Paywall (C1 + C8)

/// Full-screen paywall that blocks the app when the trial expires.
/// Also used as the final screen of the value preview flow (C2).
/// Dev mode NEVER sees this — hasFullAccess is always true in dev.
struct HardPaywallView: View {

    /// True when shown after trial expiry (no X button). False when shown as the
    /// final value-preview screen (has a "Comenzar" CTA instead of block).
    var isBlocking: Bool = true

    /// Called when the user taps "Comenzar" in non-blocking mode (value preview).
    var onStart: () -> Void = {}

    @State private var selectedPlan: Plan = .yearly
    @State private var isPulsing = false
    @Environment(\.colorScheme) private var cs

    enum Plan { case monthly, yearly }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                headerSection
                socialProof
                benefitsList
                planSelector
                trialTimeline
                ctaButton
                footerLinks
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                colors: [
                    cs == .dark ? Color(hex: "0A1A14") : Color(hex: "F0FFF8"),
                    cs == .dark ? Color(hex: "1A1A2E") : Color(hex: "FFFFFF")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            isPulsing = true
            AnalyticsService.track(.paywallViewed, properties: ["blocking": String(isBlocking)])
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Animated Fingether icon
            ZStack {
                Circle()
                    .fill(Color.fingetherPrimary.opacity(0.12))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isPulsing ? 1.08 : 0.95)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)

                ZStack {
                    Text("$")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(Color.fingetherPrimary)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.fingetherRose)
                        .offset(x: 22, y: -22)
                }
            }

            Text("Tomen el control de su dinero juntos")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color(.label))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Social proof

    private var socialProof: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.fingetherAmber)
                }
            }
            Text("4.9")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(.label))
            Text("—")
                .foregroundStyle(.tertiary)
            Text("Parejas que confían en Fingether")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Benefits

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefit("División justa de gastos automática")
            benefit("Insights con IA para decisiones de pareja")
            benefit("Metas de ahorro compartidas")
            benefit("Presupuesto inteligente que se adapta")
            benefit("Input por voz en 5 idiomas")
            benefit("Simuladores financieros")
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func benefit(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.fingetherPrimary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color(.label))
        }
    }

    // MARK: - Plan selector

    private var planSelector: some View {
        HStack(spacing: 12) {
            planCard(
                plan: .monthly,
                label: "Mensual",
                price: "$9.99",
                period: "/mes",
                badge: nil
            )
            planCard(
                plan: .yearly,
                label: "Anual",
                price: "$6.67",
                period: "/mes",
                badge: "Ahorra 33%"
            )
        }
    }

    private func planCard(plan: Plan, label: String, price: String, period: String, badge: String?) -> some View {
        let isSel = selectedPlan == plan
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedPlan = plan }
        } label: {
            VStack(spacing: 6) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.fingetherDanger)
                        .clipShape(Capsule())
                }
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.label))
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.title2.bold())
                    Text(period)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if plan == .yearly {
                    Text("Facturado como $79.99/año")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSel ? Color.fingetherPrimary.opacity(0.10) : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSel ? Color.fingetherPrimary : Color(.systemGray4), lineWidth: isSel ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Trial timeline

    private var trialTimeline: some View {
        VStack(spacing: 14) {
            HStack {
                timelinePoint(label: "Hoy", detail: "Acceso completo gratis", isActive: true)
                Spacer()
                timelinePoint(label: "Día 12", detail: "Te recordamos", isActive: false)
                Spacer()
                timelinePoint(label: "Día 14", detail: "Se activa tu plan", isActive: false)
            }

            Text("Cancela cuando quieras antes del día 14 y no se te cobra nada")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func timelinePoint(label: String, detail: String, isActive: Bool) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isActive ? Color.fingetherPrimary : Color(.systemGray4))
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isActive ? Color.fingetherPrimary : .secondary)
            Text(detail)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: 80)
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            AnalyticsService.track(.purchaseStarted, properties: ["plan": selectedPlan == .yearly ? "yearly" : "monthly"])
            if !isBlocking {
                onStart()
            }
            // In blocking mode, this would initiate StoreKit purchase.
            // For now mock: mark as premium.
            MockDataService.shared.markMockProfilePremium(true)
        } label: {
            VStack(spacing: 4) {
                Text(isBlocking ? "Suscribirse ahora" : "Comenzar 14 días gratis")
                    .font(.headline)
                Text(selectedPlan == .yearly ? "Luego $79.99/año" : "Luego $9.99/mes")
                    .font(.caption)
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.fingetherPrimary, Color.fingetherPrimaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.fingetherPrimary.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footerLinks: some View {
        VStack(spacing: 10) {
            Button("Restaurar compra") {
                AnalyticsService.track(.purchaseRestored)
            }
            .font(.subheadline)
            .foregroundStyle(Color.fingetherPrimary)

            HStack(spacing: 16) {
                Button("Términos") {}
                    .font(.caption).foregroundStyle(.tertiary)
                Button("Privacidad") {}
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}
