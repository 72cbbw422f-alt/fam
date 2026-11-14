import Foundation
import Supabase

/// Creates the Supabase client from local, non-secret app configuration.
/// The anon/publishable key is intended for client use; never use service-role keys here.
enum SupabaseClientProvider {
    static func makeClient() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: AppConfig.supabaseURL,
            supabaseKey: AppConfig.supabaseAnonKey
        )
    }
}
