#!/bin/bash
# uninstall_mde.sh — Microsoft Defender for Endpoint 移除腳本
# 使用方式：sudo bash uninstall_mde.sh

set -euo pipefail

# ── 前置檢查 ──────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo "[錯誤] 請用 sudo 執行此腳本"
    exit 1
fi

echo "=============================="
echo " MDE 移除腳本"
echo " 開始時間：$(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================="

# ── 1. 移除 mdatp ─────────────────────────────────────
echo "[1/5] 移除 mdatp..."
apt-get remove -y mdatp

# ── 2. 移除 Microsoft 套件來源與 GPG 金鑰 ────────────
echo "[2/5] 移除 Microsoft 套件來源與 GPG 金鑰..."
rm -f /etc/apt/sources.list.d/microsoft-prod.list
rm -f /usr/share/keyrings/microsoft-prod.gpg

# ── 3. 移除 logrotate 設定 ────────────────────────────
echo "[3/5] 移除 logrotate 設定..."
rm -f /etc/logrotate.d/mdatp

# ── 4. 移除 crontab 排程 ──────────────────────────────
echo "[4/5] 移除 crontab 排程..."
crontab -l 2>/dev/null | grep -v 'mdatp' | crontab - || true

# ── 5. 移除 /opt/edr ──────────────────────────────────
echo "[5/5] 移除 /opt/edr..."
rm -rf /opt/edr

# ── 更新套件清單 ──────────────────────────────────────
apt-get update -qq

echo ""
echo "=============================="
echo "[ OK ] 移除完成：$(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================="
