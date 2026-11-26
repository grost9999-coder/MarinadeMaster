# iOS 正式簽署與 TestFlight

目前一般 iOS 工作流程只建立 iOS Simulator `.app`，不能安裝到實體 iPhone。正式 IPA 必須由有效 Apple Developer Program 帳號、Apple Distribution 憑證及 App Store provisioning profile 簽署。

## App 識別資料
- Bundle ID：`com.grost9999.marinademaster`
- Xcode scheme：`MarinadeMaster`
- 最低 iOS：17.0

## GitHub Actions Secrets
由帳號持有人在 Repository → Settings → Secrets and variables → Actions 建立：

| Secret 名稱 | 內容 |
|---|---|
| `IOS_CERTIFICATE_BASE64` | Apple Distribution .p12 憑證的 Base64 |
| `IOS_CERTIFICATE_PASSWORD` | 匯出 .p12 時設定的密碼 |
| `IOS_PROVISIONING_PROFILE_BASE64` | App Store distribution provisioning profile 的 Base64 |
| `IOS_PROVISIONING_PROFILE_NAME` | profile 內的 Name |
| `IOS_TEAM_ID` | Apple Developer Team ID |
| `APP_STORE_CONNECT_API_KEY_BASE64` | App Store Connect API .p8 私鑰 Base64（僅自動上傳時需要） |
| `APP_STORE_CONNECT_API_KEY_ID` | API Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID |

不要把憑證、密碼、私鑰或 provisioning profile 提交到 GitHub 程式碼，也不要貼在聊天中。

## 產生 IPA
1. 建立 App Store distribution provisioning profile，Bundle ID 必須是 `com.grost9999.marinademaster`。
2. 將 Apple Distribution 憑證匯出成有密碼的 .p12。
3. 將 .p12、provisioning profile，以及（若要自動上傳）API .p8 分別 Base64 編碼後放進 GitHub Actions Secrets。
4. 到 Actions → **MarinadeMaster signed iOS release** → Run workflow。
5. `upload_to_testflight=false` 只產生已簽署 IPA；`true` 會在產生 IPA 後呼叫 App Store Connect 上傳。

Base64 範例（在自己的 Mac 終端機執行）：
```sh
base64 -i distribution.p12 | pbcopy
base64 -i profile.mobileprovision | pbcopy
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

請確認 Apple Developer Program 會員有效、App Store Connect 已建立對應 App，且 API Key 有足夠的 App Manager 權限。上傳成功仍需在 App Store Connect 完成 TestFlight 資訊及必要的 Beta App Review。

## 尚未驗證
- 此 workflow 已建立，但尚未使用真實 Apple 憑證執行。
- 未完成真實簽署前，不可把 Simulator ZIP 當成 iPhone IPA。
- 此專案目前採本機資料優先，沒有雲端資料庫金鑰。
