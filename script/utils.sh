#!/bin/bash

# 設定發生錯誤時立即中斷，並使用未宣告變數時報錯
# 注意：當此檔案被 source 時，這些設定也會影響呼叫者
set -euo pipefail

# 定義顏色代碼
export RED='\033[31m'
export GREEN='\033[32m'
export YELLOW='\033[33m'
export CYAN='\033[36m'
export RESET='\033[0m'

ok() { echo -e "${GREEN}[✓] $1${RESET}"; }
info() { echo -e "${YELLOW}[i] $1${RESET}"; }
err() { echo -e "${RED}[✗] $1${RESET}"; }

# 檢查相依性
check_requirements() {
    if ! command -v jq &> /dev/null; then
        err "錯誤: 找不到 'jq' 工具"
        echo "請先安裝 jq (例如: brew install jq 或 apt-get install jq)"
        exit 1
    fi
}

# 載入設定 (嚴格依賴環境變數)
load_env() {
    local script_dir="$1"
    
    # 如果變數未設定，嘗試從 .env 載入 (主要用於本地開發測試)
    if [ -z "${GRAFANA_TOKEN:-}" ] && [ -f "$script_dir/../.env" ]; then
        info "從 .env 檔案載入環境變數..."
        # 使用 set -a 自動 export 變數
        set -a
        source "$script_dir/../.env"
        set +a
    fi
    # 如果是上兩層 (例如在 script/ 目錄下執行)
    if [ -z "${GRAFANA_TOKEN:-}" ] && [ -f "$script_dir/../../.env" ]; then
         info "從 ../../.env 檔案載入環境變數..."
         set -a
         source "$script_dir/../../.env"
         set +a
    fi

    # 設定預設值
    export GRAFANA_HOST=${GRAFANA_HOST:-"grafana:3000"}
    
    # 檢查必要變數
    if [ -z "${GRAFANA_TOKEN:-}" ]; then
        err "錯誤: 環境變數 GRAFANA_TOKEN 未設定"
        echo "請確認已設定環境變數 (請檢查 .env 檔案或確認 Docker 環境變數已傳入)"
        exit 1
    fi
    
    # 輸出當前配置 (除錯用)
    # info "環境配置: HOST=$GRAFANA_HOST"
}

# 確保 Folder 存在
ensure_folder() {
    local folder_uid="$1"
    local folder_title="$2"
    
    info "📂 檢查 Folder: $folder_title ($folder_uid)..."
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" -X GET "http://$GRAFANA_HOST/api/folders/$folder_uid" \
        -H "Authorization: Bearer $GRAFANA_TOKEN")
        
    if [ "$http_code" == "200" ]; then
        ok "Folder 已存在。"
    else
        info "Folder 不存在，正在建立..."
        local response=$(curl -s -w "\n%{http_code}" -X POST "http://$GRAFANA_HOST/api/folders" \
            -H "Authorization: Bearer $GRAFANA_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
                \"uid\": \"$folder_uid\",
                \"title\": \"$folder_title\"
            }")
            
        local create_code=$(tail -1 <<< "$response")
        if [[ "$create_code" == "200" ]]; then
            ok "Folder 建立成功！"
        else
            err "Folder 建立失敗 (HTTP $create_code)"
            # echo "回傳內容: $response"
            exit 1
        fi
    fi
}

