import SwiftUI

@main
struct T9BopomofoApp: App {
    var body: some Scene {
        WindowGroup {
            SetupView()
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
                    numbered("3", "點進該鍵盤，開啟「允許完整取用」（本機詞庫學習需要）")
                    numbered("4", "在任意 App 切換到此鍵盤開始測試")

                    Group {
                        Text("已知行為（v0.1）").font(.headline)
                        Text("• 有候選時按符號／空格／換行：只插入該字元並清空組字，不會送出第一候選")
                        Text("• 支援 T9 一鍵多碼、聲調可省略")
                        Text("• 模糊：鄰鍵錯誤、漏打一碼")
                        Text("• 本機 bigram 學習；內建台灣詞（含拉亞等）")
                        Text("• 可切換 EN／符號／Emoji")
                    }
                }
                .padding()
            }
            .navigationTitle("設定說明")
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
