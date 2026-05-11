#!/bin/bash
# 部署腳本：Godot Web Export + 壓縮 wasm + commit + push 到 Cloudflare Pages
# 使用方式：bash deploy.sh "commit 訊息"（訊息可省略，預設為「更新 web build」）

set -e

cd "$(dirname "$0")"

GODOT="C:/Users/User/work/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64.exe"
PROJECT="C:/Users/User/work/work2026/aigame"

# 備份自訂 HTML（Godot export 會覆蓋）
cp build/web/index.html build/web/index.html.custom 2>/dev/null || true

# 自動 Godot Web Export
if [ -f "$GODOT" ]; then
    echo "🔧 執行 Godot Web Export..."
    "$GODOT" --headless --export-release "Web" --path "$PROJECT" 2>&1 || {
        echo "警告：Godot headless export 失敗，檢查是否已有現成 build..."
    }
else
    echo "警告：找不到 Godot 執行檔，跳過自動 export"
fi

# 還原自訂 HTML（Windows 風格載入畫面）
if [ -f build/web/index.html.custom ]; then
    # 從新 export 的 HTML 取得最新的 GODOT_CONFIG（含正確的 fileSizes）
    NEW_CONFIG=$(grep -o 'const GODOT_CONFIG = {.*};' build/web/index.html)
    cp build/web/index.html.custom build/web/index.html
    if [ -n "$NEW_CONFIG" ]; then
        # 用新的 config 替換自訂 HTML 中的舊 config
        python3 -c "
import re, sys
html = open('build/web/index.html','r',encoding='utf-8').read()
new_cfg = '''$NEW_CONFIG'''
html = re.sub(r'const GODOT_CONFIG = \{.*?\};', new_cfg, html)
open('build/web/index.html','w',encoding='utf-8').write(html)
" 2>/dev/null || echo "警告：無法更新 GODOT_CONFIG，使用舊值"
    fi
    rm build/web/index.html.custom
    echo "✅ 已還原自訂載入畫面"
fi

# 檢查 build/web/index.wasm 是否存在
if [ ! -f build/web/index.wasm ]; then
    echo "錯誤：找不到 build/web/index.wasm，Godot Export 可能失敗"
    exit 1
fi

# 檢查是否為原始 wasm（非 gzip 壓縮）
MAGIC=$(xxd -l 2 -p build/web/index.wasm)
if [ "$MAGIC" = "0061" ]; then
    echo "壓縮 index.wasm..."
    gzip -f build/web/index.wasm
    mv build/web/index.wasm.gz build/web/index.wasm
    echo "壓縮完成 ($(du -h build/web/index.wasm | cut -f1))"
elif [ "$MAGIC" = "1f8b" ]; then
    echo "index.wasm 已是 gzip 格式，跳過壓縮"
else
    echo "警告：index.wasm 格式不明 (magic: $MAGIC)，嘗試壓縮..."
    gzip -f build/web/index.wasm
    mv build/web/index.wasm.gz build/web/index.wasm
fi

# Git commit & push
git add build/web/
git status --short build/web/

MSG=${1:-"更新 web build"}

git commit -m "$MSG"
git push origin master

echo ""
echo "部署完成！Cloudflare Pages 將在約 30-40 秒內自動更新："
echo "  https://game.itsmygo.uk"
echo "  https://aigame-8jz.pages.dev"
