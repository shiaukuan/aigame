#!/bin/bash
# CI 版部署腳本：在 GitHub Actions Linux 環境跑 Godot Web Export + 壓縮 wasm
# 不負責 git commit / push（由 workflow 處理）
# 使用方式：bash deploy-ci.sh
#
# 依賴：
#   - godot 4.6.2-stable headless（barichello/godot-ci:4.6.2 docker image 已內建）
#   - python3、gzip、od（base image 預設都有）

set -e

cd "$(dirname "$0")"

GODOT="${GODOT:-godot}"

cp build/web/index.html build/web/index.html.custom 2>/dev/null || true

echo "Godot import (產生 .godot/imported cache)..."
$GODOT --headless --import 2>&1 || echo "警告：godot --import 回傳非 0，繼續嘗試 export"

echo "Godot Web Export..."
$GODOT --headless --export-release "Web" "build/web/index.html"

if [ -f build/web/index.html.custom ]; then
    NEW_CONFIG=$(grep -o 'const GODOT_CONFIG = {.*};' build/web/index.html || true)
    cp build/web/index.html.custom build/web/index.html
    if [ -n "$NEW_CONFIG" ]; then
        # 用 env var 把 config 傳進 python，避免 shell interpolation 炸掉
        # 使用 quoted heredoc delimiter 'PY' 讓 python 原始碼不受 shell 影響
        export NEW_CONFIG
        if command -v python3 >/dev/null 2>&1; then
            python3 - <<'PY'
import os, re, sys
new_cfg = os.environ['NEW_CONFIG']
with open('build/web/index.html', 'r', encoding='utf-8') as f:
    html = f.read()
new_html, count = re.subn(r'const GODOT_CONFIG = \{.*?\};', new_cfg, html)
if count == 0:
    print('錯誤：在 index.html 找不到 GODOT_CONFIG，無法替換', file=sys.stderr)
    sys.exit(1)
with open('build/web/index.html', 'w', encoding='utf-8') as f:
    f.write(new_html)
print(f'已更新 GODOT_CONFIG（替換 {count} 處）')
PY
        else
            echo "錯誤：找不到 python3，無法更新 GODOT_CONFIG"
            exit 1
        fi
    else
        echo "警告：無法從新 export 的 index.html 擷取 GODOT_CONFIG"
    fi
    rm build/web/index.html.custom
    echo "已還原自訂載入畫面"
fi

if [ ! -f build/web/index.wasm ]; then
    echo "錯誤：找不到 build/web/index.wasm，Godot Export 失敗"
    exit 1
fi

MAGIC=$(od -An -tx1 -N2 build/web/index.wasm | tr -d ' \n')
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

echo ""
echo "deploy-ci.sh 完成，build/web/ 已準備好讓 workflow 進行 commit & push"
