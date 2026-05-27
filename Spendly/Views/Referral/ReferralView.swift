import SwiftUI
import Foundation

// MARK: - Referral View

/// Referral program screen where users can share their code
/// and invite other couples to the app.
struct ReferralView: View {

    @State private var preferences = AppPreferences.shared
    @State private var showCopiedToast = false

    private var referralCode: String {
        if preferences.referralCode.isEmpty {
            let generated = generateCode()
            preferences.referralCode = generated
            return generated
        }
        return preferences.referralCode
    }

    private var fullCode: String {
        "REF-\(referralCode)"
    }

    private var shareText: String {
        "Mi pareja y yo usamos Fingether para manejar nuestro dinero juntos. Pruebalo! Usa mi codigo \(fullCode) y ambos recibimos 1 mes gratis. https://fingether.app/ref/\(referralCode)"
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                headerSection
                codeCard
                shareSection
                invitedCountCard
                howItWorksCard
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Referidos")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if showCopiedToast {
                copiedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showCopiedToast)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("\u{1F381}")
                .font(.system(size: 60))

            Text("Invita a otra pareja")
                .font(.title2.bold())

            Text("Comparte tu codigo y cuando otra pareja se registre, ambos reciben 1 mes gratis de Fingether Premium.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.top, 8)
    }

    // MARK: - Code Card

    private var codeCard: some View {
        VStack(spacing: 16) {
            Text("Tu codigo de referido")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(fullCode)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.fingetherPrimary)
                .kerning(3)

            Button {
                copyCode()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                    Text("Copiar codigo")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.fingetherPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.fingetherPrimary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }

    // MARK: - Share Section

    private var shareSection: some View {
        ShareLink(item: shareText) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                Text("Compartir invitacion")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.fingetherPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .simultaneousGesture(TapGesture().onEnded {
            AnalyticsService.track(.referralShared)
        })
    }

    // MARK: - Invited Count

    private var invitedCountCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.title2)
                .foregroundStyle(Color.fingetherPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Parejas invitadas")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("0")
                    .font(.title3.bold())
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }

    // MARK: - How It Works

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Como funciona")
                .font(.headline)

            howItWorksStep(
                number: 1,
                icon: "paperplane.fill",
                text: "Comparte tu codigo con otra pareja"
            )
            howItWorksStep(
                number: 2,
                icon: "person.badge.plus",
                text: "Ellos se registran usando tu codigo"
            )
            howItWorksStep(
                number: 3,
                icon: "gift.fill",
                text: "Ambas parejas reciben 1 mes gratis de Premium"
            )
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }

    private func howItWorksStep(number: Int, icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.fingetherPrimary.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(Color.fingetherPrimary)
            }

            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Copied Toast

    private var copiedToast: some View {
        Text("Codigo copiado!")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.fingetherForest)
            .clipShape(Capsule())
            .padding(.top, 8)
    }

    // MARK: - Actions

    private func copyCode() {
        #if canImport(UIKit)
        UIPasteboard.general.string = fullCode
        #endif
        showCopiedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedToast = false
        }
    }

    private func generateCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReferralView()
    }
}
