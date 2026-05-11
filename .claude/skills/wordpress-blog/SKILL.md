---
name: wordpress-blog
description: |
  WordPress 技術部落格發文管理工具。透過 REST API 執行文章 CRUD、媒體上傳、分類/標籤管理、留言處理。
  使用時機：(1) 發布/更新/刪除/查詢 WordPress 文章 (2) 上傳圖片作為封面或內文圖 (3) 管理分類與標籤（自動建立不存在的）(4) 讀取/回覆/審核留言 (5) 任何與 WordPress 部落格內容管理相關的任務。
  適用：技術部落格、程式教學網站、個人 WordPress 站點。
---

# WordPress 技術部落格管理

透過 Python 腳本操作 WordPress REST API，完整支援文章、媒體、分類、標籤、留言管理。

## 執行方式

所有腳本必須在 scripts 目錄下，透過 `uv run python` 執行，並事先設定環境變數。

**不要用 `python` 或 `python3` 直接執行**，必須用 `uv run python`，否則會缺少 `requests` 等依賴。

### CLI 執行

環境變數由 `.env` 檔自動載入（位於 `.claude/skills/wordpress-blog/.env`），無需手動 export。

```bash
cd .claude/skills/wordpress-blog/scripts && \
uv run python <腳本名稱> <參數>
```

### Python API 呼叫

```bash
cd .claude/skills/wordpress-blog/scripts && \
uv run python -c "
from wp_publish import publish_from_markdown
result = publish_from_markdown('./article.md', categories=['Git'])
print(result)
"
```

## 快速開始

### 從 Markdown 檔案發布（推薦）

支援直接從 Markdown 檔案發布，自動轉換格式：

```python
from wp_publish import publish_from_markdown

result = publish_from_markdown(
    file_path="./git-tutorial.md",
    categories=["Git", "教學"],
    tags=["git", "版本控制"],
    excerpt="Git 入門教學"
)

if result["success"]:
    print(f"發布成功: {result['post']['link']}")
```

命令列使用：

```bash
uv run python wp_publish.py publish-markdown ./article.md --categories "Git,教學" --tags "git,入門"
```

支援 YAML front matter（可選）：

```markdown
---
title: Git 入門教學
categories: [Git, 教學]
tags: [git, 版本控制, 入門]
excerpt: 學習 Git 版本控制基礎概念
---

# Git 入門教學

文章內容...
```

### 發布文章（HTML 格式）

使用 `wp_publish.py` 一次完成分類/標籤解析、封面圖上傳、文章發布：

```python
from wp_publish import publish_tech_post

result = publish_tech_post(
    title="Python async/await 完全指南",
    content="<h2>非同步程式設計</h2><p>本文介紹...</p>",
    categories=["Python", "進階教學"],  # 不存在自動建立
    tags=["asyncio", "coroutine"],
    featured_image="https://example.com/cover.jpg",
    excerpt="學習 Python 3 非同步程式設計"
)

if result["success"]:
    print(f"發布成功: {result['post']['link']}")
```

### 查詢文章

```python
from wp_posts import list_posts, get_post, list_titles

# 列表（支援分頁、搜尋）
posts, pagination = list_posts(search="Python", per_page=10)

# 單篇
post = get_post(123)

# 列出所有標題（用於檢查重複）
titles = list_titles(search="git")
for item in titles:
    print(f"[{item['id']}] {item['title']}")
```

命令列搜尋：

```bash
# 搜尋關鍵字
uv run python wp_posts.py search git

# 搜尋並指定分頁
uv run python wp_posts.py list --search "Python" --page 1 --per-page 20

# 列出所有標題（避免重複發文）
uv run python wp_posts.py titles           # 列出全部
uv run python wp_posts.py titles git       # 搜尋 git 相關標題
```

### 上傳圖片

```python
from wp_media import upload_image, upload_image_from_url

# 本地檔案
media = upload_image("./screenshot.png", alt_text="程式碼截圖")

# 網路圖片
media = upload_image_from_url("https://example.com/img.jpg")

# 使用 media['id'] 作為文章 featured_media
```

### 標籤

標籤不存在時自動建立：

```python
from wp_taxonomy import resolve_tags

# 批次（回傳 ID 列表）
tag_ids = resolve_tags(["container", "devops", "k8s"])
```

### 多階層分類（Hierarchical Categories）

支援使用路徑格式建立父子階層分類，使用 `/` 分隔各層級：

