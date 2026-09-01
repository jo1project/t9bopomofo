import Foundation

/// Shared settings in App Group (host app + keyboard).
final class AppSettings: @unchecked Sendable {
    static let shared = AppSettings()

    private let defaults: UserDefaults
    private let suite = "group.com.jo1project.t9bopomofo"

    private enum Key {
        static let llmEnabled = "settings_llm_enabled_v1"
        static let llmBaseURL = "settings_llm_base_url_v1"
        static let llmAPIKey = "settings_llm_api_key_v1"
        static let llmModel = "settings_llm_model_v1"
        static let iCloudAutoBackup = "settings_icloud_auto_backup_v1"
    }

    private init() {
        defaults = UserDefaults(suiteName: suite) ?? .standard
    }

    var llmEnabled: Bool {
        get { defaults.bool(forKey: Key.llmEnabled) }
        set { defaults.set(newValue, forKey: Key.llmEnabled) }
    }

    /// OpenAI-compatible base, e.g. `https://api.openai.com/v1`
    var llmBaseURL: String {
        get {
            let v = defaults.string(forKey: Key.llmBaseURL) ?? ""
            return v.isEmpty ? "https://api.openai.com/v1" : v
        }
        set { defaults.set(newValue, forKey: Key.llmBaseURL) }
    }

    var llmAPIKey: String {
        get { defaults.string(forKey: Key.llmAPIKey) ?? "" }
        set { defaults.set(newValue, forKey: Key.llmAPIKey) }
    }

    var llmModel: String {
        get {
            let v = defaults.string(forKey: Key.llmModel) ?? ""
            return v.isEmpty ? "gpt-4o-mini" : v
        }
        set { defaults.set(newValue, forKey: Key.llmModel) }
    }

    var iCloudAutoBackup: Bool {
        get { defaults.bool(forKey: Key.iCloudAutoBackup) }
        set { defaults.set(newValue, forKey: Key.iCloudAutoBackup) }
    }

    var canUseLLM: Bool {
        llmEnabled && !llmAPIKey.isEmpty
    }
}
