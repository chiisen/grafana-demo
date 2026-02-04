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
BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
CHAT_ID="$TELEGRAM_CHAT_ID"

# 確保 Telegram 相關變數已設定
if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo -e "${RED}[✗] 錯誤: 環境變數 TELEGRAM_BOT_TOKEN 或 TELEGRAM_CHAT_ID 未設定${RESET}"
    exit 1
fi

# 使用固定名稱與固定 UID 以確保冪等性 (Idempotency)
CONTACT_NAME="tg-contact-points"
FIXED_UID="tg-contact-points-main"

echo "=== 建立 Telegram Contact Point ==="
echo -e "${YELLOW}[i] 目標 Name: $CONTACT_NAME${RESET}"
echo -e "${YELLOW}[i] 目標 UID:  $FIXED_UID${RESET}"

# 步驟 1: 建立一個臨時的 "Safe Lock" Contact Point 用於解鎖
echo "[1/5] 準備 Safe Lock 機制以避免 409 Conflict..."
SAFE_LOCK_NAME="safe-lock-receiver"
curl -s -X POST "http://$HOST/api/v1/provisioning/contact-points" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -H "X-Disable-Provenance: true" \
  -d "{
    \"name\": \"$SAFE_LOCK_NAME\",
    \"type\": \"email\",
    \"settings\": { \"addresses\": \"lock@localhost\" }
  }" > /dev/null

# 步驟 2: 強制將 Policy 指向 Safe Lock (這會釋放舊的 Contact Point)
echo "[2/5] 切換 Policy 到 Safe Lock..."
curl -s -X PUT "http://$HOST/api/v1/provisioning/policies" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -H "X-Disable-Provenance: true" \
  -d '{
    "receiver": "'"$SAFE_LOCK_NAME"'",
    "group_by": ["grafana_folder", "alertname"],
    "routes": []
  }' > /dev/null

# 步驟 3: 清理舊的 Contact Points (包含重複的)
echo "[3/5] 掃描並清理重複的 Contact Points..."

# 找出所有名稱匹配 $CONTACT_NAME 的 UID，或者 UID 匹配 $FIXED_UID 的
# 邏輯：全部刪除後重建，是最乾淨的解決重複方案
TARGET_UIDS=$(curl -s "http://$HOST/api/v1/provisioning/contact-points" \
  -H "Authorization: Bearer ${TOKEN}" \
  | jq -r ".[] | select(.name == \"$CONTACT_NAME\" or .uid == \"$FIXED_UID\") | .uid")

if [ -n "$TARGET_UIDS" ]; then
    for old_uid in $TARGET_UIDS; do
        echo -e "  正在刪除舊 UID: $old_uid..."
        DELETE_RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
          -X DELETE "http://$HOST/api/v1/provisioning/contact-points/$old_uid" \
          -H "Authorization: Bearer ${TOKEN}" \
          -H "X-Disable-Provenance: true")
        
        if [[ "$DELETE_RESULT" == "200" || "$DELETE_RESULT" == "202" || "$DELETE_RESULT" == "204" ]]; then
            echo -e "${GREEN}  ✔ 已刪除: $old_uid${RESET}"
        elif [[ "$DELETE_RESULT" == "404" ]]; then
             echo "  ⚠ 已經不存在: $old_uid"
        else
            echo -e "${RED}  ⚠ 刪除失敗 $old_uid (HTTP $DELETE_RESULT) - 可能被其他 Route 鎖定或權限不足${RESET}"
        fi
    done
else
    echo "✓ 未發現舊的或重複的 Contact Points"
fi

# 步驟 4: 建立新的 Contact Point
echo "[4/5] 建立或更新 Contact Point (固定 UID)..."
PAYLOAD="{
    \"uid\": \"$FIXED_UID\",
    \"name\": \"$CONTACT_NAME\",
    \"type\": \"telegram\",
    \"settings\": {
      \"bottoken\": \"$BOT_TOKEN\",
      \"chatid\": \"$CHAT_ID\",
      \"disable_notification\": false
    },
    \"disableResolveMessage\": true
}"

# 嘗試建立 (POST)
CREATE_RESULT=$(curl -s -w "\n%{http_code}" -X POST "http://$HOST/api/v1/provisioning/contact-points" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -H "X-Disable-Provenance: true" \
  -d "$PAYLOAD")

HTTP_CODE=$(tail -1 <<< "$CREATE_RESULT")
RESPONSE_BODY=$(sed '$d' <<< "$CREATE_RESULT")

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" || "$HTTP_CODE" == "202" ]]; then
    echo -e "${GREEN}[✓] Contact Point 建立成功 (HTTP $HTTP_CODE)${RESET}"
elif [[ "$HTTP_CODE" == "409" ]]; then
    echo -e "${YELLOW}[!] Contact Point UID 已存在 (HTTP 409)，嘗試更新 (PUT)...${RESET}"
    # 嘗試 UPDATE (PUT)
    UPDATE_RESULT=$(curl -s -w "\n%{http_code}" -X PUT "http://$HOST/api/v1/provisioning/contact-points/$FIXED_UID" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -H "X-Disable-Provenance: true" \
      -d "$PAYLOAD")
    
    UPDATE_CODE=$(tail -1 <<< "$UPDATE_RESULT")
    UPDATE_BODY=$(sed '$d' <<< "$UPDATE_RESULT")
    
    if [[ "$UPDATE_CODE" == "200" || "$UPDATE_CODE" == "202" ]]; then
         echo -e "${GREEN}[✓] Contact Point 更新成功 (HTTP $UPDATE_CODE)${RESET}"
    else
         echo -e "${RED}[✘] Contact Point 更新失敗 (HTTP $UPDATE_CODE)${RESET}"
         echo "錯誤詳情: $UPDATE_BODY"
         exit 1
    fi
else
    echo -e "${RED}[✘] Contact Point 建立失敗 (HTTP $HTTP_CODE)${RESET}"
    echo "錯誤詳情: $RESPONSE_BODY"
    exit 1
fi

# 步驟 5: 驗證
echo "[5/5] 驗證..."
VERIFY_RESULT=$(curl -s "http://$HOST/api/v1/provisioning/contact-points" \
  -H "Authorization: Bearer ${TOKEN}" \
  | jq ".[] | select(.uid == \"$FIXED_UID\") | {name, type, uid}")

if [ -n "$VERIFY_RESULT" ]; then
    echo -e "${GREEN}[✓] 驗證成功:${RESET}"
    echo "$VERIFY_RESULT"
else
    echo -e "${RED}[✘] 驗證失敗: 找不到剛建立的 Contact Point${RESET}"
    exit 1
fi

echo ""
echo "=== Contact Point 設定完成 ==="


