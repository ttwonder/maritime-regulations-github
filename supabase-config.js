// GitHub Pages 前端使用的 Supabase 公開設定。
// 注意：anonKey 是公開前端 key，不是 service_role secret；不要把 service_role key 放到 GitHub。
// 建立 Supabase 專案並執行 supabase/schema.sql 後，將下列值替換為你的專案資訊。
window.MARITIME_SUPABASE_CONFIG = {
  url: "https://bwkzcykimxsojfmxvcpk.supabase.co", // 例：https://xxxxxxxxxxxx.supabase.co
  anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ3a3pjeWtpbXhzb2pmbXh2Y3BrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIzMTIwNzYsImV4cCI6MjA5Nzg4ODA3Nn0.qpuing5gp2LJo7_8y5XWJmy-oLV2rQH3hLFxiCmK8d4"
};
