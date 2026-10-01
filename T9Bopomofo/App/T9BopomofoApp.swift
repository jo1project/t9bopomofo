import SwiftUI
import UniformTypeIdentifiers

@main
struct T9BopomofoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            SetupView()
                .tabItem { Label("啟用", systemImage: "keyboard") }
            KeyboardSettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
            BackupView()
                .tabItem { Label("備份", systemImage: "externaldrive") }
            LLMSettingsView()
                .tabItem { Label("LLM", systemImage: "sparkles") }
        }
    }
}

// MARK: - Setup

struct SetupView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Jo一個T9注音")
                        .font(.largeTitle.bold())
                    Text("T9 注音鍵盤。請依下列步驟啟用，並開啟「允許完整取用」以使用學習、備份與 LLM。")
                        .foregroundStyle(.secondary)

                    numbered("1", "打開「設定 → 一般 → 鍵盤 → 鍵盤」")
                    numbered("2", "新增鍵盤，選擇「Jo一個T9注音」")
                    numbered("3", "點進該鍵盤，開啟「允許完整取用」")
                    numbered("4", "在任意 App 切換到此鍵盤開始使用")

                    Group {
                        Text("功能摘要").font(.headline)
                        Text("• 選詞：libchewing 詞庫 + 自學排序；候選 ▼ 可展開")
                        Text("• 長按注音／標點：在原地左右滑即可切換選項")
                        Text("• 臨近鍵容錯：預設開啟；可於「設定」關閉")
                        Text("• LLM 聯想：自備 API Key，於 LLM 分頁設定")
                        Text("• 。點＝句號／長按標點；123 長按表情；空格/EN")
                        Text("• 英文：⇧ 點一下大寫下一個、再點 ⇪ 鎖定")
                    }
                }
                .padding()
            }
            .navigationTitle("啟用說明")
        }
    }

    private func numbered(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(n)
                .font(.headline)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
            Text(text)
        }
    }
}

// MARK: - Keyboard settings

struct KeyboardSettingsView: View {
    @State private var fuzzyOn = AppSettings.shared.fuzzyNeighborEnabled
    @State private var hapticsOn = AppSettings.shared.hapticsEnabled
    @State private var soundsOn = AppSettings.shared.soundsEnabled

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("臨近鍵容錯", isOn: $fuzzyOn)
                        .onChange(of: fuzzyOn) { _, v in
                            AppSettings.shared.fuzzyNeighborEnabled = v
                        }
                    Text("關閉後只保留精確匹配。預設開啟。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("輸入")
                }

                Section("回饋") {
                    Toggle("按鍵音效", isOn: $soundsOn)
                        .onChange(of: soundsOn) { _, v in
                            AppSettings.shared.soundsEnabled = v
                        }
                    Toggle("按鍵觸覺回饋", isOn: $hapticsOn)
                        .onChange(of: hapticsOn) { _, v in
                            AppSettings.shared.hapticsEnabled = v
                        }
                }

                Section("外觀") {
                    Text("鍵盤會跟隨系統淺色／深色模式。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("鍵盤設定")
            .onAppear {
                AppSettings.shared.reloadFromDisk()
                fuzzyOn = AppSettings.shared.fuzzyNeighborEnabled
                hapticsOn = AppSettings.shared.hapticsEnabled
                soundsOn = AppSettings.shared.soundsEnabled
            }
        }
    }
}

// MARK: - Backup

struct BackupView: View {
    @State private var lexicon = UserLexicon()
    @State private var status = ""
    @State private var autoICloud = AppSettings.shared.iCloudAutoBackup
    @State private var exportItem: BackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false

