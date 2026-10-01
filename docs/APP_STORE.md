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
九個鍵就能打注音！長句一次選到、候選字一鍵展開、長按原地滑動選注音與標點。完全免費，不收集任何資料，還能接上你自己的 AI 聯想。
```

## 關鍵字（≤100，逗號分隔不加空格）

```
注音,九宮格,T9,輸入法,鍵盤,ㄅㄆㄇ,繁體中文,台灣,單手,中文輸入,打字,選字,聲調,AI聯想,長輩
```

不放 ChatGPT、Gemini 等商標名稱（審核準則 2.3.7）；App 名稱裡已有的字也不用重複。

## 描述（≤4000）

```
Jo一個T9注音：把注音放進九個鍵，單手也能快速打中文。

懷念傳統手機的九宮格打字嗎？Jo一個T9注音把 37 個注音符號分配到九宮格上，不用精準點到小小的按鍵，按大格子就能打字，特別適合單手操作、手指比較粗，或是家中長輩使用。

【主要特色】

● 長句一次打到位
連續輸入多個字的注音，鍵盤會自動斷詞組句。例如打「ㄒㄧㄤˇ ㄧ ㄒㄧㄚˋ」，就能直接選到「想一下」。聲調鍵讓選字更精準。

● 候選字一鍵展開
點 ▼ 展開完整候選清單，多字詞也會完整顯示，不會被截斷。

● 長按原地左右滑
長按注音鍵，手指在原地左右滑，就能指定要打的那一個注音；長按「。」選標點，長按聲調鍵換聲調。

● 打錯也找得到
「臨近鍵容錯」會把按到旁邊的鍵、少按一個鍵的情況一起列入候選（可在設定中關閉）。

● 越用越懂你
常選的字詞會自動排到前面，並根據上一個詞建議下一個詞。學習紀錄只存在你的裝置上，可匯出備份或用 iCloud 同步。

● 可接自己的 AI 聯想（選用）
支援 OpenAI 相容 API，填入你自己的 API Key，選字後就會出現 AI 建議的下一句。預設關閉，資料直接從你的手機送到你選的服務。

● 英文、數字、符號、表情符號
空格鍵長按切換英文鍵盤，123 鍵切換數字符號，長按 123 打表情符號。

【完全免費・重視隱私】
沒有廣告、沒有內購、沒有帳號。開發者不收集任何資料，你打的字不會傳給我們。

【啟用方式】
1. 打開「設定 → 一般 → 鍵盤 → 鍵盤」
2. 新增鍵盤，選擇「Jo一個T9注音」
3. 點進該鍵盤，開啟「允許完整取用」（用於共用學習紀錄；選用的 AI 聯想與 iCloud 備份也需要）
4. 在任何 App 中切換到此鍵盤開始使用

詞庫採用 libchewing（新酷音）開源詞庫。
```

## 這個版本的新功能（What's New）

```
・首次正式上架，完全免費
・長句辨識更準確，連續輸入也能選到完整詞組
・打字更順，修正偶發的卡頓
・展開候選清單時，多字詞完整顯示
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
4. `04-llm` — 免費使用，可接自己的 AI 聯想
5. `05-setup` — 三步驟啟用，不收集任何個人資料

重新產生：`python Scripts/render_asc_screenshots.py`（需 Windows 的微軟正黑體；鍵盤外觀照 Swift 程式碼的尺寸與顏色畫，候選字由 `Tests/test_engine_ref.py` 的參考引擎算出）。6.9 吋截圖 App Store 會自動縮放給其他尺寸的 iPhone 使用。

## 送審前檢查

- [ ] **地球鍵（審核準則 4.4.1）：** 鍵盤目前沒有處理 `needsInputModeSwitchKey`。有 Home 鍵的 iPhone（SE 2/3）系統不會顯示地球鍵，鍵盤必須自己提供切換鍵盤的方法，否則很可能被退件。
- [ ] 分支 merge 進 main 後，隱私權政策網址才會生效（網址指向 main）。
- [ ] 版本號目前是 0.3.9（寫在 `.github/workflows/testflight.yml`）；要用 1.0.0 上架需改 workflow 與 `project.yml`。
