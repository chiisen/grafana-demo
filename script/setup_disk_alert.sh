#!/bin/bash

# 設定發生錯誤時立即中斷，並使用未宣告變數時報錯
set -euo pipefail

# 取得腳本所在目錄的絕對路徑
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 載入共用工具函式 (utils.sh)
if [ -f "$SCRIPT_DIR/utils.sh" ]; then
    source "$SCRIPT_DIR/utils.sh"
else
    echo "❌ 錯誤: 找不到工具腳本 $SCRIPT_DIR/utils.sh"
    exit 1
fi

# 1. 檢查具備必要工具
check_requirements

# 載入環境變數
load_env "$SCRIPT_DIR"

# 設定變數
RULE_NAME="disk-usage-alert"
JSON_FILE="$SCRIPT_DIR/rules/rules_disk_usage.json"
FOLDER_UID="tg-alerts"
FOLDER_TITLE="Telegram Alerts"

# 檢查規則檔案是否存在
if [ ! -f "$JSON_FILE" ]; then
    err "錯誤: 找不到規則設定檔 $JSON_FILE"
    exit 1
fi

# 2. 確保 Folder 存在
ensure_folder "$FOLDER_UID" "$FOLDER_TITLE"

# 3. 部署規則
deploy_rule "$RULE_NAME" "$JSON_FILE" "$FOLDER_UID"

ok "✅ Disk Alert Setup Completed"
