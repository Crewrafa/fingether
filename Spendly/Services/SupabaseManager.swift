import Foundation
import Supabase

// MARK: - Supabase Manager

final class SupabaseManager: Sendable {

    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: Constants.supabaseURL)!,
            supabaseKey: Constants.supabaseAnonKey
        )
    }
}
