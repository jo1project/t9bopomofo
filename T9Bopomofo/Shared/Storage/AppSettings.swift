import Foundation

/// Shared settings in App Group (host app + keyboard).
/// Also mirrors to a JSON file so unsigned / flaky App Group UserDefaults still sync.
final class AppSettings: @unchecked Sendable {
    static let shared = AppSettings()

    private let suite = "group.com.jo1project.t9bopomofo"
    private let defaults: UserDefaults
    private let lock = NSLock()
    private var fileCache: FilePayload?

    private enum Key {
        static let llmEnabled = "settings_llm_enabled_v1"
        static let llmBaseURL = "settings_llm_base_url_v1"
        static let llmAPIKey = "settings_llm_api_key_v1"
        static let llmModel = "settings_llm_model_v1"
        static let iCloudAutoBackup = "settings_icloud_auto_backup_v1"
    }

    private struct FilePayload: Codable {
        var llmEnabled: Bool
        var llmBaseURL: String
        var llmAPIKey: String
        var llmModel: String
        var iCloudAutoBackup: Bool
    }

    private init() {
        defaults = UserDefaults(suiteName: suite) ?? .standard
        reloadFromDisk()
    }

    /// App Group container availability (unsigned IPA may lack a working group).
    var appGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suite) != nil
    }

    var settingsFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: suite)?
            .appendingPathComponent("SharedLibrary", isDirectory: true)
            .appendingPathComponent("llm_settings.json")
    }

    var llmEnabled: Bool {
        get {
            reloadFromDiskIfNeeded()
            if let fileCache { return fileCache.llmEnabled }
            return defaults.bool(forKey: Key.llmEnabled)
        }
        set { update { $0.llmEnabled = newValue } }
    }

    /// OpenAI-compatible base, e.g. `https://api.openai.com/v1`
    var llmBaseURL: String {
        get {
            reloadFromDiskIfNeeded()
            if let fileCache, !fileCache.llmBaseURL.isEmpty { return fileCache.llmBaseURL }
            let v = defaults.string(forKey: Key.llmBaseURL) ?? ""
            return v.isEmpty ? "https://api.openai.com/v1" : v
        }
        set { update { $0.llmBaseURL = newValue } }
    }

    var llmAPIKey: String {
        get {
            reloadFromDiskIfNeeded()
            if let fileCache, !fileCache.llmAPIKey.isEmpty { return fileCache.llmAPIKey }
            return defaults.string(forKey: Key.llmAPIKey) ?? ""
        }
        set { update { $0.llmAPIKey = newValue } }
    }

    var llmModel: String {
        get {
            reloadFromDiskIfNeeded()
            if let fileCache, !fileCache.llmModel.isEmpty { return fileCache.llmModel }
            let v = defaults.string(forKey: Key.llmModel) ?? ""
            return v.isEmpty ? "gpt-4o-mini" : v
        }
        set { update { $0.llmModel = newValue } }
    }

    var iCloudAutoBackup: Bool {
        get {
            reloadFromDiskIfNeeded()
            if let fileCache { return fileCache.iCloudAutoBackup }
            return defaults.bool(forKey: Key.iCloudAutoBackup)
        }
        set { update { $0.iCloudAutoBackup = newValue } }
    }

    var canUseLLM: Bool {
        llmEnabled && !llmAPIKey.isEmpty
    }

    /// Human-readable diagnostics for the settings screen / keyboard.
    var llmDiagnostics: String {
        reloadFromDisk()
        var parts: [String] = []
        parts.append(appGroupAvailable ? "App Group：可用" : "App Group：不可用（unsigned 常見，鍵盤可能讀不到設定）")
        if let url = settingsFileURL {
            let exists = FileManager.default.fileExists(atPath: url.path)
            parts.append(exists ? "設定檔：已寫入" : "設定檔：尚無")
        } else {
            parts.append("設定檔：無容器路徑")
        }
        parts.append(llmEnabled ? "開關：開" : "開關：關")
        parts.append(llmAPIKey.isEmpty ? "Key：未填" : "Key：已填（\(llmAPIKey.prefix(6))…）")
        parts.append("Model：\(llmModel)")
        return parts.joined(separator: "\n")
    }

    func reloadFromDisk() {
        lock.lock()
        defer { lock.unlock() }
        fileCache = readFileUnlocked()
        // Prefer file → UserDefaults when file exists (host wrote it).
        if let payload = fileCache {
            defaults.set(payload.llmEnabled, forKey: Key.llmEnabled)
            defaults.set(payload.llmBaseURL, forKey: Key.llmBaseURL)
            defaults.set(payload.llmAPIKey, forKey: Key.llmAPIKey)
            defaults.set(payload.llmModel, forKey: Key.llmModel)
            defaults.set(payload.iCloudAutoBackup, forKey: Key.iCloudAutoBackup)
            defaults.synchronize()
        }
    }

    private func reloadFromDiskIfNeeded() {
        // Cheap: always try file so keyboard sees host edits without restart.
        lock.lock()
        fileCache = readFileUnlocked() ?? fileCache
        lock.unlock()
    }

    private func update(_ body: (inout FilePayload) -> Void) {
        lock.lock()
        var payload = fileCache ?? FilePayload(
            llmEnabled: defaults.bool(forKey: Key.llmEnabled),
            llmBaseURL: defaults.string(forKey: Key.llmBaseURL) ?? "",
            llmAPIKey: defaults.string(forKey: Key.llmAPIKey) ?? "",
            llmModel: defaults.string(forKey: Key.llmModel) ?? "",
            iCloudAutoBackup: defaults.bool(forKey: Key.iCloudAutoBackup)
        )
        body(&payload)
        fileCache = payload
        defaults.set(payload.llmEnabled, forKey: Key.llmEnabled)
        defaults.set(payload.llmBaseURL, forKey: Key.llmBaseURL)
        defaults.set(payload.llmAPIKey, forKey: Key.llmAPIKey)
        defaults.set(payload.llmModel, forKey: Key.llmModel)
        defaults.set(payload.iCloudAutoBackup, forKey: Key.iCloudAutoBackup)
        defaults.synchronize()
        writeFileUnlocked(payload)
        lock.unlock()
    }

    private func readFileUnlocked() -> FilePayload? {
        guard let url = settingsFileURL, FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FilePayload.self, from: data)
    }

    private func writeFileUnlocked(_ payload: FilePayload) {
        guard let url = settingsFileURL else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}
