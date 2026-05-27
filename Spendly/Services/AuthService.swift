import Foundation
import Supabase

// MARK: - Auth Service

enum AuthService {

    private static var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - Sign Up

    /// Registra un nuevo usuario con email, contraseña y nombre
    static func signUp(email: String, password: String, displayName: String) async throws {
        let metadata: [String: AnyJSON] = [
            "display_name": .string(displayName)
        ]

        try await client.auth.signUp(
            email: email,
            password: password,
            data: metadata
        )
    }

    // MARK: - Sign In

    /// Inicia sesión con email y contraseña
    static func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(
            email: email,
            password: password
        )
    }

    // MARK: - Sign Out

    /// Cierra la sesión actual
    static func signOut() async throws {
        if MockDataService.shared.isEnabled {
            return
        }
        try await client.auth.signOut()
    }

    // MARK: - Get Current User

    /// Retorna el usuario actual si hay sesión activa
    static func getCurrentUser() -> User? {
        client.auth.currentUser
    }

    // MARK: - Get Current Session

    /// Retorna la sesión actual, lanza error si no hay sesión
    static func getCurrentSession() async throws -> Session {
        try await client.auth.session
    }

    // MARK: - Reset Password

    /// Envía un correo para restablecer la contraseña
    static func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }

    // MARK: - Get Profile

    /// Obtiene el perfil del usuario actual desde la base de datos
    static func getCurrentProfile() async throws -> Profile {
        if MockDataService.shared.isEnabled {
            return MockDataService.shared.getMockProfile()
        }

        guard let userId = getCurrentUser()?.id else {
            throw AuthError.noActiveSession
        }

        let profile: Profile = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        return profile
    }

    // MARK: - Update Profile

    /// Actualiza campos del perfil del usuario actual
    static func updateProfile(displayName: String? = nil, monthlyIncome: Decimal? = nil, currency: String? = nil, onboardingCompleted: Bool? = nil) async throws {
        if MockDataService.shared.isEnabled {
            MockDataService.shared.updateMockProfile(displayName: displayName, monthlyIncome: monthlyIncome, currency: currency, onboardingCompleted: onboardingCompleted)
            return
        }

        guard let userId = getCurrentUser()?.id else {
            throw AuthError.noActiveSession
        }

        var updates: [String: AnyJSON] = [:]

        if let displayName {
            updates["display_name"] = .string(displayName)
        }
        if let monthlyIncome {
            updates["monthly_income"] = .double(monthlyIncome.doubleValue)
        }
        if let currency {
            updates["currency"] = .string(currency)
        }
        if let onboardingCompleted {
            updates["onboarding_completed"] = .bool(onboardingCompleted)
        }

        guard !updates.isEmpty else { return }

        try await client
            .from("profiles")
            .update(updates)
            .eq("id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Errors

    enum AuthError: LocalizedError {
        case noActiveSession
        case signUpFailed(String)
        case signInFailed(String)

        var errorDescription: String? {
            switch self {
            case .noActiveSession:
                return "No hay sesión activa. Inicia sesión nuevamente."
            case .signUpFailed(let message):
                return "Error al registrarse: \(message)"
            case .signInFailed(let message):
                return "Error al iniciar sesión: \(message)"
            }
        }
    }
}
