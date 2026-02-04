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

# 1. 檢查與初始化
check_requirements
load_env "$SCRIPT_DIR"

echo -e "${YELLOW}=== 開始 Grafana 自動化初始化流程 ===${RESET}"

# 檢查與等待 Grafana 啟動
HOST="$GRAFANA_HOST"
echo -e "${YELLOW}等待 Grafana 啟動... (HOST: $HOST)${RESET}"

# 簡單的等待迴圈
max_retries=30
count=0
until curl -s "http://$HOST/api/health" > /dev/null; do
    count=$((count+1))
    if [ $count -ge $max_retries ]; then
        echo -e "${RED}[✗] 等待 Grafana 超時 ($max_retries 秒)${RESET}"
        exit 1
    fi
    printf "."
    sleep 2
done
echo -e "\n${GREEN}[✓] Grafana 已啟動${RESET}"

# 輔助函式：執行腳本並檢查結果
run_script() {
    local script_name="$1"
    echo -e "\n${YELLOW}>>> 正在執行: $script_name${RESET}"
    
    if [ -f "$SCRIPT_DIR/$script_name" ]; then
        # 這裡不需再用 bash 呼叫，直接執行並確保繼承當前 shell 的屬性 (如環境變數)
        # 但為了保險起見，使用 bash 執行是 OK 的，只要確保環境變數有 export
        bash "$SCRIPT_DIR/$script_name"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ $script_name 執行成功${RESET}"
        else
            echo -e "${RED}✗ $script_name 執行失敗${RESET}"
            exit 1
        fi
    else
        echo -e "${RED}錯誤: 找不到腳本 $script_name${RESET}"
        exit 1
    fi
}

# 步驟 3: 建立聯絡點 (Contact Point)
# 參考 README.md -> ## 步驟 3: 建立聯絡點 (Contact Point)
echo -e "${YELLOW}[1/4] 建立自動化聯絡點 (參考步驟 3)${RESET}"
run_script "setup_tg_contact.sh"

# 步驟 4: 設定通知政策 (Notification Policy)
# 參考 README.md -> ## 步驟 4: 設定通知政策 (Notification Policy)
# *注意：此步驟必須在建立聯絡點後執行*
echo -e "${YELLOW}[2/4] 設定通知路由政策 (參考步驟 4)${RESET}"
run_script "setup_notification_policy.sh"

# 步驟 5: 部署告警規則 (Alert Rules)
# 參考 README.md -> ## 步驟 5: 部署告警規則 (Alert Rules)
echo -e "${YELLOW}[3/4] 部署應用程式錯誤監控 (參考步驟 5.1)${RESET}"
run_script "setup_tg_alert.sh"

echo -e "${YELLOW}[4/4] 部署伺服器資源監控 (參考步驟 5.2)${RESET}"
run_script "setup_cpu_alert.sh"
run_script "setup_ram_alert.sh"
run_script "setup_disk_alert.sh"

echo -e "\n${GREEN}=== 所有自動化設定執行完畢 ===${RESET}"
