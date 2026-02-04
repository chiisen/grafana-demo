# 📊 Grafana Demo 專案

歡迎來到 **Grafana Demo**！🚀
這是一個完整的監控解決方案演示專案，整合了 **Grafana**, **Prometheus**, **Loki** 與 **Promtail**。
旨在展示如何快速搭建一個具備指標監控 (Metrics) 與日誌聚合 (Logs) 功能的全方位觀測平台。

---

## 🛠️ 核心組件

本專案由以下強大的開源工具構建而成：

- **📊 Grafana**: 強大的視覺化儀表板與數據分析平台。
- **🔥 Prometheus**: 領先的系統監控與報警工具包，專注於指標收集。
- **🪵 Loki**: 專為日誌設計的聚合系統，受 Prometheus 啟發，輕量且高效。
- **🚚 Promtail**: 日誌收集代理，負責將日誌發送至 Loki。
- **📈 Node Exporter**: 用於導出硬體指標與操作系統狀態。

---

## 🐳 Docker Compose 服務列表

我們使用 `docker-compose.yml` 定義並管理以下服務。為了讓初學者更容易理解，下表詳細說明了各個服務的角色：

| 服務名稱 | 角色與功能說明 | 🔗 端口 |
| :--- | :--- | :--- |
| **grafana** | **👁️ 視覺化總部**<br>這是您唯一需要直接操作的介面。它將枯燥的數據轉化為精美的圖表與儀表板，讓您一目瞭然地掌握系統狀態。 | `3000` |
| **prometheus** | **🔢 指標數據庫 (Metrics)**<br>負責定時「拉取 (Scrape)」並儲存**數值型**的監控數據 (例如：目前的 CPU 使用率是 50%、記憶體剩餘 2GB)。 | `9090` |
| **loki** | **🪵 日誌數據庫 (Logs)**<br>專門儲存應用程式產生的**文字紀錄 (Logs)**。它的設計理念與 Prometheus 相似，但專注於處理大量的日誌文字，適合用來排查具體錯誤訊息。 | `3100` |
| **promtail** | **🚚 日誌快遞員**<br>這是一個背景程式，負責讀取伺服器上的 Log 檔案，打包並傳送給 **Loki** 儲存。它就像是將信件 (Log) 收集起來送到郵局 (Loki) 的郵差。 | - |
| **node_exporter** | **🏥 硬體監控員**<br>負責採集主機的「生理特徵」，如 CPU 負載、記憶體使用量、磁碟空間、網路流量等硬體層面的指標，並提供給 Prometheus 讀取。 | `9100` |

---

## 🚀 快速開始

### 啟動服務
使用以下指令一鍵啟動所有服務：
```bash
docker compose up -d
```

### 停止服務
若需停止並移除容器：
```bash
docker compose down
```

### 檢查狀態
確認所有容器是否正常運行：
```bash
docker compose ps
```

---

## 🔐 登入系統

服務啟動後，請訪問以下地址進入 Grafana 儀表板：

- **📍 URL**: http://localhost:3000
- **👤 預設帳號**: `admin`
- **🔑 預設密碼**: `admin` *(首次登入可能要求更改密碼)*

---
🌟 *Happy Monitoring!*

---

# Grafana 自動化設定指南

本教學文件說明如何利用 **Grafana Admin API** 自動化佈署監控系統。主要針對 Laravel 應用程式的 **ERROR 日誌**，以及伺服器的 **CPU、Disk、Memory (RAM) 高使用率**進行監控。

---

## ⚠️ 重要：架構與執行順序說明

本系統採用 **`.env` 檔案驅動** 設計。`docker-compose` 會自動讀取目錄下的 `.env` 檔案並將變數傳遞給容器。 Ensure the `.env` file exists and contains the necessary variables before starting the services.

### 變數來源
*   **所有環境**：直接讀取 `/.env` 檔案。

---

## 步驟 1: 環境變數準備

### 必要變數清單
請確保您的執行環境中包含以下變數：

| 變數名稱 (Variable) | 說明 | 範例值 |
| :--- | :--- | :--- |
| `GRAFANA_TOKEN` | **[核心]** Grafana Service Account Token | `glsa_...` |
| `TELEGRAM_BOT_TOKEN`| Telegram Bot Token | `12345:ABC...` |
| `TELEGRAM_CHAT_ID` | 接收通知的 Chat ID | `-100...` |

> **注意**：
> - `GRAFANA_TOKEN` 必須是具有 **Editor** 權限的 Service Account Token。
> - `GRAFANA_HOST` 已在 `docker-compose.yml` 中固定為 `grafana:3000`（容器間通訊），無需額外設定。

### 設定方式

請在 `/` 目錄下建立 `.env` 檔案，並填入上述變數。

```bash
# 1. 複製範例檔
cp .env.example .env

# 2. 編輯 .env 並填入正確數值
vim .env
# TELEGRAM_BOT_TOKEN=...
# TELEGRAM_CHAT_ID=...
# GRAFANA_TOKEN=...
```

當執行 `docker compose up -d` 時，Docker 會自動讀取此檔案中的變數。

> **提示**：可使用 `docker compose run --rm setup env | grep GRAFANA` 檢查變數是否已正確傳遞到容器中。

---

## 步驟 2: 產生 Grafana Service Account Token

在執行自動化部署前，您需要先產生 `GRAFANA_TOKEN`。

### 透過 Grafana 網頁操作（推薦）

1. **啟動 Grafana**
   ```bash
   docker compose up -d grafana
   ```

2. **登入 Grafana**
   - 開啟瀏覽器訪問：`http://localhost:3000`
   - 使用預設帳密登入（首次登入會要求修改密碼）

