# Supabase 雲端環境設定

MarinadeMaster 已準備第一版 Supabase 資料庫結構，尚未連接任何實際雲端專案。

## 建立專案

1. 到 https://supabase.com/dashboard 建立一個新 Project。
2. 選擇離使用者主要使用地區較近的區域，設定資料庫密碼並妥善保存。
3. 開啟 Project Settings → API，取得 Project URL 與 Publishable key（舊版介面可能顯示 anon public key）。
4. **不要把 service_role key 放進瀏覽器、GitHub 前端程式或 iPhone App。**它具有繞過 RLS 的高權限。

## 建立資料表與權限

1. 開啟 Supabase → SQL Editor。
2. 貼上並執行本專案的 `supabase/schema.sql`。
3. 確認 recipes、ingredients、purchases、batches、inventory_ledger、batch_photos、workspace_snapshots 均已建立 RLS。
4. 確認 Storage 中存在私有 bucket `marinade-batch-photos`。
5. 在 Authentication → Providers 確認 Email 登入已啟用。

## 第一版資料設計

- 每筆資料以 `owner_id = auth.uid()` 隔離不同帳號。
- 原始配方、批次配方快照、採購紀錄、庫存異動分表保存。
- 照片使用私有 Storage bucket，資料表只保存物件路徑與描述。
- `workspace_snapshots` 提供整份工作區 JSON 備份與 revision 樂觀鎖，避免兩台裝置互相覆蓋。
- 所有使用者資料表均啟用 Row Level Security。

## 尚待完成

- 將 Project URL 與 Publishable／anon key 填入前端設定。
- 完成 Email 註冊、登入、登出與登入狀態恢復。
- 實作本機資料上傳、雲端下載、衝突處理及照片物件儲存。
- 完成雙裝置同步測試與資料復原測試。

目前請勿把正式營運資料視為已雲端備份；在同步功能通過測試前，仍請定期匯出 JSON 備份。
