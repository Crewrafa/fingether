import SwiftUI

// MARK: - Tutorial Module Detail

struct TutorialModuleView: View {

    @Bindable var viewModel: TutorialViewModel
    let module: TutorialModule

    @Environment(\.dismiss) private var dismiss
    @State private var preferences = AppPreferences.shared
    private var lang: AppLanguage { preferences.language }

    private var isCompleted: Bool { viewModel.isCompleted(module) }
    private var accent: Color { viewModel.iconColor(for: module) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroIconSection
                if isCompleted {
                    completedBadge
                }
                titleAndDescription
                tipCard
                ctaButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(L10n.t("tutorial_module_nav", lang))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero Icon

    private var heroIconSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 110, height: 110)
                Image(systemName: module.icon)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(accent)
            }
            .shadow(color: accent.opacity(0.25), radius: 14, y: 6)

            Text(String(format: L10n.t("tutorial_step_label", lang), module.id, viewModel.totalCount))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(Capsule())
        }
        .padding(.top, 6)
    }

    // MARK: - Completed Badge

    private var completedBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.white)
            Text(L10n.t("tutorial_completed_badge", lang))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.fingetherForest, Color.fingetherPrimary],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
        .shadow(color: Color.fingetherForest.opacity(0.25), radius: 8, y: 4)
    }

    // MARK: - Title & Description

    private var titleAndDescription: some View {
        VStack(spacing: 14) {
            Text(L10n.t(module.titleKey, lang))
                .font(.title2.bold())
                .foregroundStyle(Color(.label))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.t(module.descriptionKey, lang))
                .font(.body)
                .foregroundStyle(Color(.label))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Tip Card

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.title3)
                .foregroundStyle(Color.fingetherWarning)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("tutorial_tip_label", lang))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.fingetherWarning)

                Text(L10n.t(module.tipKey, lang))
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.fingetherWarning.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.fingetherWarning.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button {
            viewModel.handleCTA(for: module)
            // Pop one level back to the tutorial list so the user can keep going.
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                Text(L10n.t(module.ctaKey, lang))
                    .font(.headline)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.fingetherPrimary, Color.fingetherPrimaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.fingetherPrimary.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(flexibility: .solid), trigger: module.id)
    }
}