3. **建立 Service Account**
   - 導航至：**Home → Administration → Users and access → Service accounts**
   - 點擊右側的 **「Add service account」** 按鈕
   - 填寫資訊：
     - **Display name**: `Automation Bot`（或任意名稱）
     - **Role**: 選擇 **Editor**
   - 點擊 **「Create」**

4. **產生 Token**
   - 在新建立的 Service Account 頁面中，點擊 **「Add service account token」**
   - 填寫 Token 名稱（例如：`automation-token`）
   - 點擊 **「Generate token」**
   - **⚠️ 重要**：立即複製產生的 Token（格式：`glsa_xxxxx`），此 Token 只會顯示一次！

5. **設定環境變數**
   ```bash
   # 方式 1: 直接設定環境變數
   export GRAFANA_TOKEN="glsa_xxxxx"
   
   # 方式 2: 寫入 .env 檔案
   echo "GRAFANA_TOKEN=glsa_xxxxx" >> .env
   ```

> **💡 安全性優勢**：
> - ✅ Token 可隨時撤銷和重新產生，不影響 Admin 帳號
> - ✅ 避免在腳本中暴露 Admin 密碼
> - ✅ 如果 Token 洩漏，只需在 Grafana UI 中刪除該 Token 即可

---

## 步驟 3: 自動化部署流程

為了確保系統正常運作，請依照以下順序執行腳本（或直接執行 `init_grafana.sh` 一鍵完成）：

### 一鍵自動化 (推薦)
```bash
docker compose up -d
```
Docker Compose 會自動執行 `init_grafana.sh`，依序完成以下所有步驟。

> **提示**：可執行 `docker compose logs setup -f` 即時查看自動化腳本的執行進度與詳細日誌。

---

### 分步手動執行

#### 3.1 建立聯絡點 (Contact Point)
```bash
./setup_tg_contact.sh
```
*   **功能**：建立名為 `tg-contact-points` 的 Telegram 接收器。
*   **自動清理**：執行時會自動刪除所有舊的同名 Contact Points，確保只保留最新版本。

#### 3.2 設定通知政策 (Notification Policy)
```bash
./setup_notification_policy.sh
```
*   **功能**：設定告警路由規則。
    *   **快速通道 (`notify_policy: fast`)**：每 **1 分鐘** 通知一次 (如 CPU 飆高)。
    *   **嚴重告警 (`severity: critical`)**：每 **4 小時** 通知一次。

#### 3.3 部署告警規則 (Alert Rules)
```bash
# 應用程式錯誤監控
./setup_tg_alert.sh

# 伺服器資源監控
./setup_cpu_alert.sh
./setup_ram_alert.sh
./setup_disk_alert.sh
```

---

## 檔案結構說明

```text
/
├── .env.example             # 環境變數範本
├── docker-compose.yml       # Docker Compose 設定檔
├── script/
│   ├── rules/                        # 告警規則定義檔 (JSON)
│   │   ├── rules_cpu_usage.json      # CPU 使用率告警規則
│   │   ├── rules_disk_usage.json     # 硬碟空間告警規則
│   │   ├── rules_ram_usage.json      # 記憶體使用率告警規則
│   │   └── rules_tg_error.json       # 應用程式錯誤日誌告警規則
│   ├── init_grafana.sh               # [主控] 一鍵自動化腳本
│   ├── setup_tg_contact.sh           # [設定] 建立 Telegram 聯絡點
│   ├── setup_notification_policy.sh  # [設定] 設定路由政策
│   ├── setup_tg_alert.sh             # [設定] Telegram 告警規則
│   └── utils.sh                      # 共用工具函式
└── ...
```

## 疑難排解

### 常見問題

**Q: 錯誤: 未找到 GRAFANA_TOKEN**
*   **原因**：執行腳本的環境中沒有該變數。
*   **解決**：
    *   **檢查**：確認 `/.env` 檔案存在且內容正確。
    *   **測試**：在伺服器上執行 `cat /.env` 確認變數值是否如預期。

**Q: 401 Unauthorized 錯誤**
*   **原因**：Token 無效、過期或權限不足。
*   **解決**：請參考「步驟 2: 產生 Grafana Service Account Token」重新產生 Token。
    1. 登入 Grafana UI (`http://localhost:3000`)
    2. 前往 **Administration → Service accounts**
    3. 刪除舊的 Service Account 或建立新的
    4. 產生新 Token 並更新環境變數
    5. 重新執行 `docker compose up -d`

**Q: 通知未送達**
1.  檢查 `setup_notification_policy.sh` 是否執行成功。
2.  確認 Telegram Bot 是否已加入群組且有發言權限。
3.  檢查 `TELEGRAM_BOT_TOKEN` 和 `TELEGRAM_CHAT_ID` 是否正確。

**Q: Grafana UI 中看到多個相同名稱的 Contact Points**
*   **原因**：這是暫時性的，通常發生在腳本執行過程中。
*   **解決**：重新執行 `docker compose restart setup`，自動清理機制會移除所有舊的 Contact Points。

---

## 技術細節

### Contact Points 自動清理機制
為確保系統乾淨且冪等，腳本會在每次執行時：
1.  **查詢**所有同名的舊 Contact Points
2.  **暫時切換** Notification Policy 到預設 Contact Point（解除鎖定）
3.  **刪除**所有舊的 Contact Points
4.  **建立**新的 Contact Point（使用時間戳 UID 避免衝突）
5.  **恢復** Notification Policy 到正確配置

此機制確保：
✅ 每次部署後只保留最新的 Contact Points  
✅ 避免 UID 衝突  
✅ 支援冪等性（可重複執行）

