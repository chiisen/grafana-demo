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

# 使用環境變數 (由 load_env 提供)
HOST="$GRAFANA_HOST"
TOKEN="$GRAFANA_TOKEN"

# 2. [動態查詢] 找到最新的 tg-contact-points
echo -e "${YELLOW}[i] 查詢最新的 tg-contact-points...${RESET}"
TG_CONTACT_UID=$(curl -s "http://$HOST/api/v1/provisioning/contact-points" \
  -H "Authorization: Bearer ${TOKEN}" \
  | jq -r '[.[] | select(.name == "tg-contact-points")] | last | .uid')

TG_CONTACT_NAME=$(curl -s "http://$HOST/api/v1/provisioning/contact-points" \
  -H "Authorization: Bearer ${TOKEN}" \
  | jq -r '[.[] | select(.name == "tg-contact-points")] | last | .name')

if [ -z "$TG_CONTACT_UID" ] || [ "$TG_CONTACT_UID" == "null" ]; then
    echo -e "${RED}[✗] 錯誤: 找不到 tg-contact-points，請先執行 setup_tg_contact.sh${RESET}"
    exit 1
fi

echo -e "${GREEN}[✓] 找到 tg-contact-points${RESET}"
echo -e "    Name: $TG_CONTACT_NAME"
echo -e "    UID:  $TG_CONTACT_UID"

# 1. [解鎖] 先將 Policy 暫時指向 tg-contact-points，以解鎖任何被佔用的 Email Contact Point
echo -e "${YELLOW}[i] 暫時切換 Policy 以解鎖 Contact Points...${RESET}"
curl -s -X PUT "http://$HOST/api/v1/provisioning/policies" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -H "X-Disable-Provenance: true" \
  -d "{
  \"receiver\": \"$TG_CONTACT_NAME\",
  \"group_by\": [\"grafana_folder\", \"alertname\"],
  \"routes\": []
}" -o /dev/null

# 2. [清理] 刪除所有舊的 Email Contact Points 以及臨時的 Safe Lock
NEW_DEFAULT_NAME="default-email"
SAFE_LOCK_NAME="safe-lock-receiver"

echo -e "${YELLOW}[i] 正在清理舊的 Email Contact Points 及臨時資源...${RESET}"

# 清理所有 default-email, grafana-default-email, safe-lock-receiver
OLD_EMAIL_UIDS=$(curl -s "http://$HOST/api/v1/provisioning/contact-points" \
  -H "Authorization: Bearer ${TOKEN}" \
  | jq -r ".[] | select(.name == \"$NEW_DEFAULT_NAME\" or .name == \"grafana-default-email\" or .name == \"$SAFE_LOCK_NAME\") | .uid")

if [ -n "$OLD_EMAIL_UIDS" ]; then
    for old_uid in $OLD_EMAIL_UIDS; do
        curl -s -X DELETE "http://$HOST/api/v1/provisioning/contact-points/$old_uid" \
          -H "Authorization: Bearer ${TOKEN}" \
          -H "X-Disable-Provenance: true" -o /dev/null || true
    done
    echo -e "${GREEN}[✓] 已清理舊的資源 (含 Safe Lock)${RESET}"
fi

# 3. [建立] 建立一個名稱清楚的預設 Email (default-email)
echo -e "${YELLOW}[i] 建立新的預設 Contact Point ($NEW_DEFAULT_NAME)...${RESET}"

curl -X POST "http://$HOST/api/v1/provisioning/contact-points" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -H "X-Disable-Provenance: true" \
  -d "{
    \"name\": \"$NEW_DEFAULT_NAME\",
    \"type\": \"email\",
    \"settings\": {
      \"addresses\": \"example@email.com\"
    }
  }" -s -o /dev/null

echo -e "${GREEN}[✓] 預設 Contact Point 準備就緒: $NEW_DEFAULT_NAME${RESET}"

# 建立政策 JSON
# 包含根路徑 (預設 $NEW_DEFAULT_NAME) 與針對 Telegram 的子路徑
cat <<EOF > policy_payload.json
{
  "receiver": "$NEW_DEFAULT_NAME",
  "group_by": ["grafana_folder", "alertname"],
  "group_wait": "10s",
  "group_interval": "5m",
  "repeat_interval": "4h",
  "routes": [
    {
      "receiver": "$TG_CONTACT_NAME",
      "object_matchers": [["notify_policy", "=", "fast"]],
      "group_interval": "1m",
      "repeat_interval": "1m",
      "group_wait": "10s"
    },
    {
      "receiver": "$TG_CONTACT_NAME",
      "object_matchers": [["severity", "=", "critical"]],
      "group_interval": "1m",
      "repeat_interval": "4h",
      "group_wait": "10s"
    }
  ]
}
EOF

# 發送請求，關鍵在於加入 X-Disable-Provenance
RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT \
  "http://${HOST}/api/v1/provisioning/policies" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -H "X-Disable-Provenance: true" \
  -d @policy_payload.json)

CODE=$(tail -1 <<< "$RESPONSE")
BODY=$(sed '$d' <<< "$RESPONSE")

if [[ "$CODE" == "200" || "$CODE" == "202" ]]; then
    echo -e "${GREEN}[✓] 政策已更新！(HTTP $CODE)${RESET}"
    echo -e "現在你可以前往 Grafana UI 自由修改這些政策了。"
else
    echo -e "${RED}[✗] 更新失敗！HTTP $CODE${RESET}"
    echo "錯誤詳情: $BODY"
fi

rm policy_payload.json
