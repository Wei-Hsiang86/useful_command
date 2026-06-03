#!/bin/bash
# install_mde.sh — Microsoft Defender for Endpoint 安裝腳本
# 使用方式：sudo bash install_mde.sh
# 前提：MicrosoftDefenderATPOnboardingLinuxServer.py 需與此腳本放在同一目錄

set -euo pipefail

EXPECTED_ORG_ID="e6f24d70-f75f-4ebb-a9a9-7b51f59e0ece"
LOG_DIR="/opt/edr/logs"
INSTALL_LOG="/opt/edr/install_$(date '+%Y%m%d_%H%M%S').log"
ONBOARDING_SCRIPT="$(dirname "$0")/MicrosoftDefenderATPOnboardingLinuxServer.py"

# ── 前置檢查 ──────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo "[錯誤] 請用 sudo 執行此腳本"
    exit 1
fi

if [ ! -f "$ONBOARDING_SCRIPT" ]; then
    echo "[錯誤] 找不到上線套件：$ONBOARDING_SCRIPT"
    echo "請確認 MicrosoftDefenderATPOnboardingLinuxServer.py 與此腳本在同一目錄"
    exit 1
fi

# ── 建立 /opt/edr 並啟動 log 記錄 ────────────────────
mkdir -p "$LOG_DIR"
exec > >(tee "$INSTALL_LOG") 2>&1

echo "=============================="
echo " MDE 安裝腳本"
echo " 開始時間：$(date '+%Y-%m-%d %H:%M:%S')"
echo " 安裝 Log：$INSTALL_LOG"
echo "=============================="

# ── 1. 安裝依賴套件 ───────────────────────────────────
echo "[1/7] 安裝依賴套件..."
apt-get install -y curl libplist-utils apt-transport-https

# ── 2. 設定 Microsoft 套件來源 ────────────────────────
echo "[2/7] 設定 Microsoft 套件來源..."
curl -o /tmp/microsoft.list https://packages.microsoft.com/config/ubuntu/24.04/prod.list
mv /tmp/microsoft.list /etc/apt/sources.list.d/microsoft-prod.list

# ── 3. 安裝 GPG 金鑰 ──────────────────────────────────
echo "[3/7] 安裝 Microsoft GPG 金鑰..."
curl -sSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | tee /usr/share/keyrings/microsoft-prod.gpg > /dev/null
chmod o+r /usr/share/keyrings/microsoft-prod.gpg

# ── 4. 安裝 mdatp ─────────────────────────────────────
echo "[4/7] 更新套件清單並安裝 mdatp..."
apt-get update -qq
apt-get install -y mdatp

# ── 5. 執行上線 ───────────────────────────────────────
echo "[5/7] 執行組織上線..."
python3 "$ONBOARDING_SCRIPT"

# ── 6. 啟用即時保護 ───────────────────────────────────
echo "[6/7] 啟用即時保護..."
mdatp config real-time-protection --value enabled

# ── 7. 建立 Log 資料夾與排程 ──────────────────────────
echo "[7/7] 建立 Log 資料夾與排程..."


# 先移除舊的 MDE 排程，再寫入新的（避免重複）
crontab -l 2>/dev/null | grep -v 'mdatp' > /tmp/existing_cron || true
cat >> /tmp/existing_cron << CRON

# MDE 排程 ─ 由 install_mde.sh 寫入於 $(date '+%Y-%m-%d')
CRON_TZ=Asia/Taipei
# 每天 01:00 更新病毒碼
00 01 * * * echo "===== \$(date '+\%Y-\%m-\%d \%H:\%M:\%S') ===== Start Update" >> ${LOG_DIR}/mdatp_update.log && /usr/bin/mdatp definitions update >> ${LOG_DIR}/mdatp_update.log 2>&1 && echo "===== \$(date '+\%Y-\%m-\%d \%H:\%M:\%S') ===== Finish Update" >> ${LOG_DIR}/mdatp_update.log
# 每天 02:00 快速掃描
00 02 * * * echo "===== \$(date '+\%Y-\%m-\%d \%H:\%M:\%S') ===== Start Quick Scan" >> ${LOG_DIR}/mdatp_quickscan.log && /usr/bin/mdatp scan quick 2>&1 | grep -A 2 "Scan has finished" >> ${LOG_DIR}/mdatp_quickscan.log && echo "===== \$(date '+\%Y-\%m-\%d \%H:\%M:\%S') ===== Finish Scan" >> ${LOG_DIR}/mdatp_quickscan.log
# 每月 15 日前的週日 06:00 升級 mdatp
00 06 * * sun [ \$(date +\%d) -le 15 ] && echo "===== \$(date '+\%Y-\%m-\%d \%H:\%M:\%S') ===== Start Upgrade" >> ${LOG_DIR}/mdatp_cron_job.log && /usr/bin/apt-get update -qq && /usr/bin/apt-get install --only-upgrade -y mdatp >> ${LOG_DIR}/mdatp_cron_job.log 2>&1 && echo "Version: \$(/usr/bin/mdatp version)" >> ${LOG_DIR}/mdatp_cron_job.log
CRON
crontab /tmp/existing_cron
rm /tmp/existing_cron

# ── 健康確認 ──────────────────────────────────────────
echo ""
echo "=============================="
echo " 安裝後健康確認"
echo "=============================="

echo "等待 mdatp 服務啟動..."
sleep 10
ACTUAL_ORG_ID=$(mdatp health --field org_id | tr -d '"')
echo "mdatp org_id：$ACTUAL_ORG_ID"
if [ "$ACTUAL_ORG_ID" = "$EXPECTED_ORG_ID" ]; then
    echo "[ OK ] org_id 驗證通過"
else
    echo "[FAIL] org_id 不符合！請確認上線套件是否正確"
fi

echo "mdatp healthy：$(mdatp health --field healthy)"
echo "mdatp RTP：$(mdatp health --field real_time_protection_enabled)"
echo "mdatp connectivity：$(mdatp connectivity test)"

echo ""
echo "[ OK ] 安裝完成：$(date '+%Y-%m-%d %H:%M:%S')"
echo "安裝 Log 已儲存至：$INSTALL_LOG"
echo "排程 Log 位置：$LOG_DIR"