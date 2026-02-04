# 🎨 Node Exporter Dashboard 冷色調配色方案

## 📋 變更摘要

已成功將 `node-exporter.json` Dashboard 的配色從暖色調改為冷色調。

---

## 🎯 配色方案對比

### 原始配色（暖色調）

| 狀態 | 顏色 | RGBA 值 | 用途 |
|------|------|---------|------|
| ✅ 正常 | 🟢 綠色 | `rgba(50, 172, 45, 0.97)` | CPU、記憶體、磁碟使用率正常 |
| ⚠️ 警告 | 🟠 橙色 | `rgba(237, 129, 40, 0.89)` | 資源使用率達到警告閾值 |
| 🚨 告警 | 🔴 紅色 | `rgba(245, 54, 54, 0.9)` | 資源使用率達到危險閾值 |

### 新配色（冷色調）

| 狀態 | 顏色 | RGBA 值 | 用途 |
|------|------|---------|------|
| ✅ 正常 | 🔵 藍色 | `rgba(45, 140, 230, 0.97)` | CPU、記憶體、磁碟使用率正常 |
| ⚠️ 警告 | 🔷 青色 | `rgba(0, 188, 212, 0.89)` | 資源使用率達到警告閾值 |
| 🚨 告警 | 🟣 紫色 | `rgba(156, 39, 176, 0.9)` | 資源使用率達到危險閾值 |

---

## 🔄 顏色對應表

### 命名顏色

| 原始顏色 | 新顏色 |
|---------|--------|
| `green` | `blue` |
| `dark-yellow` | `cyan` |
| `dark-red` | `purple` |
| `red` | `purple` |
| `yellow` | `cyan` |

### RGBA 顏色

| 原始 RGBA | 新 RGBA | 說明 |
|-----------|---------|------|
| `rgba(50, 172, 45, 0.97)` | `rgba(45, 140, 230, 0.97)` | 正常狀態 - 綠色 → 藍色 |
| `rgba(237, 129, 40, 0.89)` | `rgba(0, 188, 212, 0.89)` | 警告狀態 - 橙色 → 青色 |
| `rgba(245, 54, 54, 0.9)` | `rgba(156, 39, 176, 0.9)` | 告警狀態 - 紅色 → 紫色 |
| `rgba(0, 211, 255, 1)` | `rgba(100, 181, 246, 1)` | 圖示顏色 - 亮藍 → 柔和藍 |

---

## 📊 影響的面板

所有使用閾值顏色的面板都已更新，包括：

### Quick CPU / Mem / Disk 區段
- ✅ Pressure (資源壓力)
- ✅ CPU Busy (CPU 使用率)
- ✅ Sys Load (系統負載)
- ✅ RAM Used (記憶體使用率)
- ✅ SWAP Used (交換空間使用率)
- ✅ Root FS Used (根檔案系統使用率)
- ✅ CPU Cores (CPU 核心數)
- ✅ Reboot Required (是否需要重啟)
- ✅ Uptime (運行時間)

### 其他所有區段
- ✅ CPU 相關圖表
- ✅ Memory 相關圖表
- ✅ Disk 相關圖表
- ✅ Network 相關圖表
- ✅ 所有 Gauge 和 Stat 面板

**總計**：所有使用顏色閾值的面板都已更新為冷色調

---

## 🎨 主題設定

Dashboard 已設定為深色主題（`"style": "dark"`），冷色調在深色背景下視覺效果更佳。

---

## 💾 備份資訊

原始檔案已自動備份至：
```
grafana/provisioning/dashboards/dashboards/node-exporter.json.backup
```

如需還原，執行：
```bash
cp grafana/provisioning/dashboards/dashboards/node-exporter.json.backup \
   grafana/provisioning/dashboards/dashboards/node-exporter.json
```

---

## 🔧 使用的工具

**腳本**：`scripts/change_dashboard_colors.py`

**功能**：
- 遞迴掃描 JSON 結構
- 批量替換所有顏色值
- 自動備份原始檔案
- 驗證 JSON 格式正確性

**使用方式**：
```bash
# 覆蓋原檔案（會自動備份）
python3 scripts/change_dashboard_colors.py node-exporter.json

# 輸出到新檔案
python3 scripts/change_dashboard_colors.py node-exporter.json node-exporter-cool.json
```

---

## 🚀 套用變更

### 方法 1：重啟 Grafana 容器

```bash
docker compose restart grafana
```

### 方法 2：完全重新啟動

```bash
docker compose down
docker compose up -d
```

### 方法 3：手動重新載入（在 Grafana UI 中）

1. 登入 Grafana
2. 進入 Dashboard
3. 點擊右上角的 **⚙️ Dashboard settings**
4. 選擇 **JSON Model**
5. 重新載入頁面

---

## 🎯 視覺效果

### 冷色調的優點

✅ **專業感**：藍色系給人專業、可靠的感覺  
✅ **減少視覺疲勞**：冷色調對眼睛較溫和  
✅ **適合長時間監控**：適合 NOC（網路運營中心）環境  
✅ **清晰的層次感**：藍→青→紫的漸變清晰易辨  
✅ **現代感**：符合現代 UI 設計趨勢  

### 適用場景

- 🏢 企業監控中心
- 💻 開發團隊 Dashboard
- 🌙 夜間值班監控
- 📊 數據分析展示
- 🎯 專業演示場合

---

## 🔄 其他配色方案

如果您想嘗試其他配色，可以修改 `scripts/change_dashboard_colors.py` 中的 `COOL_COLOR_SCHEME` 字典。

### 範例：更柔和的冷色調

```python
COOL_COLOR_SCHEME = {
    "rgba(50, 172, 45, 0.97)": "rgba(100, 181, 246, 0.97)",   # 淺藍
    "rgba(237, 129, 40, 0.89)": "rgba(77, 208, 225, 0.89)",   # 淺青
    "rgba(245, 54, 54, 0.9)": "rgba(186, 104, 200, 0.9)",     # 淺紫
}
```

### 範例：高對比冷色調

```python
COOL_COLOR_SCHEME = {
    "rgba(50, 172, 45, 0.97)": "rgba(33, 150, 243, 0.97)",    # 鮮藍
    "rgba(237, 129, 40, 0.89)": "rgba(0, 229, 255, 0.89)",    # 鮮青
    "rgba(245, 54, 54, 0.9)": "rgba(170, 0, 255, 0.9)",       # 鮮紫
}
```

---

## ✅ 驗證清單

- [x] JSON 格式正確
- [x] 所有顏色已替換
- [x] 原始檔案已備份
- [x] 主題設定為深色模式
- [ ] 在 Grafana UI 中測試顯示效果（需重啟服務）

---

## 📞 需要協助？

如果您想：
- 調整特定顏色
- 嘗試其他配色方案
- 還原原始配色
- 為其他 Dashboard 套用相同配色

請隨時告知！

---

## 🎨 配色設計理念

**冷色調配色遵循以下原則**：

1. **色相漸變**：藍（240°）→ 青（180°）→ 紫（280°）
2. **飽和度一致**：保持相近的飽和度，確保視覺和諧
3. **亮度遞減**：正常→警告→告警，亮度逐漸降低
4. **對比度適中**：在深色背景下清晰可辨，但不刺眼

這樣的設計確保了：
- 視覺層次清晰
- 狀態易於區分
- 長時間觀看不疲勞
- 符合專業監控場景需求