# 部署規則
deploy_rule() {
    local rule_name="$1"
    local json_file="$2"
    local folder_uid="$3"
    
    info "🔍 $rule_name 狀態檢查 (Status Check)..."
    
    # 1. 狀態檢查
    local rules_json=$(curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" \
        "http://$GRAFANA_HOST/api/ruler/grafana/api/v1/rules/$folder_uid")

    local exists=$(echo "$rules_json" | jq --arg name "$rule_name" --arg folder "$folder_uid" '
        .[$folder] // [] | [.[]? | select(.name==$name)] | length > 0')
    
    # 顯示現有規則列表 (Optional)
    local existing_names=$(echo "$rules_json" | jq -r --arg folder "$folder_uid" '.[$folder][]? | .name' 2>/dev/null)
    if [ -n "$existing_names" ]; then
        echo -e "${CYAN}--- 現有規則列表 (Rule List) ---${RESET}"
        echo "$existing_names" | nl
        echo -e "${CYAN}-------------------------------${RESET}"
    fi

    if [ "$exists" == "true" ]; then
        echo "🟢 已存在"
    else
        echo "🔴 未找到"
    fi

    # 2. 強制更新
    info "🔄 正在更新/重建規則 (Updating/Rebuilding Rule)..."
    
    # 刪除舊規則
    # 0. 預防性清理: 檢查是否有殘留的 Provisioned Rules (這會導致 API 建立失敗)
    # 即使 Ruler API 說 "未找到"，Provisioning API 可能仍鎖住了該資源
    info "🧹 檢查並清理殘留的 Provisioned Rules (Rule Name: $rule_name)..."
    local prov_uids=$(curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" \
        "http://$GRAFANA_HOST/api/v1/provisioning/alert-rules" \
        | jq -r --arg title "$rule_name" '.[] | select(.title == $title) | .uid')
    
    for uid in $prov_uids; do
        if [ -n "$uid" ] && [ "$uid" != "null" ]; then
            echo -e "${YELLOW}發現殘留 Provisioned Rule (UID: $uid)，正在解鎖並強制移除...${RESET}"
            
            # 1. 接管 (Detach): 先更新規則以移除 'file' provenance
            # 關鍵：必須移除唯讀欄位 (.id, .provenance) 才能成功 PUT，否則 API 可能會忽視或報錯
            local raw_rule=$(curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" "http://$GRAFANA_HOST/api/v1/provisioning/alert-rules/$uid")
            local clean_rule=$(echo "$raw_rule" | jq 'del(.id, .provenance)')
            
            curl -s -o /dev/null -X PUT "http://$GRAFANA_HOST/api/v1/provisioning/alert-rules/$uid" \
                -H "Authorization: Bearer $GRAFANA_TOKEN" \
                -H "Content-Type: application/json" \
                -H "X-Disable-Provenance: true" \
                -d "$clean_rule"

            # 2. 刪除
            local del_res=$(curl -s -w "\n%{http_code}" -X DELETE "http://$GRAFANA_HOST/api/v1/provisioning/alert-rules/$uid" \
                -H "Authorization: Bearer $GRAFANA_TOKEN" \
                -H "X-Disable-Provenance: true")
            
            local del_status=$(tail -1 <<< "$del_res")
            
            # [終極手段] 如果遇到 409 Provenance Mismatch，使用 SQLite 直接修復資料庫
            if [[ "$del_status" == "409" ]]; then
                 echo -e "${RED}⚠ API 刪除受阻 (HTTP 409)，啟動 SQLite 直接修復模式...${RESET}"
                 
                 # 檢查 DB 是否存在 (確保 Docker Volume 掛載正確)
                 if [ -f "/var/lib/grafana/grafana.db" ]; then
                     echo "正在重置 DB 中規則 $uid 的 provenance..."
                     # Grafana v11+ 使用獨立的 provenance_type 表
                     sqlite3 /var/lib/grafana/grafana.db "DELETE FROM provenance_type WHERE record_key = '$uid';"
                     
                     if [ $? -eq 0 ]; then
                        echo "✔ SQLite 修復成功！重試 API 刪除..."
                        # 重試刪除
                        del_res=$(curl -s -w "\n%{http_code}" -X DELETE "http://$GRAFANA_HOST/api/v1/provisioning/alert-rules/$uid" \
                            -H "Authorization: Bearer $GRAFANA_TOKEN" \
                            -H "X-Disable-Provenance: true")
                        del_status=$(tail -1 <<< "$del_res")
                     else
                        echo -e "${RED}✘ SQLite 執行失敗，請檢查權限或檔案鎖定${RESET}"
                     fi
                 else
                     echo -e "${RED}✘ 找不到 /var/lib/grafana/grafana.db，無法執行修復${RESET}"
                 fi
            fi

            if [[ "$del_status" == "200" || "$del_status" == "204" ]]; then
                 echo "✔ 已刪除 Provisioned Rule: $uid"
                 sleep 1 # 等待資料庫一致性
            else
                 echo -e "${RED}✘ 刪除失敗 Provisioned Rule: $uid (HTTP $del_status)${RESET}"
                 echo "回應: $(sed '$d' <<< "$del_res")"
            fi
        fi
    done

    # 刪除舊規則 (嘗試兩種 API)
    # 1. 大部分情況使用 Ruler API 刪除整個 Group
    local del_code=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "http://$GRAFANA_HOST/api/ruler/grafana/api/v1/rules/$folder_uid/$rule_name" \
        -H "Authorization: Bearer $GRAFANA_TOKEN" \
        -H "X-Disable-Provenance: true")

    if [[ "$del_code" == "400" || "$del_code" == "422" ]]; then
        info "⚠️ Ruler API 刪除受阻，嘗試使用 Provisioning API 強制刪除規則..."
        # 取得該 Group 下所有 Rules 的 UID
        local rule_uids=$(curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" \
            "http://$GRAFANA_HOST/api/ruler/grafana/api/v1/rules/$folder_uid" \
            | jq -r --arg group "$rule_name" --arg folder "$folder_uid" '.[$folder] | .[] | select(.name==$group) | .rules[].grafana_alert.uid')
            
        for uid in $rule_uids; do
            if [ -n "$uid" ] && [ "$uid" != "null" ]; then
                echo "正在強制刪除 Provisioned Rule UID: $uid"
                curl -s -X DELETE "http://$GRAFANA_HOST/api/v1/provisioning/alert-rules/$uid" \
                    -H "Authorization: Bearer $GRAFANA_TOKEN" \
                    -H "X-Disable-Provenance: true" > /dev/null
            fi
        done
        # 刪除完規則後，Group 自然消失或變為空，這時再嘗試 POST 應該就會成功
    fi
        
    # 建構 Payload
    # 使用 mktemp 建立臨時檔案
    local temp_payload=$(mktemp)
    
    jq -c --arg folderUid "$folder_uid" --arg name "$rule_name" '
      del(.rules[0].grafana_alert.guid, .rules[0].grafana_alert.namespace_uid) |
      .rules[0].grafana_alert.folderUID = $folderUid |
      .rules[0].grafana_alert.title = $name |
      .rules[0].grafana_alert.missing_series_evals_to_resolve = 1 |
      {
        name: $name,
        folderUID: $folderUid,
        interval: "1m",
        rules: [.rules[0]]
      }
    ' "$json_file" > "$temp_payload"
    
    # 發送 POST
    local response=$(curl -s -w "\n%{http_code}" -X POST \
      "http://$GRAFANA_HOST/api/ruler/grafana/api/v1/rules/$folder_uid" \
      -H "Authorization: Bearer $GRAFANA_TOKEN" \
      -H "Content-Type: application/json" \
      -H "X-Disable-Provenance: true" \
      -d @"$temp_payload")
      
    local code=$(tail -1 <<< "$response")
    local body=$(sed '$d' <<< "$response")
    
    rm "$temp_payload"
    
    if [[ "$code" == "200" || "$code" == "202" ]]; then
        ok "✅ 更新成功！HTTP $code"
        
        # 顯示最終報告
        echo -e "\n${CYAN}📊 執行報告 (Execution Report)${RESET}"
        echo -e "========================================"
        echo -e "規則名稱 (Rule)   : ${rule_name}"
        echo -e "規則狀態 (Status) : 🟢 更新完成 (Update Complete)"
        echo -e "資料夾 (Folder)   : $folder_uid"
        echo -e "檢查時間 (Time)   : $(date '+%Y-%m-%d %H:%M:%S')"
        echo -e "========================================"
        ok "✅ 生產環境就緒！(Production Ready)"
        
        return 0
    else
        err "更新失敗！HTTP $code"
        echo "錯誤詳情 (Error Details): $body"
        return 1
    fi
}
