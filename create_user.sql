-- PostgreSQL

-- 1. 建立新使用者
CREATE USER 使用者名稱 WITH PASSWORD '密碼';

-- 2. 授予連線到資料庫的權限
GRANT CONNECT ON DATABASE 資料庫名稱 TO 使用者名稱;

-- 3. 切換到 <資料庫名稱> 資料庫（在 psql 中執行）
\c 資料庫名稱

-- 4. 授予對 public schema 的使用權限
GRANT USAGE ON SCHEMA public TO 使用者名稱;

-- 5. 授予所有現有資料表的 SELECT 權限
GRANT SELECT ON ALL TABLES IN SCHEMA public TO 使用者名稱;

-- 6. 授予所有現有 sequences 的 SELECT 權限
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO 使用者名稱;

-- 7. 設定預設權限，讓未來新建的資料表也自動有讀取權限
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
GRANT SELECT ON TABLES TO 使用者名稱;