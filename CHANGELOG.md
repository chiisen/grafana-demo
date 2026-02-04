# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **docker-compose.yml**:
    - 啟用了 `cadvisor` 服務以進行容器層級指標監控。
- **.gitignore**:
    - 完善了忽略規則，涵蓋 MacOS 系統檔、IDE 設定、Docker 覆寫檔、日誌以及 Laravel/Vue/Python 開發環境之暫存檔。
- **prometheus/prometheus.yml**:
    - 將設定檔中的英文註解翻譯為繁體中文，並補充各項監控任務的說明。

### Fixed
- **docker-compose.yml**:
    - 修正了 `cadvisor` 服務區塊的 YAML 縮進錯誤。
    - 移除了過時的 `version: '3'` 屬性，消除 Docker Compose 警告。
    - 優化了網路配置，將與專案主題無關的 `observability` 名稱重新命名為 `grafana-net`。
    - 將 `setup` 服務的容器名稱從 `observability-setup` 更改為 `grafana-setup`，使其更契合專案主題。
    - 解決了容器名稱衝突問題 (針對 `node_exporter` 等服務)。
    - **[重構]** 統一服務與容器命名，將 `setup` 服務重命名為 `grafana-setup`。
    - **[優化]** 為所有關鍵服務補齊 `restart: unless-stopped` 策略，提升系統穩定性。
    - **[優化]** 啟用 Grafana 健康檢查，並將 `grafana-setup` 的依賴條件優化為 `service_healthy`。
    - **[優化]** 將 `grafana-setup` 的基礎鏡像固定為 `alpine:3.21`。
- **setup_git_sync.ps1**:
    - 重構腳本邏輯，使用陣列管理遠端列表，提升可維護性。
    - 新增 `git config --unset-all` 機制，確保多次執行不會產生重複設定 (Idempotency)。
    - 加入顏色輸出與狀態檢查，提升使用者體驗。
- **README.md**:
    - 優化了文件整體的語氣與結構，使其更具親和力。
    - 新增了大量襯景的情緒符號 (Emojis) 以提升閱讀體驗。
    - 為 Docker Compose 服務列表中的每個組件加入了生動的角色比喻 (如「視覺化總部」、「日誌快遞員」) 與白話功能說明，幫助初學者快速理解。
