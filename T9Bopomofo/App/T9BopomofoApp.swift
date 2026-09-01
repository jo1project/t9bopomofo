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
            BackupView()
                .tabItem { Label("備份", systemImage: "externaldrive") }
            LLMSettingsView()
                .tabItem { Label("LLM", systemImage: "sparkles") }
        }
    }
}

struct SetupView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("T9 注音鍵盤")
                        .font(.largeTitle.bold())
                    Text("內部 IPA／TestFlight 測試用。請依下列步驟啟用鍵盤並開啟「允許完整取用」。")
                        .foregroundStyle(.secondary)

                    numbered("1", "打開「設定 → 一般 → 鍵盤 → 鍵盤」")
                    numbered("2", "新增鍵盤，選擇「T9 注音」")
                    numbered("3", "點進該鍵盤，開啟「允許完整取用」（學習／備份／LLM 需要）")
                    numbered("4", "在任意 App 切換到此鍵盤開始測試")

                    Group {
                        Text("已知行為").font(.headline)
                        Text("• 選詞：librime + octagram；候選 ▼ 可展開")
                        Text("• 聲符鍵 34pt（鍵盤本體，不自動縮小）")
                        Text("• 。點＝句號／長按標點；123 長按表情；空格/EN")
                        Text("• 備份：本機 JSON 匯出／匯入，可選 iCloud KVS")
                        Text("• LLM：在「LLM」分頁填入相容 API，上屏後聯想")
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
                        status = lexicon.backupToiCloud() ? "已要求同步（unsigned 可能無效）" : "備份失敗"
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

struct LLMSettingsView: View {
    @State private var enabled = AppSettings.shared.llmEnabled
    @State private var baseURL = AppSettings.shared.llmBaseURL
    @State private var apiKey = AppSettings.shared.llmAPIKey
    @State private var model = AppSettings.shared.llmModel
    @State private var testStatus = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("啟用 LLM 聯想", isOn: $enabled)
                        .onChange(of: enabled) { _, v in AppSettings.shared.llmEnabled = v }
                    Text("上屏後，在本機 bigram 之外再向相容 API 要接續詞。需開啟鍵盤「完整取用」。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("OpenAI 相容 API") {
                    TextField("Base URL", text: $baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: baseURL) { _, v in AppSettings.shared.llmBaseURL = v }
                    SecureField("API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: apiKey) { _, v in AppSettings.shared.llmAPIKey = v }
                    TextField("Model", text: $model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: model) { _, v in AppSettings.shared.llmModel = v }
                }
                Section {
                    Button("測試聯想「你好」") {
                        testStatus = "請求中…"
                        Task {
                            let words = await LLMPredictor.shared.suggest(after: "你好", limit: 5)
                            await MainActor.run {
                                testStatus = words.isEmpty ? "無結果（檢查 Key／網路／完整取用）" : words.joined(separator: "、")
                            }
                        }
                    }
                    if !testStatus.isEmpty {
                        Text(testStatus)
                    }
                }
            }
            .navigationTitle("LLM 預測")
        }
    }
}
