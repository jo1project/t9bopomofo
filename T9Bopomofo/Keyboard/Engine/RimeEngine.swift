import Foundation
import Darwin

/// Thin Swift wrapper around librime C API via `rime_get_api()`
/// (free `Rime*` helpers are C++-mangled in LibrimeKit 2.x).
final class RimeEngine {
    static let shared = RimeEngine()

    private(set) var isReady = false
    private var session: RimeSessionId = 0
    private let resourceVersion = "rime-bundle-v3-octagram"
    private let schemaId = "bopomofo_phone"

    private var sharedDir: NSString = ""
    private var userDir: NSString = ""
    private let distributionName: NSString = "T9Bopomofo"
    private let distributionCodeName: NSString = "t9bopomofo"
    private let distributionVersion: NSString = "0.3.9"
    private let appName: NSString = "rime.t9bopomofo"

    private init() {}

    private var api: UnsafeMutablePointer<RimeApi>? {
        rime_get_api()
    }

    // MARK: - Lifecycle

    @discardableResult
    func start(bundle: Bundle) -> Bool {
        guard let api else {
            NSLog("[RimeEngine] rime_get_api() returned nil")
            return false
        }
        if isReady, session != 0, api.pointee.find_session(session) != 0 {
            return true
        }

        guard let roots = deployResources(from: bundle) else {
            NSLog("[RimeEngine] resource deploy failed")
            return false
        }

        sharedDir = roots.shared as NSString
        userDir = roots.user as NSString

        var traits = RimeTraits()
        memset(&traits, 0, MemoryLayout<RimeTraits>.size)
        traits.data_size = Int32(MemoryLayout<RimeTraits>.size - MemoryLayout<Int32>.size)
        traits.shared_data_dir = sharedDir.utf8String
        traits.user_data_dir = userDir.utf8String
        traits.distribution_name = distributionName.utf8String
        traits.distribution_code_name = distributionCodeName.utf8String
        traits.distribution_version = distributionVersion.utf8String
        traits.app_name = appName.utf8String
        traits.min_log_level = 2

        api.pointee.setup(&traits)
        api.pointee.initialize(&traits)

        if api.pointee.start_maintenance(1) != 0 {
            api.pointee.join_maintenance_thread()
        }

        session = api.pointee.create_session()
        if session == 0 {
            NSLog("[RimeEngine] create_session failed")
            return false
        }
        _ = schemaId.withCString { api.pointee.select_schema(session, $0) }
        isReady = true
        let ver = api.pointee.get_version().map { String(cString: $0) } ?? "?"
        NSLog("[RimeEngine] ready schema=%@ version=%@", schemaId, ver)
        return true
    }

    func shutdown() {
        guard let api else { return }
        if session != 0 {
            _ = api.pointee.destroy_session(session)
            session = 0
        }
        if isReady {
            api.pointee.finalize()
            isReady = false
        }
    }

    // MARK: - Input

    @discardableResult
    func processKey(_ ch: Character) -> Bool {
        guard isReady, let api, let scalar = ch.unicodeScalars.first else { return false }
        return api.pointee.process_key(session, Int32(scalar.value), 0) != 0
    }

    @discardableResult
    func processKeyCode(_ code: Int32, mask: Int32 = 0) -> Bool {
        guard isReady, let api else { return false }
        return api.pointee.process_key(session, code, mask) != 0
    }

    func backspace() {
        _ = processKeyCode(0xff08)
    }

    func clearComposition() {
        guard isReady, let api else { return }
        api.pointee.clear_composition(session)
    }

    @discardableResult
    func selectCandidate(at index: Int) -> String {
        guard isReady, let api else { return "" }
        _ = api.pointee.select_candidate(session, index)
        return consumeCommit()
    }

    func consumeCommit() -> String {
        guard isReady, let api else { return "" }
        var commit = RimeCommit()
        memset(&commit, 0, MemoryLayout<RimeCommit>.size)
        commit.data_size = Int32(MemoryLayout<RimeCommit>.size - MemoryLayout<Int32>.size)
        guard api.pointee.get_commit(session, &commit) != 0 else { return "" }
        let text = commit.text.map { String(cString: $0) } ?? ""
        _ = api.pointee.free_commit(&commit)
        return text
    }

    // MARK: - Context

    var input: String {
        guard isReady, let api, let c = api.pointee.get_input(session) else { return "" }
        return String(cString: c)
    }

    var isComposing: Bool {
        guard isReady, let api else { return false }
        var status = RimeStatus()
        memset(&status, 0, MemoryLayout<RimeStatus>.size)
        status.data_size = Int32(MemoryLayout<RimeStatus>.size - MemoryLayout<Int32>.size)
        defer { _ = api.pointee.free_status(&status) }
        guard api.pointee.get_status(session, &status) != 0 else { return false }
        return status.is_composing != 0
    }

