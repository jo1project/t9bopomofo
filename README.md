# Jo一個T9注音（iOS）

鍵盤 UI + 選詞引擎皆自研 Swift（無 Rime／librime 依賴）。

詳見 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)。

## 引擎

1. 鍵盤 UI 自研；選詞走純 Swift T9 引擎（`InputEngine` + `DictionaryLoader`）
2. 詞庫底：[libchewing-data](https://github.com/chewing/libchewing-data)（`word.csv` + `tsi.csv`）+ 手工維護的台灣用語（`taiwan_phrases.dict.yaml`）
3. 排序：`T9SortFilter`（覆蓋長度 + 聲調錨點）疊加 `UserLexicon` 使用者自學（詞頻 + bigram，iCloud 備份）

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
brew install xcodegen && xcodegen generate
open T9Bopomofo.xcodeproj
```

## 詞庫

```bash
python3 Scripts/build-chewing-dict.py  # 重新從 libchewing-data 產生 Resources/chewing/chewing_base.dict.yaml
```

## 測試

```bash
python3 Tests/test_engine_ref.py
```
