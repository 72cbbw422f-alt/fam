import Foundation

/// Copy this file to Config.swift and fill in the public Supabase project values.
/// Never add a service-role key to the iOS app.
enum AppConfig {
    static let supabaseURL = URL(string: "https://YOUR_PROJECT.supabase.co")!
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_OR_PUBLISHABLE_KEY"
}
