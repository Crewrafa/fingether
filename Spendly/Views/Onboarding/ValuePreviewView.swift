import SwiftUI

// MARK: - Value Preview (C2)

/// 5 screens shown ONCE after onboarding, before the user enters the app.
/// The last screen is the paywall CTA with "Comenzar 14 días gratis".
/// NOT shown in dev mode (controlled by RootView).
struct ValuePreviewView: View {

    /// Called after the user taps "Comenzar" on the last screen.
    var onComplete: () -> Void

    @State private var currentPage = 0
    @Environment(\.colorScheme) private var cs

    private let pages = ValuePage.all

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    cs == .dark ? Color(hex: "0A1A14") : Color(hex: "F0FFF8"),
                    cs == .dark ? Color(hex: "1A1A2E") : Color(hex: "FFFFFF")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { idx, page in
                        pageContent(page)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Dots + button
                VStack(spacing: 20) {
                    // Page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { idx in
                            Circle()
                                .fill(idx == currentPage ? Color.fingetherPrimary : Color(.systemGray4))
                                .frame(width: 8, height: 8)
                                .scaleEffect(idx == currentPage ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }

                    // CTA
                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation { currentPage += 1 }
                        } else {
                            onComplete()
                        }
                    } label: {
                        Text(currentPage == pages.count - 1 ? "Comenzar prueba gratuita" : "Siguiente")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.fingetherPrimary, in: RoundedRectangle(cornerRadius: 14))
                            .shadow(color: Color.fingetherPrimary.opacity(0.3), radius: 10, y: 5)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Page content

    private func pageContent(_ page: ValuePage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Illustration card with mock data
            VStack(spacing: 16) {
                Text(page.emoji)
                    .font(.system(size: 56))

                // Example card
                page.exampleCard
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
                    .padding(.horizontal, 20)
            }

            // Headline + subtext
            VStack(spacing: 10) {
                Text(page.headline)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(.label))
                    .multilineTextAlignment(.center)

                Text(page.subtext)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Value Pages

private struct ValuePage {
    let emoji: String
    let headline: String
    let subtext: String
    let exampleCard: AnyView

    static var all: [ValuePage] {
        [
            ValuePage(
                emoji: "📊",
                headline: "Todo tu dinero, en un solo lugar",
                subtext: "Ve ingresos, gastos y balance de los dos al instante",
                exampleCard: AnyView(dashboardExample)
            ),
            ValuePage(
                emoji: "⚖️",
                headline: "Cada quien paga lo justo",
                subtext: "Dividan gastos sin discutir — 50/50, proporcional, o como quieran",
                exampleCard: AnyView(splitExample)
            ),
            ValuePage(
                emoji: "🎯",
                headline: "Metas compartidas, progreso real",
                subtext: "Ahorren juntos para lo que importa y vean su avance día a día",
                exampleCard: AnyView(savingsExample)
            ),
            ValuePage(
                emoji: "🤖",
                headline: "Insights inteligentes para decisiones de pareja",
                subtext: "Tu asesor financiero con IA analiza y sugiere mejoras cada semana",
                exampleCard: AnyView(insightExample)
            ),
            ValuePage(
                emoji: "✨",
                headline: "14 días gratis para probarlo todo",
                subtext: "Acceso completo sin restricciones. Cancela cuando quieras.",
                exampleCard: AnyView(trialExample)
            ),
        ]
    }

    // MARK: - Example cards

    private static var dashboardExample: some View {
        VStack(spacing: 12) {
            HStack {
                Text("💕 Rafael & Mariana").font(.subheadline.weight(.bold))
                Spacer()
                Text("Abril 2026").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 0) {
                VStack { Text("Ingresos").font(.caption2).foregroundStyle(.secondary); Text("$8.200.000").font(.subheadline.bold()).foregroundStyle(Color.fingetherPrimary) }
                    .frame(maxWidth: .infinity)
                VStack { Text("Gastos").font(.caption2).foregroundStyle(.secondary); Text("$5.100.000").font(.subheadline.bold()).foregroundStyle(Color.fingetherExpense) }
                    .frame(maxWidth: .infinity)
                VStack { Text("Balance").font(.caption2).foregroundStyle(.secondary); Text("+$3.100.000").font(.subheadline.bold()).foregroundStyle(Color.fingetherPrimary) }
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private static var splitExample: some View {
        VStack(spacing: 10) {
            HStack { Text("🏠 Arriendo").font(.subheadline.weight(.semibold)); Spacer(); Text("$1.600.000").font(.subheadline.bold()) }
            HStack(spacing: 4) {
                VStack { Text("Tú: 61%").font(.caption.weight(.bold)).foregroundStyle(Color.fingetherPrimary); Text("$968.000").font(.caption) }
                    .frame(maxWidth: .infinity).padding(8).background(Color.fingetherPrimary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 8))
                VStack { Text("Pareja: 39%").font(.caption.weight(.bold)).foregroundStyle(Color.fingetherRose); Text("$632.000").font(.caption) }
                    .frame(maxWidth: .infinity).padding(8).background(Color.fingetherRose.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private static var savingsExample: some View {
        VStack(spacing: 10) {
            HStack { Text("✈️ Viaje a Cartagena").font(.subheadline.weight(.semibold)); Spacer(); Text("65%").font(.subheadline.bold()).foregroundStyle(Color.fingetherPrimary) }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Color(.systemGray5)).frame(height: 10)
                    RoundedRectangle(cornerRadius: 6).fill(Color.fingetherPrimary).frame(width: geo.size.width * 0.65, height: 10)
                }
            }.frame(height: 10)
            HStack { Text("$1.950.000 de $3.000.000").font(.caption).foregroundStyle(.secondary); Spacer(); Text("Faltan 2 meses").font(.caption).foregroundStyle(Color.fingetherPrimary) }
        }
    }

    private static var insightExample: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) { Image(systemName: "sparkles").foregroundStyle(Color.fingetherPrimary); Text("Fingether AI").font(.caption.weight(.bold)).foregroundStyle(Color.fingetherPrimary) }
            Text("Este mes gastaron 40% menos en delivery que el anterior 🎉 Si mantienen ese ritmo, ahorrarían $180.000 extra para su meta de viaje.")
                .font(.subheadline)
                .foregroundStyle(Color(.label))
        }
    }

    private static var trialExample: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "gift.fill").font(.title2).foregroundStyle(Color.fingetherPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Prueba gratuita").font(.subheadline.weight(.bold))
                    Text("14 días con acceso completo").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 16) {
                Label("Sin tarjeta", systemImage: "creditcard.trianglebadge.exclamationmark").font(.caption2).foregroundStyle(.secondary)
                Label("Cancela gratis", systemImage: "xmark.circle").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