```python
from wp_taxonomy import get_or_create_category_path, resolve_categories

# 建立或取得階層分類 "程式語言 > Python > 進階"
# 系統會自動：
#   1. 查找或建立「程式語言」
#   2. 在「程式語言」下查找或建立「Python」
#   3. 在「Python」下查找或建立「進階」
cat = get_or_create_category_path("程式語言/Python/進階")

# 也支援單層（向後相容）
cat = get_or_create_category_path("Docker")

# 批次處理：混合單層與多層分類
category_ids = resolve_categories([
    "L1-起步/開發工具/容器化/Docker",  # 四層
    "程式語言/Python/進階"      # 三層
])
```

命令列使用：

```bash
# 列出所有分類（階層路徑格式，推薦）
uv run python wp_taxonomy.py categories-tree

# 列出所有分類（含 parent 資訊）
uv run python wp_taxonomy.py categories

# 建立多階層分類
uv run python wp_taxonomy.py get-or-create-category-path '程式語言/Python/進階'

# 批次解析（混合單層與多層）
uv run python wp_taxonomy.py resolve-categories 'Docker' '程式語言/Python'
```

#### 查詢分類階層路徑

```python
from wp_taxonomy import list_categories_tree, get_category_path

# 列出所有分類的完整路徑
cats = list_categories_tree()
for cat in cats:
    print(f"[{cat['id']}] {cat['path']}")
# 輸出：
# [41] L1-起步
# [59] L1-起步/AI工具
# [60] L1-起步/AI工具/AI助手

# 取得單一分類的路徑
path = get_category_path(category_id=60)
print(path)  # "L1-起步/AI工具/AI助手"
```

#### 在發布文章時使用多階層分類

```python
from wp_publish import publish_from_markdown

result = publish_from_markdown(
    file_path="./python-async.md",
    categories=["程式語言/Python/進階", "教學/中階"],  # 多階層分類
    tags=["asyncio", "coroutine"]
)
```

**注意事項**：

- 分類路徑使用 `/` 分隔，例如 `"父分類/子分類/孫分類"`
- 路徑中的每一層都會自動查找或建立
- 回傳的是最深層分類的資料（包含 ID）
- 若同名分類在不同父分類下，系統會正確區分

### 留言管理

```python
from wp_comments import list_comments, reply_comment, approve_comment

# 待審核留言
comments, _ = list_comments(status="hold")

# 回覆（預設公開）
reply_comment(post_id=123, parent_comment_id=456, content="謝謝提問！")

# 審核
approve_comment(789)
```

## 腳本說明

| 腳本             | 用途                             |
| ---------------- | -------------------------------- |
| `wp_config.py`   | 設定與認證（自動從環境變數讀取） |
| `wp_posts.py`    | 文章 CRUD、列表查詢              |
| `wp_media.py`    | 圖片上傳（本地/URL）、媒體管理   |
| `wp_taxonomy.py` | 分類/標籤查詢、建立、智慧解析    |
| `wp_comments.py` | 留言讀取、審核、回覆             |
| `wp_publish.py`  | 整合發文（推薦用於完整發文流程） |

詳細 API 參數見 [references/api_reference.md](references/api_reference.md)。

## 技術部落格工作流程

1. **準備內容**：撰寫 Markdown 或 HTML 格式文章內容
2. **準備封面圖**：本地路徑或網路 URL（可選）
3. **決定分類/標籤**：使用名稱即可，系統自動處理 ID
4. **發布**：呼叫 `publish_from_markdown()` 或 `publish_tech_post()`
5. **管理留言**：定期檢查並回覆讀者問題

## Markdown 支援功能

內建 Markdown 轉 HTML 支援以下格式：

- 標題（# ~ ######）
- 粗體（**text**）、斜體（_text_）
- 無序列表（- item）、有序列表（1. item）
- 程式碼區塊（```language）、行內程式碼（`code`）
- 引用（> text）
- 表格
- 連結（[text](url)）、圖片（![alt](url)）
- 分隔線（---）

### `read_quiz_file()` 的處理

此函數會自動：

1. **移除 HTML 結構**：`<!DOCTYPE>`, `<html>`, `<head>`, `<body>` 標籤
2. **Scope CSS 樣式**：將全域選擇器（`*`, `body`, `h1`）移除，並為 class 選擇器加上容器前綴
3. **用容器包裹**：用 `<div id="container_id">` 包裹內容，確保樣式只作用於該區塊
4. **避免衝突**：多個測驗可以安全地嵌入同一頁面

## 注意事項

- 推薦使用 Markdown 格式撰寫，系統自動轉換為 HTML
- 封面圖（featured_media）需先上傳取得 Media ID，或使用 `publish_*` 函數自動處理
- 分類/標籤使用名稱即可，`wp_taxonomy` 自動處理查詢或建立
- 留言回覆預設直接公開（status=approved）
- **嵌入外部 HTML**：使用 `read_quiz_file()` 處理，避免樣式污染整個頁面