    var body: some View {
        NavigationStack {
            Form {
                Section("本機詞庫") {
                    Text(lexicon.statsSummary)
                        .foregroundStyle(.secondary)
                    Button("重新整理統計") {
                        lexicon = UserLexicon()
                        status = "已重新載入"
                    }
                }
                Section("檔案備份") {
                    Button("匯出 JSON…") {
                        if let data = try? lexicon.exportJSON() {
                            exportItem = BackupDocument(data: data)
                            showExporter = true
                        } else {
                            status = "匯出失敗"
                        }
                    }
                    Button("匯入並合併…") { showImporter = true }
                    Text("可存到「檔案」App／iCloud Drive，換機時再匯入。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("iCloud（需正式簽名＋開啟 iCloud）") {
                    Toggle("上屏時自動寫入 iCloud KVS", isOn: $autoICloud)
                        .onChange(of: autoICloud) { _, v in
                            AppSettings.shared.iCloudAutoBackup = v
                        }
                    Button("立即備份到 iCloud") {
                        status = lexicon.backupToiCloud() ? "已要求同步" : "備份失敗"
                    }
                    Button("從 iCloud 還原（合併）") {
                        status = lexicon.restoreFromiCloud(merge: true) ? "已還原並合併" : "沒有可用備份"
                        lexicon = UserLexicon()
                    }
                }
                if !status.isEmpty {
                    Section("狀態") { Text(status) }
                }
            }
            .navigationTitle("詞庫備份")
            .fileExporter(
                isPresented: $showExporter,
                document: exportItem,
                contentType: .json,
                defaultFilename: "t9bopomofo-lexicon"
            ) { result in
                switch result {
                case .success: status = "匯出完成"
                case .failure(let e): status = "匯出錯誤：\(e.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    do {
                        let accessed = url.startAccessingSecurityScopedResource()
                        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                        let data = try Data(contentsOf: url)
                        _ = try lexicon.importJSON(data, merge: true)
                        lexicon = UserLexicon()
                        status = "匯入合併完成"
                    } catch {
                        status = "匯入失敗：\(error.localizedDescription)"
                    }
                case .failure(let e):
                    status = "匯入錯誤：\(e.localizedDescription)"
                }
            }
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - LLM (bring your own key)

struct LLMSettingsView: View {
    @State private var enabled = AppSettings.shared.llmEnabled
    @State private var provider = LLMProviderPreset.matching(baseURL: AppSettings.shared.llmBaseURL)
    @State private var baseURL = AppSettings.shared.llmBaseURL
    @State private var apiKey = AppSettings.shared.llmAPIKey
    @State private var model = AppSettings.shared.llmModel
    @State private var testStatus = ""
    @State private var diagnostics = AppSettings.shared.llmDiagnostics

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("啟用 LLM 聯想", isOn: $enabled)
                        .onChange(of: enabled) { _, v in
                            AppSettings.shared.llmEnabled = v
                            diagnostics = AppSettings.shared.llmDiagnostics
                        }
                    Text("選詞上屏後會出現淺藍 ✦ 聯想。需鍵盤「完整取用」。請確認上方「啟用 LLM 聯想」已打開。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Group {
                    Section("服務商") {
                        Picker("API", selection: $provider) {
                            ForEach(LLMProviderPreset.allCases) { p in
                                Text(p.title).tag(p)
                            }
                        }
                        .onChange(of: provider) { _, p in
                            applyProvider(p)
                        }
                        Text(provider.note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Section("OpenAI 相容 API") {
                        TextField("Base URL", text: $baseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: baseURL) { _, v in
                                AppSettings.shared.llmBaseURL = v
                                diagnostics = AppSettings.shared.llmDiagnostics
                            }
                        SecureField("API Key（必填）", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: apiKey) { _, v in
                                AppSettings.shared.llmAPIKey = v
                                diagnostics = AppSettings.shared.llmDiagnostics
                            }
                        TextField("Model", text: $model)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: model) { _, v in
                                AppSettings.shared.llmModel = v
                                diagnostics = AppSettings.shared.llmDiagnostics
                            }
                    }
                    Section("診斷（鍵盤讀得到嗎）") {
                        Text(diagnostics)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if !AppSettings.shared.appGroupAvailable {
                            Text("若顯示 App Group 不可用：請改用 Xcode 開發者簽名安裝，不要只重裝 unsigned IPA。")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                        Button("重新檢查") { reloadLocal() }
                    }
                    Section {
                        Button("測試聯想「你好」") {
                            testStatus = "請求中…"
                            Task {
                                let result = await LLMPredictor.shared.suggestDetailed(after: "你好", limit: 5)
                                await MainActor.run {
                                    if result.words.isEmpty {
                                        testStatus = "失敗：\(result.errorMessage ?? "未知錯誤")"
                                    } else {
                                        testStatus = result.words.joined(separator: "、")
                                    }
                                }
                            }
                        }
                        if !testStatus.isEmpty {
                            Text(testStatus)
                        }
                    }
                }
            }
            .navigationTitle("LLM 預測")
            .onAppear {
                reloadLocal()
            }
        }
    }

    private func reloadLocal() {
        AppSettings.shared.reloadFromDisk()
        enabled = AppSettings.shared.llmEnabled
        baseURL = AppSettings.shared.llmBaseURL
        apiKey = AppSettings.shared.llmAPIKey
        model = AppSettings.shared.llmModel
        provider = LLMProviderPreset.matching(baseURL: baseURL)
        diagnostics = AppSettings.shared.llmDiagnostics
    }

    private func applyProvider(_ p: LLMProviderPreset) {
        if let url = p.exampleBaseURL {
            baseURL = url
            AppSettings.shared.llmBaseURL = url
        }
        if let m = p.exampleModel {
            model = m
            AppSettings.shared.llmModel = m
        }
        diagnostics = AppSettings.shared.llmDiagnostics
        if p == .custom {
            testStatus = "自訂：請自行填 Base URL／Model／Key"
        } else {
            testStatus = "已填 \(p.title) 範例，請貼上該服務的 API Key"
        }
    }
}
