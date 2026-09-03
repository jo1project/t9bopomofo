# 無 Mac：用 Codemagic 簽好丟 TestFlight

不需要本機 Xcode。Codemagic 雲端 Mac 會簽名並上傳 TestFlight。

## 0. 開發者後台（先做，否則 App Group 仍會掛）

1. [App Groups](https://developer.apple.com/account/resources/identifiers/list/applicationGroup)  
   新增：`group.com.jo1project.t9bopomofo`
2. [Identifiers](https://developer.apple.com/account/resources/identifiers/list)  
   - `com.jo1project.t9bopomofo`：勾 **App Groups**（選上面）+ **In-App Purchase**  
   - `com.jo1project.t9bopomofo.keyboard`：勾 **App Groups**（同一個）

## 1. App Store Connect API Key

1. 打開 [Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api)  
2. 產生 Key，權限選 **Admin** 或至少 **App Manager**  
3. 下載一次 `.p8`（只會下載一次，存好）  
4. 記下 **Issuer ID**、**Key ID**

## 2. 註冊 Codemagic

1. 打開 https://codemagic.io 用 GitHub 登入  
2. 新增應用 → 選 repo `jo1project/t9bopomofo`  
3. 分支用 `cursor/app-polish-sponsor-99f2`（或之後的 `main`）  
4. 設定裡會讀到根目錄的 `codemagic.yaml`

## 3. 接上 App Store Connect

在 Codemagic 專案設定：

1. **Teams / Integrations → App Store Connect**  
2. 新增 integration，名稱必須是：`JoT9ASC`（與 `codemagic.yaml` 裡一致）  
3. 貼上 Issuer ID、Key ID、`.p8` 內容  
4. Code signing：選 **App Store** distribution，bundle id 含：  
   - `com.jo1project.t9bopomofo`  
   - `com.jo1project.t9bopomofo.keyboard`

（若 UI 有「Fetch certificates」／自動簽名，打開它。）

## 4. 開跑

1. Start new build → workflow **iOS TestFlight (signed)**  
2. 等綠燈  
3. 到 [TestFlight](https://appstoreconnect.apple.com) 等「正在處理」結束  
4. iPhone 裝 TestFlight → 安裝「Jo一個T9注音」  
5. 系統設定開啟鍵盤 + **允許完整取用**  
6. App → LLM 診斷應顯示 **App Group：可用** → 再測試解鎖／開 LLM

## 常見失敗

| 現象 | 處理 |
|------|------|
| signing / profile 失敗 | 確認兩個 Bundle ID 都在 Developer 後台，且 App Group 已勾 |
| integration 名稱不符 | yaml 裡是 `JoT9ASC`，Codemagic 裡同名 |
| TestFlight 看不到建置 | 檢查郵箱邀請、是否同一 Apple ID |
| 仍 App Group 不可用 | 重做第 0 步後再打一版 |

## 和 unsigned GitHub IPA 的差別

| | GitHub unsigned | Codemagic TestFlight |
|--|-----------------|----------------------|
| 簽名 | 無 | App Store 簽名 |
| App Group | 通常無效 | 有效 |
| LLM 設定同步到鍵盤 | ❌ | ✅ |
