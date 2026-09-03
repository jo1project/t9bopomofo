# Xcode Cloud / TestFlight（無本機 Mac 時）

目標：用 **正式簽名** 安裝，讓 App Group 生效，鍵盤才讀得到 LLM／贊助設定。

## 你先在網頁做的（必做）

### 1. App Group
[Identifiers → App Groups](https://developer.apple.com/account/resources/identifiers/list/applicationGroup)  
新增：`group.com.jo1project.t9bopomofo`

### 2. App ID 勾能力
[Identifiers](https://developer.apple.com/account/resources/identifiers/list) 分別編輯：

| Bundle ID | 要勾 |
|-----------|------|
| `com.jo1project.t9bopomofo` | App Groups（選上面那個）、In-App Purchase |
| `com.jo1project.t9bopomofo.keyboard` | App Groups（同一個） |

### 3. App Store Connect
確認已有 App「Jo一個T9注音」，SKU／Bundle 對得上。

## Xcode Cloud 怎麼開

Apple 目前多數情況：**第一個 workflow 要在 Xcode 裡建立一次**。  
沒有自己的 Mac 時可選：

1. **借／租一台 Mac 約 30 分鐘**（朋友、圖書館、雲端 Mac）只做第一次  
2. 或請有 Mac 的人幫你按下面步驟

### 在 Mac 上（只做一次）

```bash
git clone <repo> && cd t9bopomofo
git checkout cursor/app-polish-sponsor-99f2
./Scripts/download-frameworks.sh
./Scripts/download-models.sh
brew install xcodegen && xcodegen generate
open T9Bopomofo.xcodeproj
```

然後：

1. Xcode 登入你的 Apple ID（Team `S24Z424MU4`）
2. 兩個 target 都選 Automatic 簽名  
3. **Product → Xcode Cloud → Create Workflow**（或 Report navigator → Cloud）
4. 連 GitHub repo `jo1project/t9bopomofo`，分支可用 `cursor/app-polish-sponsor-99f2` 或之後的 `main`
5. Action 選 **Archive** → 目的選 **TestFlight Internal Testing**
6. Start Build

Repo 已有 `ci_scripts/ci_post_clone.sh`：Cloud 會自動 `xcodegen` + 下載 frameworks。

### 建好之後（不用 Mac）

- 之後每次 push，Xcode Cloud 可自動 Archive  
- 去 [App Store Connect → TestFlight](https://appstoreconnect.apple.com) 等處理完  
- iPhone 裝 **TestFlight** → 安裝「Jo一個T9注音」  
- 再開鍵盤「完整取用」→ App 裡測試解鎖／開 LLM

## 若暫時借不到 Mac

可改用 **Codemagic / GitHub Actions + 正式憑證**（要上傳 Distribution 憑證與 profile）。你若要走這條跟我說，我再改 workflow。

## 驗收

TestFlight 版裝好後，App → LLM → 診斷應顯示 **「App Group：可用」**，鍵盤才不會一直要贊助。
