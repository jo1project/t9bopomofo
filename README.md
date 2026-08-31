# T9 注音（iOS）

獨立的 iOS T9 注音鍵盤（內部 IPA 測試）。佈局復刻 Hamster `zhuyin_phone`，引擎為 Swift 實作的 T9／模糊／本機學習；Rime schema／詞庫一併打包，方便之後接 librime。

## v0.1 行為

| 項目 | 說明 |
|------|------|
| 佈局 | `zhuyin_phone`：左聲調、中 T9、右 ⌫／123／。／換行 |
| 組字 | 一鍵多碼；聲調可省略 |
| 符號／空格／換行 | **只插入該字元並清空組字，不會送出第一候選** |
| 模糊 | 鄰鍵錯誤、漏打一碼 |
| 詞庫 | `bopomofo_t9.dict` + `taiwan_phrases`（含拉亞等） |
| 學習 | App Group 本機 bigram／詞頻 |
| 模式 | 注音 ↔ EN ↔ 符號 ↔ Emoji |

## 自動打包 IPA（GitHub Actions）

Workflow：`.github/workflows/build-ipa.yml`（常見 unsigned IPA 流程：`xcodebuild` + `CODE_SIGNING_ALLOWED=NO` + Payload zip）。

1. 推送到 `main`／本功能分支，或到 Actions 手動 **Run workflow**
2. 等 job **Build Unsigned IPA** 完成
3. 下載 artifact **`T9Bopomofo-unsigned-ipa`**
4. 用 **Sideloadly / AltStore / TrollStore** 等工具重簽後裝到裝置（未簽章 IPA 無法直接安裝）

之後若要簽章 IPA，把 Apple 憑證與 profile 設成 repo secrets，再改用 `yukiarrr/ios-build-action`。

## 本機建置（Mac）

```bash
./Scripts/download-models.sh   # 可選
brew install xcodegen
xcodegen generate
open T9Bopomofo.xcodeproj
```

設 Team → 啟用鍵盤並開「允許完整取用」→ Archive。

## 資源

- `Resources/layouts/zhuyin_phone.yaml` — 鍵位來源
- `Resources/rime/*.schema.yaml` / `*.dict.yaml` — Rime 方案與詞庫
- `Scripts/download-models.sh` — `zh-hant-t-essay-bgw.gram`、`essay.txt`

## 測試

```bash
python3 Tests/test_engine_ref.py
```
