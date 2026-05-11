# Loop Prompt — CyberDesk 遊戲品質檢查自動化

## 使用方式

在 Claude Code 中執行：
```
/loop 10m
```
然後貼上下方「Loop Prompt」的內容。

或者直接一行：
```
/loop 10m <貼上 Loop Prompt 內容>
```

## 停止方式

Claude 會回傳 Job ID，用 CronDelete 停止：
```
停下 loop
```

---

## Loop Prompt

```
執行兩階段遊戲品質檢查：

## 階段一：UI/UX 審查（godot-level-reviewer 風格）
看 git log 是否有「修正第 X 關 UI/UX」或「審查第 X 關」的 commit，找出第 1-15 關中下一個尚未審查的。

如果還有未審查的關卡，使用 general-purpose agent 審查該關（純程式碼分析，不用 Godot MCP）：
1. 讀 docs/levels.md 了解設計規格
2. 讀該關 handler 檔案，逐行檢查 UI 佈局
3. 讀 desktop.gd 確認用對接口
4. 計算每個元素 position + size，檢查溢出/重疊/邊界問題
5. 修正問題後 bash deploy.sh "修正第 X 關 UI/UX 問題"

## 階段二：遊戲深度審查（godot-game-auditor 風格）
如果全 15 關 UI/UX 都已審查完，看 git log 是否有「審計第 X 關」或「audit 第 X 關」的 commit，找出下一個未審計的關卡。

如果還有未審計的關卡，使用 general-purpose agent 做深度審查：
1. 讀 docs/levels.md 和 docs/puzzle-hints.md
2. 讀該關 handler 完整程式碼
3. Bug 檢測：Lambda 捕獲、signal 連接、queue_free 後存取、state 流程
4. 可玩性驗證：模擬正確答案路徑 → passed:true？模擬錯誤路徑 → passed:false + 有用提示？
5. 計分驗證：首次無錯=100、重試=60、放棄=30
6. 修正問題後 bash deploy.sh "審計第 X 關：修正問題"，無問題則 bash deploy.sh "審計第 X 關：通過"

如果兩階段都全部完成，回報「所有關卡審查與審計已完成」並停止。
```

---

## 相關 Agent 定義檔

| 檔案 | 用途 |
|------|------|
| `.claude/agents/godot-level-reviewer.md` | UI/UX 審查 agent（階段一的參考） |
| `.claude/agents/godot-game-auditor.md` | 深度審計 agent（階段二的參考） |
| `.claude/agents/godot-level-developer.md` | 關卡開發 agent（開發新關卡用） |

## 進度追蹤方式

透過 git log commit message 判斷：
- 階段一完成標記：`修正第 X 關 UI/UX` 或 `審查第 X 關`
- 階段二完成標記：`審計第 X 關` 或 `audit 第 X 關`

## 注意事項

- Loop 是 session-only，關掉 Claude Code 就消失
- 自動過期時間：7 天
- 自訂 agent（`.claude/agents/` 裡的 .md 檔）不能直接用 Agent tool 的 subagent_type 呼叫，只能用 general-purpose agent 並把指引寫在 prompt 裡
- 每輪 loop 會啟動一個背景 agent，完成後結果回到主對話（只有簡短 summary，不會塞爆 context）
