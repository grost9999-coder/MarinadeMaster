# iOS 原生 App（本機優先）

## 專案
- Xcode 專案：`ios/MarinadeMaster.xcodeproj`
- Scheme／Target：`MarinadeMaster`
- Bundle Identifier（目前專案設定）：`com.grost9999.marinademaster`
- 最低部署版本：iOS 17
- 儲存：SwiftData 本機資料庫；批次照片使用 SwiftData external storage
- 不含登入、雲端 API、Supabase 或跨裝置同步

## 目前已實作
- 首次啟動建立兩筆歷史配方種子資料。
- 配方清單、配方明細、原料新增／刪除、g／kg、基準重量、備註。
- 編輯配方時另存新版本，不覆蓋舊配方。
- 依雞肉重量換算原料用量並建立批次配方快照。
- 批次清單、退冰／醃製／裹粉／完成時間紀錄。
- 從 iPhone 相簿選取照片，或使用 iPhone 相機拍攝，壓縮為 JPEG 後保存在本機；可檢視及刪除。
- 原料庫存新增／編輯／刪除、進貨紀錄與加權平均成本。
- 建立批次時，按原料名稱與 g／kg 單位換算，自動檢查並扣除已建檔原料庫存；庫存不足時阻止建立批次。
- 批次保存原料成本快照，後續採購價格變動不會回寫既有批次成本。
- JSON 備份與還原涵蓋配方、批次、照片、庫存、進貨及成本快照。

## 在 Mac 開啟
1. 下載或 clone 此 GitHub repository。
2. 使用 Xcode 開啟 `ios/MarinadeMaster.xcodeproj`。
3. 選擇 MarinadeMaster scheme 與 iPhone Simulator。
4. 在 Signing & Capabilities 選擇自己的 Apple Developer Team，確認 Bundle Identifier 可用。
5. Build and Run。

## 尚未完成／尚未驗證
- 本工作環境沒有 Xcode，因此尚未宣稱 iOS 專案已成功編譯或在 iPhone 實機運行。
- macOS GitHub Actions 已成功通過 iOS Simulator 編譯；目前工作流程會將 `.app` 打包為 ZIP artifact（保留 14 天），可供模擬器測試，不可直接安裝到實體 iPhone。
- GitHub Actions 支援手動執行；每次 iOS 目錄變更也會自動編譯。
- 尚未在真實 iPhone 驗證相機權限、照片保存、庫存扣料及備份還原流程。
- 尚未簽署、上傳 TestFlight 或送 App Store 審核。
\n## 正式 IPA 與 TestFlight\n- 已建立 `.github/workflows/ios-release.yml`，需由帳號持有人在 GitHub Actions Secrets 設定 Apple Distribution 憑證、App Store provisioning profile 與 Team ID 後手動執行。\n- 設定說明：`ios/RELEASE_SIGNING.md`。\n- 未使用真實 Apple 憑證執行前，不代表 IPA 已產生或已上傳 TestFlight。\n