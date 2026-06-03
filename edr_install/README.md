# MDE Linux 安裝操作手冊

## 前置準備

到現場前，確認以下幾樣都備齊：

| 項目 | 來源 | 備註 |
|------|------|------|
| `install_mde.sh` | 自行準備 | 本手冊附件 |
| 每台 VM 的 SSH 帳號密碼 | 自行準備 | 建立的 VM 帳號密碼 |
| `MicrosoftDefenderATPOnboardingLinuxServer.py` | 詢問客戶 | 務必提前索取 |
| 確認 log rotate 時間 | 詢問客戶 | |

> ⚠️ `MicrosoftDefenderATPOnboardingLinuxServer.py` 包含公司組織專屬資訊，需由客戶 IT 從 Microsoft Defender 入口網站下載後提供，無法自行下載替代。

---

## 每台 VM 安裝流程

### Step 1：確認目標 VM 的 Linux 版本

```bash
cat /etc/os-release
```

確認為 **Ubuntu 24.04**，再繼續後續步驟。若版本不為 24.04，找到下面指令並且修改 version

```
curl -o /tmp/microsoft.list https://packages.microsoft.com/config/ubuntu/24.04/prod.list
                                                                            ↑
                                                                          改這裡
```

---

### Step 2：將檔案傳送到 VM

在**你的本地端**執行（兩個檔案一次傳送）：

```bash
scp install_mde.sh MicrosoftDefenderATPOnboardingLinuxServer.py <user>@<VM_IP>:/opt/edr/
```

> 若 `/opt/edr/` 不存在，先建立：
> ```bash
> ssh <user>@<VM_IP> "sudo mkdir -p /opt/edr && sudo chown <user>:<user> /opt/edr"
> ```

---

### Step 3：SSH 登入 VM

```bash
ssh <user>@<VM_IP>
```

---

### Step 4：執行安裝腳本

```bash
cd /opt/edr
sudo bash install_mde.sh
```

腳本會自動完成以下項目：
- 安裝依賴套件
- 設定 Microsoft 套件來源與 GPG 金鑰
- 安裝 mdatp
- 執行組織上線
- 啟用即時保護（Real-Time Protection）
- 建立 Log 資料夾（`/opt/edr/logs/`）
- 設定 Log 自動清理（logrotate，目前預設保留 12 週，請與客戶確認後調整）
- 寫入 Crontab 排程：
  - 每天 01:00 病毒碼更新
  - 每天 02:00 快速掃描
  - 每月 15 日前的週日 06:00 版本升級

---

### Step 5：確認安裝結果

腳本執行完畢後，會自動顯示健康確認結果，請逐項確認：

| 項目 | 預期結果 |
|------|---------|
| `org_id` | `e6f24d70-f75f-4ebb-a9a9-7b51f59e0ece` |
| `healthy` | `true` |
| `RTP` | `true` |
| `connectivity` | 顯示連線成功 |

若 `org_id` 不符合，請停止並聯絡客戶 IT 確認上線套件是否正確。

---

### Step 6：測試 Defender 是否正常運作

```bash
curl -o /tmp/eicar.com.txt https://secure.eicar.org/eicar.com.txt
curl -o /tmp/eicar_com.zip https://secure.eicar.org/eicar_com.zip
curl -o /tmp/eicarcom2.zip https://secure.eicar.org/eicarcom2.zip
```

接著確認威脅已被偵測：

```bash
mdatp threat list
```

應看到上述三個測試檔案被列為威脅。

---

### Step 7：登出，換下一台

```bash
exit
```

重複 Step 2–6，直到 10 台全部完成。

---

## Log 位置

```
/opt/edr/logs/
├── mdatp_update.log       ← 每天 01:00 病毒碼更新記錄
├── mdatp_quickscan.log    ← 每天 02:00 快速掃描記錄
└── mdatp_cron_job.log     ← 每月 15 日前週日版本升級記錄
```

---

## Crontab 排程摘要

| 時間 | 工作 |
|------|------|
| 每天 01:00 | 病毒碼更新 |
| 每天 02:00 | 快速掃描 |
| 每月 15 日前的週日 06:00 | mdatp 版本升級 |

---

## 常見問題

**Q：腳本執行到一半失敗怎麼辦？**
腳本設定了 `set -euo pipefail`，任何步驟失敗會立即停止並顯示錯誤訊息，修正問題後重新執行即可。

**Q：重複執行腳本會有問題嗎？**
Crontab 部分有防重複機制，不會產生重複排程。其他步驟（apt install、mdatp 上線）重複執行也是安全的。

**Q：org_id 驗證失敗怎麼辦？**
請聯絡客戶 IT，確認提供的 `MicrosoftDefenderATPOnboardingLinuxServer.py` 是否為正確的版本。
