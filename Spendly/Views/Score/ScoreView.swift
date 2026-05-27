import SwiftUI
import UIKit

struct ScoreView: View {

    let coupleId: UUID
    var userId: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()

    @State private var viewModel = ScoreViewModel()
    @State private var animatedProgress: Double = 0
    @State private var preferences = AppPreferences.shared
    @State private var paywallFeature: PremiumFeature?  // P6
    private var lang: AppLanguage { preferences.language }
    private var isCoupleMode: Bool { preferences.isCoupleMode }
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

    private let tealColor = Color.fingetherPrimary
    private let roseColor = Color.fingetherRose

    private var isPremium: Bool {
        MockDataService.shared.mockProfile?.subscriptionTier == .premium
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                scoreRingSection
                if isCoupleMode {
                    coupleContributionCard
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                // P6: free tier sees ONLY the score number + tips.
                // Breakdown, history chart, charts view = Premium.
                if isPremium {
                    shareCardButton
                    breakdownSection
                    historySection
                    ScoreChartsView(coupleId: coupleId, userId: userId)
                } else {
                    premiumLockedScoreCard
                }
                tipsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .paywallGate($paywallFeature)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .trackCurrency()
        .navigationTitle(L10n.t("score_nav_title", lang))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadScore(coupleId: coupleId)
            withAnimation(.easeOut(duration: 1.2)) {
                animatedProgress = viewModel.scoreProgress
            }
        }
        .refreshable {
            await viewModel.refreshScore(coupleId: coupleId)
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = viewModel.scoreProgress
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
    }

    // MARK: - Score Ring

    private var scoreRingSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 16)
                    .frame(width: 180, height: 180)

