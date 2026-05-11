---
description: 冒煙測試 — 登入 CyberDesk 並驗證進入關卡選單
---

# CyberDesk 登入冒煙測試

使用 chrome MCP 執行以下步驟，每一步完成後才進行下一步。若任一步失敗，立即回報失敗原因與截圖。

## 步驟

1. 呼叫 `mcp__claude-in-chrome__tabs_context_mcp`（`createIfEmpty: true`）取得 tab。
2. 用 `mcp__claude-in-chrome__navigate` 開啟 `https://game.itsmygo.uk`。
3. 等待 3 秒讓 Godot 載入（`mcp__claude-in-chrome__computer` action `wait`, duration 3）。
4. 截圖（`screenshot`），確認出現「User」登入畫面與密碼輸入框。若未出現，再等 3 秒後重試一次；仍未出現則 FAIL。
5. 點擊密碼輸入框中央（參考截圖實際座標，約 `(765, 360)`；若畫面縮放不同需從截圖重新判斷中心座標）。
6. `type` 文字 `217313`。
7. `key` 按下 `Return`。
8. 等待 2 秒後再次截圖。
9. **斷言**：截圖中必須出現「開發者模式 — 選擇關卡」字樣與第 1~15 關列表。
   - PASS：輸出 ✅ 並附上最終截圖。
   - FAIL：輸出 ❌、失敗步驟、當時截圖、可能原因。

## 注意

- 整個流程只讀、不改檔、不 commit。
- Godot 以 canvas 渲染，DOM 無可互動元素，必須用 `computer` 座標點擊。
- 若 `tabs_context_mcp` 回報多擴充套件衝突，提示使用者在目標瀏覽器點 Connect 後重試。
