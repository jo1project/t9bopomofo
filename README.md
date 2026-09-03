# Jo一個T9注音（iOS）

鍵盤 UI 自研；**智慧選詞應對齊 Hamster／Rime**，不是逐字調權重。

詳見 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)。

## 為什麼之前像「遇到一個字改一個字」

Hamster 的聰明來自 **librime** + 你的 schema／`rime.lua`（`t9_sort_filter`）／`essay`／`.gram`。  
本專案一開始用的是簡化 Swift T9，所以只能靠加詞補洞。現在已接上 **librime + octagram**：

1. 鍵盤 UI 自研；選詞走 librime（[fulanto/LibrimeKit](https://github.com/fulanto/LibrimeKit) 2.9.0，含 lua／octagram）
2. 方案／詞庫／`rime.lua` + `zh-hant-t-essay-bgw.gram` 上下文重排
3. Rime 啟動失敗時仍回退到 Swift T9

## 行為（產品規則）

| 項目 | 說明 |
|------|------|
| 佈局 | `zhuyin_phone` |
| 符號／空格／換行 | 只插入並清空，不送第一候選 |
| 。鍵 | 彈出常用標點列（原地左右滑選） |
| 臨近鍵容錯 | 預設開；單次贊助後可關 |
| LLM | 單次贊助解鎖（產品 ID `com.jo1project.t9bopomofo.sponsor`） |
| 模式 | 注音 ↔ EN ↔ 符號 ↔ Emoji |

## 簽名

`DEVELOPMENT_TEAM = S24Z424MU4`（Automatic）。在 Xcode 登入同一個 Apple ID 後即可真機安裝。

本機 StoreKit 測試用 `T9Bopomofo/App/Configuration.storekit`。上架前請在 App Store Connect 建立同 ID 的 **Non-Consumable** 商品。

## IPA

GitHub Actions 可打 unsigned IPA；正式簽名請用 Xcode Archive。

```bash
# 本機
./Scripts/download-models.sh      # essay + gram
./Scripts/download-frameworks.sh  # librime xcframeworks
brew install xcodegen && xcodegen generate
open T9Bopomofo.xcodeproj
```

## 測試

```bash
python3 Tests/test_engine_ref.py
```
