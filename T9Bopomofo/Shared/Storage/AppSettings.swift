import Foundation

/// Shared settings in App Group (host app + keyboard).
/// Also mirrors to a JSON file so unsigned / flaky App Group UserDefaults still sync.
/// API key prefers Keychain; file/UserDefaults keep a non-secret presence flag for diagnostics.
final class AppSettings: @unchecked Sendable {
    static let shared = AppSettings()

    private let suite = "group.com.jo1project.t9bopomofo"
    private let defaults: UserDefaults
    private let lock = NSLock()
    private var fileCache: FilePayload?
    private let apiKeyAccount = "llm_api_key"

    private enum Key {
        static let llmEnabled = "settings_llm_enabled_v1"
        static let llmBaseURL = "settings_llm_base_url_v1"
        static let llmAPIKey = "settings_llm_api_key_v1" // legacy mirror only
        static let llmModel = "settings_llm_model_v1"
        static let iCloudAutoBackup = "settings_icloud_auto_backup_v1"
        static let isSponsored = "settings_is_sponsored_v1"
        static let fuzzyNeighborEnabled = "settings_fuzzy_neighbor_v1"
        static let hapticsEnabled = "settings_haptics_v1"
    }

    private struct FilePayload: Codable {
        var llmEnabled: Bool
        var llmBaseURL: String
        var llmAPIKey: String
        var llmModel: String
        var iCloudAutoBackup: Bool
        var isSponsored: Bool
        var fuzzyNeighborEnabled: Bool
        var hapticsEnabled: Bool

        enum CodingKeys: String, CodingKey {
            case llmEnabled, llmBaseURL, llmAPIKey, llmModel, iCloudAutoBackup
            case isSponsored, fuzzyNeighborEnabled, hapticsEnabled
        }

        init(
            llmEnabled: Bool,
            llmBaseURL: String,
            llmAPIKey: String,
            llmModel: String,
            iCloudAutoBackup: Bool,
            isSponsored: Bool,
            fuzzyNeighborEnabled: Bool,
            hapticsEnabled: Bool
        ) {
            self.llmEnabled = llmEnabled
            self.llmBaseURL = llmBaseURL
            self.llmAPIKey = llmAPIKey
            self.llmModel = llmModel
            self.iCloudAutoBackup = iCloudAutoBackup
            self.isSponsored = isSponsored
            self.fuzzyNeighborEnabled = fuzzyNeighborEnabled
            self.hapticsEnabled = hapticsEnabled
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            llmEnabled = try c.decodeIfPresent(Bool.self, forKey: .llmEnabled) ?? false
            llmBaseURL = try c.decodeIfPresent(String.self, forKey: .llmBaseURL) ?? ""
            llmAPIKey = try c.decodeIfPresent(String.self, forKey: .llmAPIKey) ?? ""
            llmModel = try c.decodeIfPresent(String.self, forKey: .llmModel) ?? ""
            iCloudAutoBackup = try c.decodeIfPresent(Bool.self, forKey: .iCloudAutoBackup) ?? false
            isSponsored = try c.decodeIfPresent(Bool.self, forKey: .isSponsored) ?? false
            // Default ON for fuzzy.
            fuzzyNeighborEnabled = try c.decodeIfPresent(Bool.self, forKey: .fuzzyNeighborEnabled) ?? true
            hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        }
    }

    private init() {
        defaults = UserDefaults(suiteName: suite) ?? .standard
        // One-time migrate legacy plaintext key → Keychain.
        if KeychainStore.get(account: apiKeyAccount) == nil,
           let legacy = defaults.string(forKey: Key.llmAPIKey), !legacy.isEmpty {
            KeychainStore.set(legacy, account: apiKeyAccount)
        }
        reloadFromDisk()
        // Ensure fuzzy default is ON when key never written.
        if defaults.object(forKey: Key.fuzzyNeighborEnabled) == nil {
            defaults.set(true, forKey: Key.fuzzyNeighborEnabled)
        }
        if defaults.object(forKey: Key.hapticsEnabled) == nil {
            defaults.set(true, forKey: Key.hapticsEnabled)
        }
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
            if let kc = KeychainStore.get(account: apiKeyAccount), !kc.isEmpty { return kc }
            reloadFromDiskIfNeeded()
            if let fileCache, !fileCache.llmAPIKey.isEmpty { return fileCache.llmAPIKey }
            return defaults.string(forKey: Key.llmAPIKey) ?? ""
        }
        set {
            KeychainStore.set(newValue, account: apiKeyAccount)
            // Keep a presence flag for keyboard diagnostics; avoid writing full key to file when possible.
            update { $0.llmAPIKey = newValue.isEmpty ? "" : "•keychain•" }
            // Also clear legacy plaintext if emptying.
            if newValue.isEmpty {
                defaults.removeObject(forKey: Key.llmAPIKey)
            }
        }
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

    /// One-time sponsor unlock (StoreKit non-consumable).
    var isSponsored: Bool {
        get {
            reloadFromDiskIfNeeded()
            if let fileCache { return fileCache.isSponsored }
            return defaults.bool(forKey: Key.isSponsored)
        }
        set { update { $0.isSponsored = newValue } }
    }

