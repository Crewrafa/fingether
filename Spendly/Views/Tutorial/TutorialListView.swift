import SwiftUI

// MARK: - Tutorial List View

struct TutorialListView: View {

    @State private var viewModel = TutorialViewModel()
    @State private var preferences = AppPreferences.shared
    private var lang: AppLanguage { preferences.language }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                progressCard
                modulesList
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(L10n.t("tutorial_nav_title", lang))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.refresh()
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 10) {
            Text("📖")
                .font(.system(size: 42))

            Text(L10n.t("tutorial_header_title", lang))
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(L10n.t("tutorial_header_subtitle", lang))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            LinearGradient(
                colors: [Color.fingetherPrimary, Color.fingetherPrimaryDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.fingetherPrimary.opacity(0.3), radius: 12, y: 6)
    }

    // MARK: - Progress

    private var progressCard: some View {
        let total = viewModel.totalCount
        let done = viewModel.completedCount
        let pct = viewModel.progress

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(format: L10n.t("tutorial_progress_label", lang), done, total))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.label))
                Spacer()
                Text("\(Int(pct * 100))%")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.fingetherPrimary)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color.fingetherPrimary, Color.fingetherPrimaryDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * CGFloat(pct), 4), height: 10)
                        .animation(.easeOut(duration: 0.4), value: pct)
                }
            }
            .frame(height: 10)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Modules List

    private var modulesList: some View {
        let nextId = viewModel.nextPendingModule?.id

        return VStack(spacing: 12) {
            ForEach(viewModel.visibleModules) { module in
                NavigationLink {
                    TutorialModuleView(viewModel: viewModel, module: module)
                } label: {
                    moduleCard(
                        module: module,
                        isCompleted: viewModel.isCompleted(module),
                        isNext: module.id == nextId
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func moduleCard(module: TutorialModule, isCompleted: Bool, isNext: Bool) -> some View {
        let accent = viewModel.iconColor(for: module)
        let borderColor: Color = isCompleted
            ? Color.fingetherForest
            : (isNext ? Color.fingetherPrimary : Color(.systemGray4))
        let bgColor: Color = isNext
            ? Color.fingetherPrimary.opacity(0.05)
            : Color(.secondarySystemGroupedBackground)

        return HStack(spacing: 14) {
            // Leading: number or check
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.fingetherForest.opacity(0.15) : accent.opacity(0.12))
                    .frame(width: 44, height: 44)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.fingetherForest)
                } else {
                    Text("\(module.id)")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(accent)
                }
            }

            // Middle: title + desc
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: module.icon)
                        .font(.caption)
                        .foregroundStyle(accent)
                    Text(L10n.t(module.titleKey, lang))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                    if isNext {
                        Text(L10n.t("tutorial_next_badge", lang))
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.fingetherPrimary)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }

                Text(L10n.t(module.descriptionKey, lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 4)

            // Trailing: chevron or check
            if isCompleted {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundStyle(Color.fingetherForest)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: isNext ? 2 : 1)
        )
        .opacity(isCompleted ? 0.85 : 1)
        .shadow(color: isNext ? Color.fingetherPrimary.opacity(0.15) : .clear, radius: 8, y: 4)
    }
}
