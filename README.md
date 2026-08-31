# T9 注音（iOS）

獨立的 iOS T9 注音鍵盤（內部 IPA 測試）。佈局復刻 Hamster `zhuyin_phone`，引擎為 Swift 實作的 T9／模糊／本機學習；Rime schema／詞庫一併打包，方便之後接 librime。

## v0.1 行為

| 項目 | 說明 |
|------|------|
| 佈局 | `zhuyin_phone`：左聲調、中 T9、右 ⌫／123／。／換行 |
| 組字 | 一鍵多碼；聲調可省略 |
| 符號／空格／換行 | **只插入該字元並清空組字，不送出第一候選** |
| 模糊 | 鄰鍵錯誤、漏打一碼 |
| 詞庫 | `bopomofo_t9.dict` + `taiwan_phrases`（含拉亞等） |
| 學習 | App Group 本機 bigram／詞頻 |
| 模式 | 注音 ↔ EN ↔ 符號 ↔ Emoji |

## 在 Mac 上建置（IPA）

1. 安裝 [XcodeGen](https://github.com/yonaskolb/XcodeGen)  
2. （可選）下載語法模型與 essay：

```bash
./Scripts/download-models.sh
```

3. 產生 Xcode 專案並打開：

```bash
brew install xcodegen   # 若尚未安裝
xcodegen generate
open T9Bopomofo.xcodeproj
```

4. 在 Xcode 設定你的 **Team** / Bundle ID，真機或模擬器跑 `T9Bopomofo`  
5. 依 App 內說明：**設定 → 鍵盤 → 加入「T9 注音」→ 允許完整取用**  
6. Product → Archive → Distribute → **Ad Hoc / Development IPA** 供內部測試

## 資源

- `Resources/layouts/zhuyin_phone.yaml` — 鍵位來源  
- `Resources/rime/*.schema.yaml` / `*.dict.yaml` — Rime 方案與詞庫  
- `Scripts/download-models.sh` — `zh-hant-t-essay-bgw.gram`、`essay.txt`

## 測試（Linux／CI 可跑）

```bash
python3 Tests/test_engine_ref.py
```

## 之後（非 v0.1）

- 接入 [LibrimeKit](https://github.com/imfuxiao/LibrimeKit) xcframework，用完整 Rime + octagram  
- 更完整 callout UI、漏／多打距離 2、萬象 user_predict Lua  
- TestFlight 對外
