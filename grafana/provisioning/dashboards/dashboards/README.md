# Grafana Dashboards 配置說明

本目錄包含所有 Grafana Dashboard 的 JSON 配置檔案，這些檔案會在 Grafana 啟動時自動載入（透過 Provisioning 機制）。

## 📁 檔案清單

| 檔案名稱 | 大小 | 用途 | 數據來源 |
|---------|------|------|---------|
| `drilldown-combined-logs.json` | 10 KB | 整合日誌鑽取分析 | Loki |
| `api-log.json` | 5.5 KB | API 日誌監控 | Loki |
| `laravel-log.json` | 5.4 KB | Laravel 應用日誌 | Loki |
| `load-testing.json` | 7.7 KB | 負載測試監控 | Prometheus |
| `node-exporter.json` | 706 KB | 系統資源監控 | Prometheus |
| `cadvisor-exporter.json` | 19 KB | 容器資源監控 | Prometheus |
| `grafana-metrics.json` | 31 KB | Grafana 自身指標 | Prometheus |
| `loki-metrics.json` | 99 KB | Loki 服務指標 | Prometheus |
| `prometheus-stats.json` | 54 KB | Prometheus 統計資訊 | Prometheus |

---

## 📊 Dashboard 詳細說明

### 1. `drilldown-combined-logs.json`

**用途**：整合多個應用程式的日誌，提供互動式鑽取分析功能

#### 主要面板

##### Panel 1: Log Volume by Job and Level
- **類型**：時間序列圖 (Time Series)
- **視覺化**：堆疊長條圖 (Stacked Bar Chart)
- **查詢**：
  ```logql
  sum by (job, level) (count_over_time({job=~"${job:regex}", level=~"${level:regex}"}[1m]))
  ```
- **功能**：
  - 顯示每分鐘的日誌數量
  - 按 Job (應用程式) 和 Level (日誌等級) 分組
  - 支援點擊圖例進行過濾（Drilldown 功能）
  - 圖例顯示總計數 (sum)

##### Panel 2: Combined Logs - API, Laravel & Lifecycle
- **類型**：日誌面板 (Logs Panel)
- **查詢**：
  ```logql
  {job=~"${job:regex}", level=~"${level:regex}"}
  ```
- **功能**：
  - 顯示原始日誌內容
  - 支援無限滾動 (Infinite Scrolling)
  - 顯示日誌詳細資訊
  - 顯示標籤和時間戳
  - 降序排列（最新的在上方）

#### 變數 (Variables)

| 變數名稱 | 標籤 | 類型 | 可選值 | 預設值 | 說明 |
|---------|------|------|--------|--------|------|
| `job` | Job | Custom | `api`, `laravel`, `order-lifecycle` | All | 選擇要查看的應用程式 |
| `level` | Level | Custom | `DEBUG`, `INFO`, `NOTICE`, `WARNING`, `ERROR`, `CRITICAL`, `ALERT`, `EMERGENCY` | All | 選擇日誌等級 |

#### 配置細節

```json
{
  "refresh": "30s",              // 每 30 秒自動刷新
  "time": {
    "from": "now-24h",           // 預設顯示最近 24 小時
    "to": "now"
  },
  "style": "dark",               // 深色主題
  "tags": ["logs", "combined", "drilldown"],  // Dashboard 標籤
  "uid": "drilldown-combined-logs"  // 唯一識別碼
}
```

#### 互動功能

1. **Drilldown 鑽取**：
   - 點擊圖表中的任何系列（Job + Level 組合）
   - 自動更新變數過濾器
   - 下方日誌面板會即時過濾顯示對應的日誌

2. **時間範圍選擇**：
   - 可在圖表上拖曳選擇時間範圍
   - 支援快速時間範圍選擇（Last 5m, 15m, 1h, 6h, 24h 等）

3. **變數過濾**：
   - 使用頂部下拉選單選擇特定 Job 或 Level
   - 支援正則表達式匹配

---

### 2. `node-exporter.json`

**用途**：監控系統層級的資源使用情況（CPU、記憶體、磁碟、網路等）