    var preedit: String {
        guard isReady, let api else { return "" }
        var ctx = RimeContext()
        memset(&ctx, 0, MemoryLayout<RimeContext>.size)
        ctx.data_size = Int32(MemoryLayout<RimeContext>.size - MemoryLayout<Int32>.size)
        defer { _ = api.pointee.free_context(&ctx) }
        guard api.pointee.get_context(session, &ctx) != 0 else { return "" }
        guard let p = ctx.composition.preedit else { return "" }
        return String(cString: p)
    }

    func candidates(limit: Int = 12) -> [(text: String, comment: String)] {
        guard isReady, let api else { return [] }
        var iterator = RimeCandidateListIterator()
        memset(&iterator, 0, MemoryLayout<RimeCandidateListIterator>.size)
        guard api.pointee.candidate_list_begin(session, &iterator) != 0 else { return [] }
        defer { api.pointee.candidate_list_end(&iterator) }

        var out: [(String, String)] = []
        out.reserveCapacity(limit)
        while out.count < limit, api.pointee.candidate_list_next(&iterator) != 0 {
            let text = iterator.candidate.text.map { String(cString: $0) } ?? ""
            let comment = iterator.candidate.comment.map { String(cString: $0) } ?? ""
            if !text.isEmpty {
                out.append((text, comment))
            }
        }
        return out
    }

    // MARK: - Deploy

    private struct Roots {
        let shared: String
        let user: String
    }

    private func deployResources(from: Bundle) -> Roots? {
        let fm = FileManager.default
        let container = fm.containerURL(forSecurityApplicationGroupIdentifier: "group.com.jo1project.t9bopomofo")
            ?? fm.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let base = container?.appendingPathComponent("rime", isDirectory: true) else {
            return nil
        }

        let sharedURL = base.appendingPathComponent("SharedSupport", isDirectory: true)
        let userURL = base.appendingPathComponent("user", isDirectory: true)
        let marker = userURL.appendingPathComponent(".bundle_version")

        guard let bundled = locateBundledRime(in: from) else {
            NSLog("[RimeEngine] bundled rime resources not found")
            return nil
        }

        let needSync: Bool = {
            guard let existing = try? String(contentsOf: marker, encoding: .utf8) else { return true }
            return existing.trimmingCharacters(in: .whitespacesAndNewlines) != resourceVersion
        }()

        if needSync {
            try? fm.removeItem(at: sharedURL)
            try? fm.createDirectory(at: sharedURL, withIntermediateDirectories: true)
            try? fm.createDirectory(at: userURL, withIntermediateDirectories: true)

            let sharedNames = [
                "essay.txt",
                "zh-hant-t-essay-bgw.gram",
                "default.yaml",
                "key_bindings.yaml",
                "punctuation.yaml",
                "symbols.yaml",
            ]
            for name in sharedNames {
                let src = bundled.appendingPathComponent(name)
                if fm.fileExists(atPath: src.path) {
                    try? fm.copyItem(at: src, to: sharedURL.appendingPathComponent(name))
                }
            }
            let opencc = bundled.appendingPathComponent("opencc")
            if fm.fileExists(atPath: opencc.path) {
                try? fm.copyItem(at: opencc, to: sharedURL.appendingPathComponent("opencc"))
            }

            let userNames = [
                "bopomofo_phone.schema.yaml",
                "bopomofo_t9.schema.yaml",
                "bopomofo_t9.dict.yaml",
                "taiwan_phrases.dict.yaml",
                "rime.lua",
            ]
            for name in userNames {
                let src = bundled.appendingPathComponent(name)
                let dst = userURL.appendingPathComponent(name)
                if fm.fileExists(atPath: dst.path) { try? fm.removeItem(at: dst) }
                if fm.fileExists(atPath: src.path) {
                    try? fm.copyItem(at: src, to: dst)
                }
            }
            let luaSrc = bundled.appendingPathComponent("lua")
            let luaDst = userURL.appendingPathComponent("lua")
            if fm.fileExists(atPath: luaDst.path) { try? fm.removeItem(at: luaDst) }
            if fm.fileExists(atPath: luaSrc.path) {
                try? fm.copyItem(at: luaSrc, to: luaDst)
            }

            let buildDir = userURL.appendingPathComponent("build")
            try? fm.removeItem(at: buildDir)

            try? resourceVersion.write(to: marker, atomically: true, encoding: .utf8)
            NSLog("[RimeEngine] synced resources → %@", userURL.path)
        }

        return Roots(shared: sharedURL.path, user: userURL.path)
    }

    private func locateBundledRime(in bundle: Bundle) -> URL? {
        let fm = FileManager.default
        let candidates: [URL] = [
            bundle.resourceURL?.appendingPathComponent("rime"),
            bundle.bundleURL.appendingPathComponent("rime"),
            URL(fileURLWithPath: "Resources/rime"),
            URL(fileURLWithPath: "../Resources/rime"),
            URL(fileURLWithPath: "/workspace/Resources/rime"),
        ].compactMap { $0 }
        for url in candidates where fm.fileExists(atPath: url.appendingPathComponent("bopomofo_phone.schema.yaml").path) {
            return url
        }
        return nil
    }
}
