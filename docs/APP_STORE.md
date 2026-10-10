# App Store 上架資料

App Store Connect 各欄位可直接複製。語言：繁體中文（主要）。

## 基本資料

| 欄位 | 內容 |
|---|---|
| 名稱（≤30） | Jo一個T9注音 |
| 副標題（≤30） | 九宮格注音鍵盤，單手打中文 |
| 類別 | 主要：工具程式；次要：生產力工具 |
| 價格 | 免費 |
| 隱私權政策網址 | https://github.com/jo1project/t9bopomofo/blob/main/docs/PRIVACY.md |
| 支援網址 | https://github.com/jo1project/t9bopomofo/issues |
| 版權 | © 2026 jo1project |
| 裝置 | 僅 iPhone |

## 推廣文字（≤170，可隨時修改不需送審）

```
九個鍵就能打注音！長句一次選到、候選字一鍵展開、長按原地滑動選注音與標點。不收集任何資料，還能接上你自己的 AI 聯想。
```

## 關鍵字（≤100，逗號分隔不加空格）

```
注音,九宮格,T9,輸入法,鍵盤,ㄅㄆㄇ,繁體中文,台灣,單手,中文輸入,打字,選字,聲調,AI聯想,長輩
```

不放 ChatGPT、Gemini 等商標名稱（審核準則 2.3.7）；App 名稱裡已有的字也不用重複。

## 描述（≤4000）

App Store Connect 會拒收部分符號（例如 ●、▼、→、・、聲調符號），這裡只用一般中文標點。

```
Jo一個T9注音：把注音放進九個鍵，單手也能快速打中文。

懷念傳統手機的九宮格打字嗎？Jo一個T9注音把 37 個注音符號分配到九宮格上，不用精準點到小小的按鍵，按大格子就能打字，特別適合單手操作、手指比較粗，或是家中長輩使用。

【主要特色】

1. 長句一次打到位
連續輸入多個字的注音，鍵盤會自動斷詞組句。例如連續打出「想一下」三個字的注音，就能直接選到整個詞。搭配聲調鍵，選字更精準。

2. 候選字一鍵展開
點候選列右邊的展開按鈕，就能看到完整候選清單，多字詞也會完整顯示，不會被截斷。

3. 長按原地左右滑
長按注音鍵，手指在原地左右滑，就能指定要打的那一個注音；長按句號鍵選標點，長按聲調鍵換聲調。

4. 打錯也找得到
「臨近鍵容錯」會把按到旁邊的鍵、少按一個鍵的情況一起列入候選（可在設定中關閉）。

5. 越用越懂你
常選的字詞會自動排到前面，並根據上一個詞建議下一個詞。學習紀錄只存在你的裝置上，可匯出備份或用 iCloud 同步。

6. 可接自己的 AI 聯想（選用）
支援 OpenAI 相容 API，填入你自己的 API Key，選字後就會出現 AI 建議的下一句。預設關閉，資料直接從你的手機送到你選的服務。

7. 英文、數字、符號、表情符號
長按空白鍵切換英文鍵盤，123 鍵切換數字符號，長按 123 打表情符號。

【重視隱私】
沒有廣告、沒有帳號。開發者不收集任何資料，你打的字不會傳給我們。

【啟用方式】
1. 打開「設定」，進入「一般」、「鍵盤」、「鍵盤」
2. 新增鍵盤，選擇「Jo一個T9注音」
3. 點進該鍵盤，開啟「允許完整取用」（用於共用學習紀錄；選用的 AI 聯想與 iCloud 備份也需要）
4. 在任何 App 中切換到此鍵盤開始使用

詞庫採用 libchewing（新酷音）開源詞庫。
```

## 這個版本的新功能（What's New）

```
- 首次正式上架
- 長句辨識更準確，連續輸入也能選到完整詞組
- 打字更順，修正偶發的卡頓
- 展開候選清單時，多字詞完整顯示
- 有 Home 鍵的 iPhone 可用地球鍵切換鍵盤
```

## App 隱私（營養標籤）

選 **「不收集資料」（Data Not Collected）**。

理由：開發者沒有伺服器、沒有分析或廣告 SDK。學習紀錄只在裝置上；iCloud 備份存在使用者自己的 iCloud。LLM 聯想是使用者自行選擇服務並填入自己的 API Key，請求從裝置直接送到該服務，開發者與其合作夥伴都拿不到。（這是依 Apple「收集」定義的判斷；若審核方有不同看法，再改為「其他使用者內容：不連結身分、用於 App 功能」。）

## 年齡分級

問卷全部選「無」。產生式 AI 相關問題：App 本身不提供 AI 服務，只有使用者自備 Key 時才會連到第三方，且只回傳下一詞建議，照實填寫即可。預期分級：4+。

