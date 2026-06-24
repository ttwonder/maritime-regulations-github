// GitHub Pages 前端使用的 Supabase 公開設定。
// 注意：anonKey 是公開前端 key，不是 service_role secret；不要把 service_role key 放到 GitHub。
// 建立 Supabase 專案並執行 supabase/schema.sql 後，將下列值替換為你的專案資訊。
window.MARITIME_SUPABASE_CONFIG = {
  url: "YOUR_SUPABASE_PROJECT_URL", // 例：https://xxxxxxxxxxxx.supabase.co
  anonKey: "YOUR_SUPABASE_ANON_PUBLIC_KEY"
};
