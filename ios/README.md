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
- 從 iPhone 相簿選取照片，壓縮為 JPEG 後保存在本機；可檢視及刪除。

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
- 原生相機即時拍攝、完整資料／照片備份匯出還原、庫存採購成本模組仍待開發。
- 尚未簽署、上傳 TestFlight 或送 App Store 審核。
