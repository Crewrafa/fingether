import SwiftUI
import LocalAuthentication

struct LockScreenView: View {

    let onUnlock: () -> Void

    @State private var isAuthenticating = false
    @State private var authFailed = false
    @State private var logoScale: CGFloat = 0.8

    private let teal = Color.fingetherPrimary

    var body: some View {
        ZStack {
            // Blur background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                ZStack {
                    Circle()
                        .fill(teal.opacity(0.1))
                        .frame(width: 120, height: 120)

                    VStack(spacing: -2) {
                        Text("💕")
                            .font(.system(size: 32))
                        Text("$")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(teal)
                    }
                }
                .scaleEffect(logoScale)

                VStack(spacing: 8) {
                    Text("Fingether")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(.label))

                    Text("Toca para desbloquear")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if authFailed {
                    Text("Autenticacion fallida. Intenta de nuevo.")
                        .font(.caption)
                        .foregroundStyle(Color.fingetherDanger)
                        .padding(.horizontal, 24)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Unlock button
                Button {
                    authenticate()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                            .font(.title2)
                        Text("Desbloquear")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(teal, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                .disabled(isAuthenticating)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                logoScale = 1.0
            }
            authenticate()
        }
    }

    private func authenticate() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Biometrics not available — unlock directly
            onUnlock()
            return
        }

        isAuthenticating = true
        authFailed = false

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Desbloquea Fingether para ver tus finanzas"
        ) { success, _ in
            DispatchQueue.main.async {
                isAuthenticating = false
                if success {
                    onUnlock()
                } else {
                    authFailed = true
                }
            }
        }
    }
}