                // Animated colored ring
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        AngularGradient(
                            colors: [scoreColor.opacity(0.6), scoreColor],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * animatedProgress)
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))

                // Score number
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(viewModel.scoreValue)")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundStyle(scoreColor)
                            .contentTransition(.numericText())

                        Text(viewModel.trend.arrow)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(viewModel.trend.color)
                    }

                    Text(viewModel.currentScore?.scoreLabel ?? L10n.t("score_loading", lang))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)

            // Trend indicator
            if let score = viewModel.currentScore {
                HStack(spacing: 6) {
                    Image(systemName: score.trend.iconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(score.trend.color)
                    Text(trendDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(score.trend.color.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Share Button

    private var shareCardButton: some View {
        Button {
            generateAndShare()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                Text(L10n.t("score_share", lang))
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color.fingetherPrimary, Color.fingetherPrimaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .sensoryFeedback(.impact(flexibility: .solid), trigger: showShareSheet)
    }

    @MainActor
    private func generateAndShare() {
        guard let score = viewModel.currentScore else { return }
        let mockData = MockDataService.shared
        let coupleName = "\(mockData.mockProfile.displayName) & \(mockData.mockPartnerProfile?.displayName ?? "Pareja")"

        let card = ShareableScoreCard(
            score: score.score,
            scoreLabel: score.scoreLabel,
            scoreColor: score.scoreColor,
            coupleName: coupleName,
            breakdown: score.breakdown,
            mascotMood: mascotMoodForScore(score.score)
        )

        let renderer = ImageRenderer(content: card.frame(width: 390))
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            shareImage = uiImage
            showShareSheet = true
        }
    }

    private func mascotMoodForScore(_ score: Int) -> String {
        switch score {
        case 85...100: return "🤩"
        case 75..<85: return "😄"
        case 60..<75: return "🙂"
        case 40..<60: return "😐"
        case 20..<40: return "😟"
        default: return "😰"
        }
    }

    // MARK: - Breakdown

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.t("score_breakdown", lang))
                    .font(.headline)
                Spacer()
                NavigationLink {
                    ScoreDetailView(coupleId: coupleId)
                } label: {
                    Text(L10n.t("score_see_detail", lang))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(tealColor)
                }
            }

            if let breakdown = viewModel.breakdown {
                VStack(spacing: 12) {
                    breakdownBar(label: L10n.t("score_budgets", lang), value: breakdown.budgetAdherence, emoji: "📊")
                    breakdownBar(label: L10n.t("score_savings_rate", lang), value: breakdown.savingsRate, emoji: "💰")
                    breakdownBar(label: L10n.t("score_debt_mgmt", lang), value: breakdown.debtManagement, emoji: "💳")
                    breakdownBar(label: L10n.t("score_consistency", lang), value: breakdown.transactionConsistency, emoji: "📝")
                    breakdownBar(label: L10n.t("score_goal_progress", lang), value: breakdown.goalProgress, emoji: "🎯")
                    breakdownBar(label: L10n.t("score_diversity", lang), value: breakdown.spendingDiversity, emoji: "🔀")
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func breakdownBar(label: String, value: Int, emoji: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(emoji) \(label)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(value)/100")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(colorForScore(value))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorForScore(value))
                        .frame(width: geo.size.width * CGFloat(value) / 100, height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - History (Line Chart)

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.t("score_history", lang))
                    .font(.headline)
                Spacer()
                Text(L10n.t("score_last_30_days", lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.scoreHistory.count < 2 {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("📊")
                            .font(.largeTitle)
                        Text(L10n.t("score_not_enough_history", lang))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
                let data = viewModel.scoreHistory.suffix(30)
                let scores = data.map { $0.score }
                let maxScore = scores.max() ?? 100
                let minScore = scores.min() ?? 0
                let avgScore = scores.reduce(0, +) / max(scores.count, 1)
                let maxIdx = scores.firstIndex(of: maxScore) ?? 0
                let minIdx = scores.firstIndex(of: minScore) ?? 0

                // Chart area
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let count = scores.count

                    ZStack {
                        // Zone backgrounds
                        let zones: [(range: ClosedRange<Int>, color: Color)] = [
                            (0...39, Color.fingetherDanger.opacity(0.06)),
                            (40...59, Color.fingetherWarning.opacity(0.06)),
                            (60...74, Color.fingetherAmber.opacity(0.06)),
                            (75...100, Color.fingetherPrimary.opacity(0.06))
                        ]
                        ForEach(0..<zones.count, id: \.self) { i in
                            let zone = zones[i]
                            let yTop = h - (h * CGFloat(zone.range.upperBound) / 100)
                            let yBottom = h - (h * CGFloat(zone.range.lowerBound) / 100)
                            Rectangle()
                                .fill(zone.color)
                                .frame(height: yBottom - yTop)
                                .offset(y: yTop)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }

                        // Y-axis labels
                        ForEach([0, 25, 50, 75, 100], id: \.self) { val in
                            let y = h - (h * CGFloat(val) / 100)
                            HStack(spacing: 0) {
                                Text("\(val)")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 20, alignment: .trailing)
                                Rectangle()
                                    .fill(Color(.systemGray4).opacity(0.5))
                                    .frame(height: 0.5)
                            }
                            .offset(y: y - h / 2)
                        }

                        // Average line (dashed)
                        let avgY = h - (h * CGFloat(avgScore) / 100)
                        Path { path in
                            path.move(to: CGPoint(x: 24, y: avgY))
                            path.addLine(to: CGPoint(x: w, y: avgY))
                        }
                        .stroke(Color(.systemGray3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                        // Average label
                        Text("\(L10n.t("score_avg", lang)): \(avgScore)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                            .offset(x: w / 2 - 20, y: avgY - h / 2 - 8)

                        // Line path with zone coloring
                        Canvas { context, size in
                            let points = scores.enumerated().map { idx, score in
                                CGPoint(
                                    x: 24 + CGFloat(idx) * ((w - 24) / CGFloat(max(count - 1, 1))),
                                    y: h - (h * CGFloat(score) / 100)
                                )
                            }

                            // Draw line segments colored by score zone
                            for i in 0..<(points.count - 1) {
                                var segmentPath = Path()
                                segmentPath.move(to: points[i])
                                segmentPath.addLine(to: points[i + 1])

                                let midScore = (scores[i] + scores[i + 1]) / 2
                                let segColor = segmentZoneColor(midScore)
                                context.stroke(segmentPath, with: .color(segColor), lineWidth: 2.5)
                            }

                            // Draw dots for max and min
                            let maxPoint = points[maxIdx]
                            let minPoint = points[minIdx]

                            // Max dot
                            let maxCircle = Path(ellipseIn: CGRect(x: maxPoint.x - 5, y: maxPoint.y - 5, width: 10, height: 10))
                            context.fill(maxCircle, with: .color(Color.fingetherPrimary))
                            context.stroke(maxCircle, with: .color(.white), lineWidth: 2)

                            // Min dot
                            let minCircle = Path(ellipseIn: CGRect(x: minPoint.x - 5, y: minPoint.y - 5, width: 10, height: 10))
                            context.fill(minCircle, with: .color(Color.fingetherDanger))
                            context.stroke(minCircle, with: .color(.white), lineWidth: 2)
                        }

                        // Max/min labels
                        let maxPt = CGPoint(
                            x: 24 + CGFloat(maxIdx) * ((w - 24) / CGFloat(max(scores.count - 1, 1))),
                            y: h - (h * CGFloat(maxScore) / 100)
                        )
                        let minPt = CGPoint(
                            x: 24 + CGFloat(minIdx) * ((w - 24) / CGFloat(max(scores.count - 1, 1))),
                            y: h - (h * CGFloat(minScore) / 100)
                        )

                        Text("▲ \(maxScore)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.fingetherPrimary)
                            .offset(x: maxPt.x - w / 2, y: maxPt.y - h / 2 - 12)

                        Text("▼ \(minScore)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.fingetherDanger)
                            .offset(x: minPt.x - w / 2, y: minPt.y - h / 2 + 12)
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // X-axis date labels
                let dateData = Array(data)
                HStack {
                    if let first = dateData.first {
                        Text(first.calculatedAt.formattedSpanishShort)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text(L10n.t("score_today", lang))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)

                // Legend
                HStack(spacing: 16) {
                    legendDot(color: Color.fingetherPrimary, label: "75-100")
                    legendDot(color: Color.fingetherAmber, label: "60-74")
                    legendDot(color: Color.fingetherWarning, label: "40-59")
                    legendDot(color: Color.fingetherDanger, label: "0-39")
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    private func segmentZoneColor(_ score: Int) -> Color {
        switch score {
        case 75...100: return Color.fingetherPrimary
        case 60..<75: return Color.fingetherAmber
        case 40..<60: return Color.fingetherWarning
        default: return Color.fingetherDanger
        }
    }

    // MARK: - Tips

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("score_tips_title", lang))
                .font(.headline)

            if viewModel.tips.isEmpty {
                Text(L10n.t("score_tips_empty", lang))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(viewModel.tips.enumerated()), id: \.offset) { _, tip in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundStyle(Color.fingetherWarning)
                            .padding(.top, 2)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundStyle(Color(.label))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.fingetherWarning.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Helpers

    private var scoreColor: Color {
        viewModel.currentScore?.scoreColor ?? Color(.systemGray3)
    }

    private func colorForScore(_ score: Int) -> Color {
        switch score {
        case 75...100: return Color.fingetherPrimary
        case 60..<75: return Color.fingetherAmber
        case 40..<60: return Color.fingetherWarning
        default: return Color.fingetherDanger
        }
    }

    private var trendDescription: String {
        switch viewModel.trend {
        case .up: return L10n.t("score_trend_up", lang)
        case .stable: return L10n.t("score_trend_stable", lang)
        case .down: return L10n.t("score_trend_down", lang)
        }
    }

    // MARK: - Premium Locked Card for Score (P6)

    private var premiumLockedScoreCard: some View {
        Button {
            paywallFeature = .scoreBreakdown
        } label: {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(tealColor)
                    Text("Desglose, gráficas e historial")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(.label))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text("Desbloquea con Premium para ver cómo se construye tu Score y la tendencia mes a mes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(tealColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(tealColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Couple Contribution Card (only when isCoupleMode == true)

    private var coupleContributionCard: some View {
        let mock = MockDataService.shared
        let n1 = mock.currentUser1Name
        let n2 = mock.currentUser2Name
        let contrib = viewModel.coupleContribution

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("💕")
                    .font(.title3)
                Text("\(n1) & \(n2)")
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                Spacer()
                Text("Contribución individual")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(roseColor.opacity(0.18))
                    .foregroundStyle(Color(.label))
                    .clipShape(Capsule())
            }

            // Overall split bar
            overallContribBar(name1: n1, name2: n2, pct1: contrib.overallUser1, pct2: contrib.overallUser2)

            // Per-dimension dual bars
            VStack(spacing: 12) {
                contribDimensionRow(
                    emoji: "📝",
                    label: "Constancia",
                    pct1: contrib.consistencyUser1,
                    pct2: contrib.consistencyUser2,
                    n1: n1, n2: n2
                )
                contribDimensionRow(
                    emoji: "💰",
                    label: "Aporte a metas",
                    pct1: contrib.savingsUser1,
                    pct2: contrib.savingsUser2,
                    n1: n1, n2: n2
                )
                contribDimensionRow(
                    emoji: "🛟",
                    label: "Salud de gasto",
                    pct1: contrib.spendingUser1,
                    pct2: contrib.spendingUser2,
                    n1: n1, n2: n2
                )
                contribDimensionRow(
                    emoji: "🔢",
                    label: "Registros",
                    pct1: contrib.transactionsUser1,
                    pct2: contrib.transactionsUser2,
                    n1: n1, n2: n2
                )
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(roseColor.opacity(0.45), lineWidth: 1.5)
        )
        .shadow(color: roseColor.opacity(0.18), radius: 10, y: 4)
    }

    private func overallContribBar(name1: String, name2: String, pct1: Int, pct2: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(tealColor).frame(width: 8, height: 8)
                    Text(name1)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(.label))
                    Text("\(pct1)%")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(tealColor)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("\(pct2)%")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(roseColor)
                    Text(name2)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(.label))
                    Circle().fill(roseColor).frame(width: 8, height: 8)
                }
            }

            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(tealColor)
                        .frame(width: max(geo.size.width * CGFloat(pct1) / 100 - 1, 4))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(roseColor)
                }
            }
            .frame(height: 10)
        }
    }

    private func contribDimensionRow(emoji: String, label: String, pct1: Int, pct2: Int, n1: String, n2: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(emoji) \(label)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(pct1) / \(pct2)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(tealColor.opacity(0.85))
                        .frame(width: max(geo.size.width * CGFloat(pct1) / 100 - 1, 2))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(roseColor.opacity(0.85))
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Shareable Score Card

private struct ShareableScoreCard: View {

    let score: Int
    let scoreLabel: String
    let scoreColor: Color
    let coupleName: String
    let breakdown: ScoreBreakdown
    let mascotMood: String

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date()).capitalized
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header gradient
            VStack(spacing: 12) {
                // Logo
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                    Text("Fingether")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }

                Text(L10n.t("score_our_financial", AppPreferences.shared.language))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                LinearGradient(
                    colors: [Color.fingetherPrimary, Color.fingetherPrimaryDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Main content
            VStack(spacing: 20) {
                // Score + Mascot
                HStack(spacing: 24) {
                    // Score ring
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 10)
                            .frame(width: 120, height: 120)
                        Circle()
                            .trim(from: 0, to: Double(score) / 100.0)
                            .stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text("\(score)")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundStyle(scoreColor)
                            Text(scoreLabel)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Mascot + couple info
                    VStack(spacing: 8) {
                        Text(mascotMood)
                            .font(.system(size: 56))

                        Text(coupleName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(.label))
                            .multilineTextAlignment(.center)

                        Text(monthName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 20)

                // Mini breakdown - 6 dots
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        miniMetric(emoji: "📊", label: L10n.t("score_budgets", AppPreferences.shared.language), value: breakdown.budgetAdherence)
                        miniMetric(emoji: "💰", label: L10n.t("score_savings", AppPreferences.shared.language), value: breakdown.savingsRate)
                        miniMetric(emoji: "💳", label: L10n.t("score_debts", AppPreferences.shared.language), value: breakdown.debtManagement)
                    }
                    HStack(spacing: 12) {
                        miniMetric(emoji: "📝", label: L10n.t("score_consistency", AppPreferences.shared.language), value: breakdown.transactionConsistency)
                        miniMetric(emoji: "🎯", label: L10n.t("score_goals", AppPreferences.shared.language), value: breakdown.goalProgress)
                        miniMetric(emoji: "🔀", label: L10n.t("score_spending_diversity", AppPreferences.shared.language), value: breakdown.spendingDiversity)
                    }
                }
                .padding(.horizontal, 16)

                // Footer
                HStack {
                    Spacer()
                    Text("fingether.app")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 16)
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, 8)
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        .padding(20)
        .background(Color(.systemGroupedBackground))
    }

    private func miniMetric(emoji: String, label: String, value: Int) -> some View {
        VStack(spacing: 6) {
            Text(emoji)
                .font(.title3)

            // Colored dot indicator
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 32, height: 32)
                Text("\(value)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(metricColor(value))
            }

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func metricColor(_ value: Int) -> Color {
        switch value {
        case 75...100: return Color.fingetherPrimary
        case 60..<75: return Color.fingetherAmber
        case 40..<60: return Color.fingetherWarning
        default: return Color.fingetherDanger
        }
    }
}

// MARK: - UIKit Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
