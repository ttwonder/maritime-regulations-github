# 海事法規、規定辨識和執行追蹤系統

這個版本可發布到 **GitHub Pages**，並用 **Supabase Auth + Database** 做雲端資料、權限分配與可查詢修改 LOG。

## 資料夾

請在 GitHub Desktop 加入這個資料夾：

```text
C:\Users\tuotu\Documents\maritime-regulations-github
```

## 主要功能

- GitHub Pages 發布：`.github/workflows/pages.yml`
- 管理中心：登入、權限分配、LOG 查詢
- 角色：`owner` / `admin` / `editor` / `viewer`
- Supabase 未設定時仍可本地顯示與測試

## Supabase 設定

1. 建立 Supabase project。
2. 到 SQL Editor。
3. 執行 `supabase/schema.sql`。
4. 執行前把最後的 `BOOTSTRAP_OWNER_EMAIL` 改成第一位管理員 email。
5. 到 Project Settings → API，複製 Project URL 與 anon public key。
6. 編輯 `supabase-config.js`。

```js
window.MARITIME_SUPABASE_CONFIG = {
  url: "https://你的專案.supabase.co",
  anonKey: "你的 anon public key"
};
```

不要把 Supabase `service_role` key 放到 GitHub。

## GitHub Pages

發布到 GitHub 後，到 repo：

```text
Settings → Pages → Source: GitHub Actions
```