    /// Neighbor-key / missing-key fuzzy. Default ON. Free users stay ON; paid may turn off.
    var fuzzyNeighborEnabled: Bool {
        get {
            reloadFromDiskIfNeeded()
            if let fileCache { return fileCache.fuzzyNeighborEnabled }
            if defaults.object(forKey: Key.fuzzyNeighborEnabled) == nil { return true }
            return defaults.bool(forKey: Key.fuzzyNeighborEnabled)
        }
        set {
            // Free users cannot disable.
            let resolved = isSponsored ? newValue : true
            update { $0.fuzzyNeighborEnabled = resolved }
        }
    }

    var hapticsEnabled: Bool {
        get {
            reloadFromDiskIfNeeded()
            if let fileCache { return fileCache.hapticsEnabled }
            if defaults.object(forKey: Key.hapticsEnabled) == nil { return true }
            return defaults.bool(forKey: Key.hapticsEnabled)
        }
        set { update { $0.hapticsEnabled = newValue } }
    }

    /// Effective fuzzy: always true unless sponsored AND user turned it off.
    var fuzzyNeighborEffective: Bool {
        if !isSponsored { return true }
        return fuzzyNeighborEnabled
    }

    var canUseLLM: Bool {
        isSponsored && llmEnabled && !llmAPIKey.isEmpty
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
        parts.append(isSponsored ? "贊助：已解鎖" : "贊助：未解鎖（LLM 需單次贊助）")
        parts.append(llmEnabled ? "開關：開" : "開關：關")
        parts.append(llmAPIKey.isEmpty ? "Key：未填" : "Key：已填（Keychain）")
        parts.append("Model：\(llmModel)")
        parts.append(fuzzyNeighborEffective ? "臨近鍵容錯：開" : "臨近鍵容錯：關")
        return parts.joined(separator: "\n")
    }

    func reloadFromDisk() {
        lock.lock()
        defer { lock.unlock() }
        fileCache = readFileUnlocked()
        if let payload = fileCache {
            defaults.set(payload.llmEnabled, forKey: Key.llmEnabled)
            defaults.set(payload.llmBaseURL, forKey: Key.llmBaseURL)
            defaults.set(payload.llmModel, forKey: Key.llmModel)
            defaults.set(payload.iCloudAutoBackup, forKey: Key.iCloudAutoBackup)
            defaults.set(payload.isSponsored, forKey: Key.isSponsored)
            defaults.set(payload.fuzzyNeighborEnabled, forKey: Key.fuzzyNeighborEnabled)
            defaults.set(payload.hapticsEnabled, forKey: Key.hapticsEnabled)
            // Migrate key from file into Keychain once.
            if payload.llmAPIKey != "•keychain•", !payload.llmAPIKey.isEmpty,
               KeychainStore.get(account: apiKeyAccount) == nil {
                KeychainStore.set(payload.llmAPIKey, account: apiKeyAccount)
            }
            defaults.synchronize()
        }
    }

    private func reloadFromDiskIfNeeded() {
        lock.lock()
        fileCache = readFileUnlocked() ?? fileCache
        lock.unlock()
    }

    private func currentPayload() -> FilePayload {
        fileCache ?? FilePayload(
            llmEnabled: defaults.bool(forKey: Key.llmEnabled),
            llmBaseURL: defaults.string(forKey: Key.llmBaseURL) ?? "",
            llmAPIKey: KeychainStore.get(account: apiKeyAccount) == nil ? (defaults.string(forKey: Key.llmAPIKey) ?? "") : "•keychain•",
            llmModel: defaults.string(forKey: Key.llmModel) ?? "",
            iCloudAutoBackup: defaults.bool(forKey: Key.iCloudAutoBackup),
            isSponsored: defaults.bool(forKey: Key.isSponsored),
            fuzzyNeighborEnabled: defaults.object(forKey: Key.fuzzyNeighborEnabled) == nil
                ? true : defaults.bool(forKey: Key.fuzzyNeighborEnabled),
            hapticsEnabled: defaults.object(forKey: Key.hapticsEnabled) == nil
                ? true : defaults.bool(forKey: Key.hapticsEnabled)
        )
    }

    private func update(_ body: (inout FilePayload) -> Void) {
        lock.lock()
        var payload = currentPayload()
        body(&payload)
        fileCache = payload
        defaults.set(payload.llmEnabled, forKey: Key.llmEnabled)
        defaults.set(payload.llmBaseURL, forKey: Key.llmBaseURL)
        defaults.set(payload.llmModel, forKey: Key.llmModel)
        defaults.set(payload.iCloudAutoBackup, forKey: Key.iCloudAutoBackup)
        defaults.set(payload.isSponsored, forKey: Key.isSponsored)
        defaults.set(payload.fuzzyNeighborEnabled, forKey: Key.fuzzyNeighborEnabled)
        defaults.set(payload.hapticsEnabled, forKey: Key.hapticsEnabled)
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
        // Never persist raw API key in the shared JSON when Keychain holds it.
        var safe = payload
        if KeychainStore.get(account: apiKeyAccount) != nil {
            safe.llmAPIKey = "•keychain•"
        }
        guard let data = try? JSONEncoder().encode(safe) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}