## 審核備註（App Review Information → Notes）

```
This is a T9 Bopomofo (Zhuyin) keyboard extension for Traditional Chinese.

How to test:
1. Install the app, open Settings > General > Keyboard > Keyboards > Add New Keyboard, choose "Jo一個T9注音".
2. Optionally enable "Allow Full Access".
3. In any text field (e.g. Notes), switch to the keyboard. Tap keys like ㄏㄒㄠㄡ (8), ㄔㄘㄣㄧ (6), ㄕㄙㄤㄨ (9) and pick candidates from the bar.

Full Access is used only to share the local learning data and settings between the app and the keyboard (App Group), and — only if the user turns them on — for the optional LLM suggestion feature and iCloud key-value backup. The keyboard works without Full Access.

The LLM feature is optional and off by default. Users enter their own API key for an OpenAI-compatible service of their choice; requests go directly from the device to that service. No demo account or key is required to review the app's core functionality.

The app collects no data, has no accounts, ads, analytics or in-app purchases.
```

聯絡資訊（姓名、電話、Email）請在 App Store Connect 自行填寫，不放在 repo 裡。

## 截圖

`docs/app-store-screenshots/`，iPhone 6.9 吋（1320×2868），依序上傳：

1. `01-long-phrase` — 九宮格注音，長句一次打到位
2. `02-expanded` — 候選字一鍵展開，多字詞完整顯示
3. `03-callout` — 長按原地左右滑，精準指定注音
4. `04-llm` — 接上自己的 AI，聯想更聰明
5. `05-setup` — 三步驟啟用，不收集任何個人資料

重新產生：`python Scripts/render_asc_screenshots.py`（需 Windows 的微軟正黑體；鍵盤外觀照 Swift 程式碼的尺寸與顏色畫，候選字由 `Tests/test_engine_ref.py` 的參考引擎算出）。6.9 吋截圖 App Store 會自動縮放給其他尺寸的 iPhone 使用。

## 送審前檢查

- [x] **地球鍵（審核準則 4.4.1）：** 有 Home 鍵的 iPhone（SE 2/3）系統不顯示地球鍵，候選列右側會出現 🌐（點一下換下一個鍵盤、長按選鍵盤）。
- [ ] 分支 merge 進 main 後，隱私權政策網址才會生效（網址指向 main）。
- [x] 版本號與 build 號碼照下方「版本號與 build 號碼」檢查過。

## 版本號與 build 號碼

每次推 TestFlight 前都要檢查這兩個號碼，否則 App Store Connect 會拒收。

**版本號（CFBundleShortVersionString）**
- 某個版本一旦通過審核，就不能再上傳同版本號的新 build（錯誤 90062：must contain a higher version than that of the previously approved version）。
- 修 bug 升最後一碼（1.0.0 → 1.0.1），加新功能升中間那碼（1.0.x → 1.1.0）。
- 五個地方要一起改：
  - `project.yml` 的 `MARKETING_VERSION`（3 處）
  - `T9Bopomofo/App/Info.plist`
  - `T9Bopomofo/Keyboard/Info.plist`
  - `.github/workflows/testflight.yml`（寫死在 `plutil` 和 `echo` 裡）
  - `codemagic.yaml`（寫死在 `plutil`、`PlistBuddy` 和 `echo` 裡）

**Build 號碼（CFBundleVersion）**
- `testflight.yml` 執行時用 `project.yml` 的 `CURRENT_PROJECT_VERSION` 加 1，但**不會把新號碼存回 repo**，所以從不同分支或連續觸發都會撞號。
- 推之前先查最後一次上傳用的號碼：`gh run list --workflow testflight.yml` 找出最近幾次執行，再到各自的 log 找 `New build: N`（所有分支都算）。
- 把 `project.yml` 的 `CURRENT_PROJECT_VERSION`（3 處）改成那個 N，這次上傳就會是 N+1。
- `codemagic.yaml` 會自己去 App Store Connect 查最新號碼，不需要手動改。

**紀錄**

| 版本 | Build | 來源 | 狀態 |
|---|---|---|---|
| 1.0.0 | 89 | main | 已上架 |
| 1.0.0 | 90 | main（PR #8 merge） | TestFlight |
| 1.0.0 | 91 | fix/iphone-only-device-family | TestFlight |
| 1.0.1 | 92 | perf/keystroke-lag | TestFlight |
| 1.0.1 | 93 | main（PR #9 merge，手動觸發） | TestFlight |
| 1.0.2 | 94 | feat/1.0.2（iPhone-only、字體、mmap 詞庫） | TestFlight |
