import SwiftUI

@main
struct FingetherApp: App {

    @State private var authViewModel = AuthViewModel()
    @State private var preferences = AppPreferences.shared
    @Environment(\.scenePhase) private var scenePhase

    @State private var isLocked = false
    @State private var backgroundTimestamp: Date?

    /// Session timeout in seconds (5 minutes)
    private let sessionTimeoutSeconds: TimeInterval = 300

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView(authViewModel: authViewModel)
                    .tint(Color.fingetherPrimary)
                    .preferredColorScheme(preferences.theme.colorScheme)

                if isLocked && authViewModel.isAuthenticated {
                    LockScreenView {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isLocked = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isLocked)
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            backgroundTimestamp = Date()
        case .active:
            guard authViewModel.isAuthenticated else { return }
            if let timestamp = backgroundTimestamp {
                let elapsed = Date().timeIntervalSince(timestamp)
                if elapsed >= sessionTimeoutSeconds {
                    isLocked = true
                }
            }
            backgroundTimestamp = nil
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}

// MARK: - Root View

struct RootView: View {

    @Bindable var authViewModel: AuthViewModel

    @State private var preferences = AppPreferences.shared

    var body: some View {
        Group {
            if authViewModel.isLoading && authViewModel.currentUser == nil {
                LaunchLoadingView()
            } else if !authViewModel.isAuthenticated {
                LoginView(authViewModel: authViewModel)
                    .transition(.opacity)
            } else if let user = authViewModel.currentUser, !user.onboardingCompleted {
                OnboardingView(authViewModel: authViewModel)
                    .transition(.move(edge: .trailing))
            } else if authViewModel.currentUser != nil, !preferences.hasFullAccess {
                // C1: Hard paywall — trial expired and not premium.
                // Dev mode is exempt (hasFullAccess always true).
                HardPaywallView(isBlocking: true)
                    .transition(.opacity)
            } else if authViewModel.currentUser != nil, !preferences.hasSeenValuePreview, !MockDataService.shared.isEnabled {
                // C2: Value preview shown once after first onboarding (not in dev mode).
                ValuePreviewView {
                    preferences.hasSeenValuePreview = true
                    preferences.startTrialIfNeeded()
                }
                .transition(.move(edge: .trailing))
            } else if let user = authViewModel.currentUser {
                MainTabView(
                    userId: user.id,
                    coupleId: user.coupleId,
                    authViewModel: authViewModel
                )
                .transition(.opacity)
            } else {
                LoginView(authViewModel: authViewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: authViewModel.isAuthenticated)
        .animation(.easeInOut(duration: 0.35), value: authViewModel.currentUser?.onboardingCompleted)
        .task {
            await authViewModel.checkSession()
        }
    }
}

// MARK: - Launch Loading View

private struct LaunchLoadingView: View {

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.fingetherPrimary)
                    .scaleEffect(isPulsing ? 1.1 : 0.95)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: isPulsing
                    )

                Text("Fingether")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(.label))

                ProgressView()
                    .tint(Color.fingetherPrimary)
            }
        }
        .onAppear { isPulsing = true }
    }
}