**來源**：[Grafana Dashboard #1860](https://grafana.com/grafana/dashboards/1860)

#### 主要監控指標

##### Quick CPU / Mem / Disk 區段

| 面板名稱 | 指標 | 查詢範例 | 閾值 |
|---------|------|---------|------|
| **Pressure** | 系統資源壓力 (PSI) | `irate(node_pressure_cpu_waiting_seconds_total[...])` | 70% 警告, 90% 告警 |
| **CPU Busy** | CPU 整體使用率 | `100 * (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[...])))` | 85% 警告, 95% 告警 |
| **Sys Load** | 系統負載 | `node_load1 * 100 / count(node_cpu_seconds_total)` | 85% 警告, 95% 告警 |
| **RAM Used** | 記憶體使用率 | `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100` | 80% 警告, 90% 告警 |
| **SWAP Used** | 交換空間使用率 | `(SwapTotal - SwapFree) / SwapTotal * 100` | 10% 警告, 25% 告警 |
| **Root FS Used** | 根檔案系統使用率 | `(size - avail) / size * 100` | 80% 警告, 90% 告警 |
| **CPU Cores** | CPU 核心數量 | `count(node_cpu_seconds_total by (cpu))` | - |
| **Reboot Required** | 是否需要重啟 | `node_reboot_required` | - |

#### 變數

- `$node`：選擇要監控的節點
- `$job`：Node Exporter 的 Job 名稱

#### 特點

- 16,076 行配置，包含大量詳細的系統監控面板
- 支援多節點監控
- 提供歷史趨勢圖和即時數據
- 包含網路、磁碟 I/O、檔案系統等進階指標

---

### 3. `cadvisor-exporter.json`

**用途**：監控 Docker 容器的資源使用情況

#### 主要監控指標

- 容器 CPU 使用率
- 容器記憶體使用量
- 容器網路流量
- 容器檔案系統使用情況
- 容器啟動/停止狀態

---

### 4. `api-log.json` & `laravel-log.json`

**用途**：分別監控 API 和 Laravel 應用的日誌

#### 功能

- 日誌數量統計
- 日誌等級分布
- 錯誤日誌追蹤
- 日誌內容搜尋

---

### 5. `load-testing.json`

**用途**：負載測試期間的效能監控

#### 監控指標

- 請求速率 (Requests per second)
- 回應時間 (Response time)
- 錯誤率 (Error rate)
- 併發連線數

---

### 6. `grafana-metrics.json`

**用途**：監控 Grafana 自身的運行狀態

#### 監控指標

- Dashboard 載入時間
- 查詢執行時間
- 活躍使用者數
- 資料來源健康狀態

---

### 7. `loki-metrics.json`

**用途**：監控 Loki 日誌聚合服務的效能

#### 監控指標

- 日誌攝取速率 (Ingestion rate)
- 查詢效能
- 儲存使用量
- Compactor 狀態

---

### 8. `prometheus-stats.json`

**用途**：監控 Prometheus 時序資料庫的運行狀態

#### 監控指標

- 時間序列數量 (Time series count)
- 樣本攝取速率 (Sample ingestion rate)
- 查詢延遲
- 儲存使用量
- TSDB 狀態

---

## 🔧 使用方式

### 自動載入

這些 Dashboard 會透過 Grafana Provisioning 機制自動載入：

```yaml
# grafana/provisioning/dashboards/dashboards.yml
apiVersion: 1
providers:
  - name: 'default'
    folder: ''
    type: file
    options:
      path: /etc/grafana/provisioning/dashboards/dashboards
```

### 手動匯入

如果需要手動匯入：

1. 登入 Grafana
2. 點擊左側選單的 **Dashboards** → **Import**
3. 上傳 JSON 檔案或貼上內容
4. 選擇資料來源
5. 點擊 **Import**

### 修改 Dashboard

⚠️ **注意**：透過 Provisioning 載入的 Dashboard 預設為唯讀模式。

如需修改：

1. **方法一**：直接編輯 JSON 檔案，重啟 Grafana
2. **方法二**：在 Grafana UI 中另存為新 Dashboard
3. **方法三**：修改 Provisioning 配置，允許編輯：
   ```yaml
   options:
     path: /etc/grafana/provisioning/dashboards/dashboards
     foldersFromFilesStructure: true
   disableDeletion: false  # 允許刪除
   allowUiUpdates: true    # 允許 UI 更新
   ```

---

## 📝 JSON 結構說明

### 基本結構

```json
{
  "annotations": {},      // 註解設定
  "editable": true,       // 是否可編輯
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,      // 圖表提示模式
  "links": [],            // 外部連結
  "panels": [],           // 面板陣列（主要內容）
  "refresh": "30s",       // 自動刷新間隔
  "schemaVersion": 38,    // Schema 版本
  "style": "dark",        // 主題
  "tags": [],             // 標籤
  "templating": {},       // 變數定義
  "time": {},             // 時間範圍
  "timepicker": {},       // 時間選擇器
  "timezone": "",         // 時區
  "title": "",            // Dashboard 標題
  "uid": "",              // 唯一識別碼
  "version": 0            // 版本號
}
```

### Panel 結構

```json
{
  "datasource": {         // 資料來源
    "type": "loki",
    "uid": "loki"
  },
  "fieldConfig": {},      // 欄位配置
  "gridPos": {            // 面板位置和大小
    "h": 8,               // 高度
    "w": 24,              // 寬度（最大 24）
    "x": 0,               // X 座標
    "y": 0                // Y 座標
  },
  "id": 1,                // 面板 ID
  "options": {},          // 視覺化選項
  "targets": [],          // 查詢目標
  "title": "",            // 面板標題
  "type": "timeseries"    // 面板類型
}
```

### 常見面板類型

- `timeseries`：時間序列圖
- `gauge`：儀表板
- `bargauge`：條形儀表板
- `stat`：統計值
- `logs`：日誌面板
- `table`：表格
- `heatmap`：熱力圖
- `piechart`：圓餅圖

---

## 🎯 最佳實踐

### 1. 命名規範

- 使用小寫字母和連字符：`drilldown-combined-logs.json`
- 名稱應清楚描述用途
- UID 應與檔案名稱一致

### 2. 版本控制

- 所有 Dashboard JSON 檔案都應納入 Git 版本控制
- 修改前先備份
- 使用有意義的 commit 訊息

### 3. 效能優化

- 避免過於複雜的查詢
- 合理設定時間範圍
- 使用變數減少重複查詢
- 適當設定刷新間隔（不要太頻繁）

### 4. 維護建議

- 定期檢查 Dashboard 是否正常運作
- 移除不再使用的 Dashboard
- 保持 Grafana 版本更新
- 記錄重要的配置變更

---

## 🔗 相關資源

- [Grafana Dashboard 官方文檔](https://grafana.com/docs/grafana/latest/dashboards/)
- [Grafana Provisioning 文檔](https://grafana.com/docs/grafana/latest/administration/provisioning/)
- [LogQL 查詢語法](https://grafana.com/docs/loki/latest/logql/)
- [PromQL 查詢語法](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboard 社群](https://grafana.com/grafana/dashboards/)

---

## 📞 支援

如有問題或需要協助，請參考：

1. 專案 README.md
2. Grafana 官方文檔
3. 提交 Issue 到專案 Repository
