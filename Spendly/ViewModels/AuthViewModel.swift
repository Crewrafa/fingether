import Foundation

@MainActor
@Observable
final class AuthViewModel {

    // MARK: - Form Properties

    var email = ""
    var password = ""
    var displayName = ""

    // MARK: - State

    var isLoading = false
    var errorMessage: String?
    var isAuthenticated = false
    var currentUser: Profile?

    // MARK: - Dev Mode (triple-tap / "Saltar al app")

    func enterDevMode() {
        MockDataService.shared.isEnabled = true
        let mock = MockDataService.shared
        // Siempre forzar datos frescos al entrar en dev mode
        mock.seedAllData()
        // CRITICAL: ensure onboardingCompleted = true so dev mode goes
        // DIRECTLY to MainTabView, never to onboarding.
        if mock.mockProfile?.onboardingCompleted == false {
            mock.mockProfile?.onboardingCompleted = true
            mock.saveAll()
        }
        // Ensure ValuePreview is skipped in dev mode
        AppPreferences.shared.hasSeenValuePreview = true
        currentUser = mock.getMockProfile()
        isAuthenticated = true
        AnalyticsService.track(.appOpened, properties: ["mode": "dev"])
    }

    // MARK: - New User Mode ("Iniciar sesión" → onboarding from scratch)

    func enterNewUserMode() {
        let mock = MockDataService.shared
        // 1. Destruir TODA la persistencia (fingether_*, app_*, tutorial_*)
        mock.nukeAllPersistedData()
        // 2. Crear estado en memoria completamente limpio
        mock.seedClean()
        // 3. Resetear preferencias de la app
        AppPreferences.shared.resetAll()
        // 4. Activar mock mode
        mock.isEnabled = true
        // 5. Profile con onboardingCompleted = false → RootView muestra OnboardingView
        currentUser = mock.getMockProfile()
        isAuthenticated = true
        AnalyticsService.track(.appOpened, properties: ["mode": "new_user"])
    }

    /// Called after mock onboarding completes — refresh currentUser from MockDataService
    func refreshMockUser() {
        currentUser = MockDataService.shared.getMockProfile()
    }

    // MARK: - Actions

    func signUp() async {
        guard validateSignUpFields() else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await AuthService.signUp(
                email: email,
                password: password,
                displayName: displayName
            )
            // After signup, sign in to get session
            try await AuthService.signIn(email: email, password: password)
            currentUser = try await AuthService.getCurrentProfile()
            isAuthenticated = true
            clearForm()
        } catch {
            errorMessage = mapAuthError(error)
        }
    }

    func signIn() async {
        guard validateSignInFields() else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await AuthService.signIn(
                email: email,
                password: password
            )
            currentUser = try await AuthService.getCurrentProfile()
            isAuthenticated = true
            clearForm()
        } catch {
            errorMessage = mapAuthError(error)
        }
    }

    func signOut() async {
        // Clear ALL MockDataService state on sign out
        let mock = MockDataService.shared
        mock.isEnabled = false
        mock.mockTransactions = []
        mock.mockDebts = []
        mock.mockSavingsGoals = []
        mock.mockBudgets = []
        mock.coupleSettings = .defaultSettings
        mock.mockAchievements = []
        mock.mockNotifications = []
        mock.mockInsights = []
        mock.mockTrips = []
        mock.mockTripExpenses = []
        mock.mockChallenges = []
        mock.mockSimulations = []
        mock.mockScoreHistory = []
        mock.mockPartnerProfile = nil
        mock.mockCouple = nil
        mock.mockPetState = nil
        mock.paidFixedKeys = []
        mock.mockSubscriptions = []
        // P3: limpiar TODA la persistencia local (claves fingether_*) ademas de la memoria.
        MockDataService.clearAllPersisted()

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await AuthService.signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            // In mock mode, just clear local state
            currentUser = nil
            isAuthenticated = false
        }
    }

    func checkSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if AuthService.getCurrentUser() != nil {
                currentUser = try await AuthService.getCurrentProfile()
                isAuthenticated = true
            } else {
                isAuthenticated = false
                currentUser = nil
            }
        } catch {
            isAuthenticated = false
            currentUser = nil
        }
    }

    func resetPassword() async {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Ingresa tu correo electronico para recuperar la contrasena."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await AuthService.resetPassword(email: email)
            errorMessage = nil
        } catch {
            errorMessage = "No se pudo enviar el correo de recuperacion. Verifica tu correo e intenta de nuevo."
        }
    }

    // MARK: - Private Helpers

    private func validateSignUpFields() -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedEmail.isEmpty {
            errorMessage = "El correo electronico es obligatorio."
            return false
        }
        if password.count < 6 {
            errorMessage = "La contrasena debe tener al menos 6 caracteres."
            return false
        }
        if trimmedName.isEmpty {
            errorMessage = "El nombre es obligatorio."
            return false
        }
        return true
    }

    private func validateSignInFields() -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedEmail.isEmpty {
            errorMessage = "El correo electronico es obligatorio."
            return false
        }
        if password.isEmpty {
            errorMessage = "La contrasena es obligatoria."
            return false
        }
        return true
    }

    private func clearForm() {
        email = ""
        password = ""
        displayName = ""
    }

    private func mapAuthError(_ error: Error) -> String {
        let description = error.localizedDescription.lowercased()

        if description.contains("invalid login") || description.contains("invalid credentials") {
            return "Correo o contrasena incorrectos."
        }
        if description.contains("email already") || description.contains("already registered") {
            return "Este correo ya esta registrado. Intenta iniciar sesion."
        }
        if description.contains("network") || description.contains("connection") {
            return "Sin conexion a internet. Verifica tu red e intenta de nuevo."
        }
        if description.contains("rate limit") || description.contains("too many") {
            return "Demasiados intentos. Espera unos minutos e intenta de nuevo."
        }
        return "Ocurrio un error inesperado. Intenta de nuevo."
    }
}
