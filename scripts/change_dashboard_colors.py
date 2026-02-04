#!/usr/bin/env python3
"""
Grafana Dashboard 配色調整腳本

用途：批量替換 Dashboard JSON 檔案中的顏色配置
支援：將暖色調（綠、橙、紅）改為冷色調（藍、青、紫）
"""

import json
import sys
from pathlib import Path
from typing import Dict, Any

# 冷色調配色方案
COOL_COLOR_SCHEME = {
    # 原始綠色 -> 藍色（正常狀態）
    "rgba(50, 172, 45, 0.97)": "rgba(45, 140, 230, 0.97)",
    
    # 原始橙色 -> 青色（警告狀態）
    "rgba(237, 129, 40, 0.89)": "rgba(0, 188, 212, 0.89)",
    
    # 原始紅色 -> 紫紅色（告警狀態）
    "rgba(245, 54, 54, 0.9)": "rgba(156, 39, 176, 0.9)",
    
    # 其他常見顏色
    "green": "blue",
    "dark-yellow": "cyan",
    "dark-red": "purple",
    "red": "purple",
    "yellow": "cyan",
    
    # 半透明綠色 -> 半透明藍色
    "rgba(0, 211, 255, 1)": "rgba(100, 181, 246, 1)",
}


def replace_colors_in_dict(obj: Any, color_map: Dict[str, str]) -> Any:
    """
    遞迴替換字典中的顏色值
    
    Args:
        obj: 要處理的物件（可能是 dict, list, str 等）
        color_map: 顏色對應表
    
    Returns:
        替換後的物件
    """
    if isinstance(obj, dict):
        return {k: replace_colors_in_dict(v, color_map) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [replace_colors_in_dict(item, color_map) for item in obj]
    elif isinstance(obj, str):
        # 替換顏色字串
        return color_map.get(obj, obj)
    else:
        return obj


def change_dashboard_colors(
    input_file: Path,
    output_file: Path,
    color_scheme: Dict[str, str],
    backup: bool = True
) -> None:
    """
    修改 Dashboard 的配色方案
    
    Args:
        input_file: 輸入的 JSON 檔案路徑
        output_file: 輸出的 JSON 檔案路徑
        color_scheme: 顏色對應表
        backup: 是否備份原始檔案
    """
    print(f"📖 讀取檔案: {input_file}")
    
    # 讀取 JSON 檔案
    with open(input_file, 'r', encoding='utf-8') as f:
        dashboard = json.load(f)
    
    # 備份原始檔案
    if backup and input_file == output_file:
        backup_file = input_file.with_suffix('.json.backup')
        print(f"💾 備份原始檔案: {backup_file}")
        with open(backup_file, 'w', encoding='utf-8') as f:
            json.dump(dashboard, f, ensure_ascii=False, indent=4)
    
    # 替換顏色
    print(f"🎨 套用冷色調配色方案...")
    dashboard_updated = replace_colors_in_dict(dashboard, color_scheme)
    
    # 添加或更新 style 為 dark（冷色調在深色主題下更好看）
    if 'style' not in dashboard_updated:
        dashboard_updated['style'] = 'dark'
        print(f"✨ 設定主題為深色模式")
    
    # 寫入新檔案
    print(f"💾 儲存檔案: {output_file}")
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(dashboard_updated, f, ensure_ascii=False, indent=4)
    
    print(f"✅ 完成！已將配色改為冷色調")
    print(f"\n配色方案：")
    print(f"  🔵 正常狀態: 藍色 (rgba(45, 140, 230, 0.97))")
    print(f"  🔷 警告狀態: 青色 (rgba(0, 188, 212, 0.89))")
    print(f"  🟣 告警狀態: 紫色 (rgba(156, 39, 176, 0.9))")


def main():
    """主程式"""
    if len(sys.argv) < 2:
        print("使用方式:")
        print(f"  python3 {sys.argv[0]} <dashboard.json>")
        print(f"  python3 {sys.argv[0]} <input.json> <output.json>")
        print()
        print("範例:")
        print(f"  python3 {sys.argv[0]} node-exporter.json")
        print(f"  python3 {sys.argv[0]} node-exporter.json node-exporter-cool.json")
        sys.exit(1)
    
    input_file = Path(sys.argv[1])
    
    if not input_file.exists():
        print(f"❌ 錯誤: 檔案不存在: {input_file}")
        sys.exit(1)
    
    # 如果有指定輸出檔案，使用指定的；否則覆蓋原檔案
    output_file = Path(sys.argv[2]) if len(sys.argv) > 2 else input_file
    
    try:
        change_dashboard_colors(
            input_file=input_file,
            output_file=output_file,
            color_scheme=COOL_COLOR_SCHEME,
            backup=True
        )
    except json.JSONDecodeError as e:
        print(f"❌ JSON 格式錯誤: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ 發生錯誤: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
