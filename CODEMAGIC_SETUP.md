# Codemagic App Store Connect Integration 設定

## 檔案位置

**App Store Connect API Key (.p8):**
```
/root/t9bopomofo/AuthKey_Y3YHPMVG9N.p8
```

## Integration 設定資訊

在 Codemagic 建立 App Store Connect integration 時填入：

| 欄位 | 值 |
|------|-----|
| Integration name | `JoT9ASC` |
| Issuer ID | `83c9555b-b62a-4b86-872c-a64a7c3ceadb` |
| Key ID | `Y3YHPMVG9N` |
| API Key | 上傳 `AuthKey_Y3YHPMVG9N.p8` 或貼上內容 |

## Code Signing 設定

| 欄位 | 值 |
|------|-----|
| Distribution method | `App Store` |
| Bundle identifiers | `com.jo1project.t9bopomofo`<br>`com.jo1project.t9bopomofo.keyboard` |

## 設定步驟

1. 訪問 https://codemagic.io 用 GitHub 登入
2. 進入 `Team settings` → `Integrations` → `App Store Connect`
3. 點擊 `Add integration`
4. 填入上述資訊
5. 上傳 `.p8` 檔案或複製貼上內容
6. 設定 Bundle IDs 和 Code Signing
7. 儲存

## 觸發建置

**自動：** 已推送 commit 到 main，Codemagic 應自動建置

**手動：** 在 Codemagic → jo1project/t9bopomofo → Start new build
- Workflow: `iOS TestFlight (signed)`
- Branch: `main`

## 建置完成後

✅ 自動上傳到 App Store Connect TestFlight  
✅ 在 iPhone TestFlight App 安裝測試  
✅ 系統設定開啟鍵盤 + 允許完整取用  
✅ 測試音效和震動功能
