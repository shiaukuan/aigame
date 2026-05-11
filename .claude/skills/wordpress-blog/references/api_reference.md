# WordPress REST API 完整參考

## 執行方式

所有腳本必須透過 `uv run python` 執行。環境變數由 `.env` 檔自動載入（位於 `.claude/skills/wordpress-blog/.env`），無需手動 export。

```bash
cd .claude/skills/wordpress-blog/scripts && \
uv run python <腳本名稱> <參數>
```

**不要用 `python` 或 `python3`**，必須用 `uv run python`。

## 腳本一覽

| 腳本             | 功能                                     |
| ---------------- | ---------------------------------------- |
| `wp_config.py`   | API 設定與 Basic Auth 認證               |
| `wp_posts.py`    | 文章 CRUD（建立/讀取/更新/刪除/列表）    |
| `wp_media.py`    | 媒體上傳（本地/URL）與管理               |
| `wp_taxonomy.py` | 分類/標籤管理（含多階層路徑、批次解析）   |
| `wp_comments.py` | 留言管理（讀取/審核/回覆/刪除）           |
| `wp_publish.py`  | 整合發文（Markdown 轉換、HTML 嵌入、發布）|

---

## wp_config.py — 設定與認證

```python
from wp_config import get_config

config = get_config()           # 從環境變數讀取設定
config.api_url                  # REST API URL: {base_url}/wp-json/wp/v2
config.auth_header              # Basic Auth Header dict
```

### WPConfig 類別

| 屬性/方法       | 說明                               |
| --------------- | ---------------------------------- |
| `base_url`      | WordPress 站點 URL                 |
| `username`      | 使用者名稱                         |
| `app_password`  | Application Password               |
| `api_url`       | Property：回傳 REST API 基底 URL   |
| `auth_header`   | Property：回傳 Basic Auth Header   |
| `from_env()`    | Classmethod：從環境變數建立        |

---

## wp_posts.py — 文章管理

### Python API

```python
from wp_posts import create_post, update_post, delete_post, get_post, list_posts, list_titles
```

#### `create_post(title, content, status="publish", categories=None, tags=None, featured_media=None, excerpt=None) -> dict`

建立新文章。

| 參數             | 類型       | 預設        | 說明                              |
| ---------------- | ---------- | ----------- | --------------------------------- |
| `title`          | str        | **必填**    | 文章標題                          |
| `content`        | str        | **必填**    | 文章內容（HTML）                  |
| `status`         | str        | `"publish"` | 狀態：publish/draft/pending/private |
| `categories`     | list[int]  | None        | 分類 ID 列表                      |
| `tags`           | list[int]  | None        | 標籤 ID 列表                      |
| `featured_media` | int        | None        | 封面圖 Media ID                   |
| `excerpt`        | str        | None        | 文章摘要                          |

#### `update_post(post_id, title=None, content=None, status=None, categories=None, tags=None, featured_media=None, excerpt=None) -> dict`

更新文章，只更新有提供的欄位。

#### `delete_post(post_id, force=False) -> dict`

刪除文章。`force=True` 永久刪除，`force=False` 移到垃圾桶。

#### `get_post(post_id) -> dict`

查詢單篇文章。

#### `list_posts(page=1, per_page=10, search=None, categories=None, tags=None, status=None, order="desc", orderby="date") -> (list, dict)`

查詢文章列表，回傳 `(文章列表, 分頁資訊)`。

| 參數         | 類型       | 預設     | 說明                                     |
| ------------ | ---------- | -------- | ---------------------------------------- |
| `page`       | int        | 1        | 頁碼（從 1 開始）                         |
| `per_page`   | int        | 10       | 每頁筆數（最大 100）                      |
| `search`     | str        | None     | 搜尋關鍵字                               |
| `categories` | list[int]  | None     | 篩選分類 ID                              |
| `tags`       | list[int]  | None     | 篩選標籤 ID                              |
| `status`     | str        | None     | 篩選狀態：publish/draft/pending/private/trash |
| `order`      | str        | `"desc"` | 排序方向：asc/desc                        |
| `orderby`    | str        | `"date"` | 排序欄位：date/id/title/slug/modified     |

分頁資訊格式：`{"total": int, "total_pages": int, "page": int, "per_page": int}`

#### `list_titles(search=None) -> list[dict]`

列出所有文章標題（自動分頁取回全部），用於檢查重複。回傳 `[{"id": int, "title": str}, ...]`。

### CLI

```bash
uv run python wp_posts.py list [--search <關鍵字>] [--page <頁碼>] [--per-page <筆數>]
uv run python wp_posts.py search <關鍵字>
uv run python wp_posts.py titles [關鍵字]
uv run python wp_posts.py get <post_id>
uv run python wp_posts.py create <title> <content>
uv run python wp_posts.py delete <post_id>
```

---

## wp_media.py — 媒體管理

### Python API

```python
from wp_media import upload_image, upload_image_from_url, get_media, list_media, delete_media
```

#### `upload_image(file_path, title=None, alt_text=None, caption=None) -> dict`

上傳本地圖片。自動偵測 MIME 類型，支援 alt_text / caption / title 中繼資料。

#### `upload_image_from_url(image_url, filename=None, title=None, alt_text=None, caption=None) -> dict`

從 URL 下載圖片並上傳。`filename` 預設從 URL 路徑取得。

#### `get_media(media_id) -> dict`

查詢單一媒體。

#### `list_media(page=1, per_page=10, media_type="image", search=None) -> (list, dict)`

查詢媒體列表。`media_type` 可為 image/video/audio/application。

#### `delete_media(media_id, force=True) -> dict`

刪除媒體（媒體必須強制刪除，不支援垃圾桶）。

### CLI

```bash
uv run python wp_media.py upload <file_path> [alt_text]
uv run python wp_media.py upload-url <image_url> [filename]
uv run python wp_media.py list [page] [per_page]
uv run python wp_media.py get <media_id>
uv run python wp_media.py delete <media_id>
```

---

## wp_taxonomy.py — 分類與標籤

### Python API — 分類

```python
from wp_taxonomy import (
    list_categories, get_category, create_category, delete_category,
    find_category_by_name, get_or_create_category,
    get_or_create_category_path, get_category_path, list_categories_tree,
    delete_all_categories, resolve_categories
)
```

#### `list_categories(page=1, per_page=100, search=None, hide_empty=False) -> (list, dict)`

查詢分類列表。

#### `get_category(category_id) -> dict`

查詢單一分類。

#### `create_category(name, slug=None, description=None, parent=None) -> dict`

建立分類。`parent` 為父分類 ID，用於建立階層。

#### `delete_category(category_id) -> dict`

刪除分類。ID=1「未分類」無法刪除。

#### `delete_all_categories() -> dict`

刪除所有分類（除「未分類」），從葉節點開始遞迴刪除。回傳 `{"deleted": int, "failed": int, "errors": list}`。

#### `find_category_by_name(name, parent=None) -> dict | None`

根據名稱查找分類（不區分大小寫）。可指定 `parent` 區分同名分類。

#### `get_or_create_category(name, description=None, parent=None) -> dict`

智慧取得或建立：存在則回傳，不存在則建立。

#### `get_or_create_category_path(path, separator="/") -> dict`

根據階層路徑取得或建立分類，每一層自動查找或建立。

```python
# 建立 程式語言 > Python > 進階
cat = get_or_create_category_path("程式語言/Python/進階")
```

#### `get_category_path(category_id, cats_dict=None) -> str`

取得分類的完整階層路徑字串，如 `"L1-起步/AI工具/AI助手"`。

#### `list_categories_tree() -> list[dict]`

列出所有分類（階層路徑格式，按路徑排序）。回傳 `[{"id", "name", "path", "parent", "count"}, ...]`。

### Python API — 標籤

```python
from wp_taxonomy import (
    list_tags, get_tag, create_tag,
    find_tag_by_name, get_or_create_tag, resolve_tags
)
```

#### `list_tags(page=1, per_page=100, search=None, hide_empty=False) -> (list, dict)`

查詢標籤列表。

#### `get_tag(tag_id) -> dict`

查詢單一標籤。

#### `create_tag(name, slug=None, description=None) -> dict`

建立標籤。

#### `find_tag_by_name(name) -> dict | None`

根據名稱查找標籤（不區分大小寫）。

#### `get_or_create_tag(name, description=None) -> dict`

智慧取得或建立標籤。

### Python API — 批次處理

#### `resolve_categories(names) -> list[int]`

批次將分類名稱/路徑解析為 ID。支援混合單層與多層路徑。

```python
ids = resolve_categories(["Docker", "程式語言/Python/進階"])
```

#### `resolve_tags(names) -> list[int]`

批次將標籤名稱解析為 ID。不存在時自動建立。

```python
ids = resolve_tags(["container", "devops", "k8s"])
```

### CLI

```bash
uv run python wp_taxonomy.py categories                           # 列出所有分類
uv run python wp_taxonomy.py categories-tree                      # 階層路徑格式
uv run python wp_taxonomy.py tags                                 # 列出所有標籤
uv run python wp_taxonomy.py get-or-create-category <name>        # 取得或建立分類
uv run python wp_taxonomy.py get-or-create-category-path <path>   # 取得或建立階層分類
uv run python wp_taxonomy.py get-or-create-tag <name>             # 取得或建立標籤
uv run python wp_taxonomy.py resolve-categories <name1> <name2>   # 批次解析分類
uv run python wp_taxonomy.py resolve-tags <name1> <name2>         # 批次解析標籤
uv run python wp_taxonomy.py delete-all-categories                # 刪除所有分類
```

---

## wp_comments.py — 留言管理

### Python API

```python
from wp_comments import (
    list_comments, get_comment, create_comment, reply_comment, delete_comment,
    approve_comment, hold_comment, spam_comment, trash_comment, update_comment_status
)
```

#### `list_comments(page=1, per_page=10, post=None, status=None, order="desc", orderby="date") -> (list, dict)`

查詢留言列表。`status` 可為 approve/hold/spam/trash/all。

#### `get_comment(comment_id) -> dict`

查詢單一留言。

#### `create_comment(post_id, content, author_name=None, author_email=None, parent=0, status="approved") -> dict`

建立新留言。`parent=0` 為頂層留言。

#### `reply_comment(post_id, parent_comment_id, content, author_name=None, author_email=None) -> dict`

回覆留言，預設直接公開（status=approved）。

#### `approve_comment(comment_id) -> dict`

核准留言。

#### `hold_comment(comment_id) -> dict`

設為待審核。

#### `spam_comment(comment_id) -> dict`

標記為垃圾留言。

#### `trash_comment(comment_id) -> dict`

移到垃圾桶。

#### `update_comment_status(comment_id, status) -> dict`

通用狀態更新。`status` 可為 approved/hold/spam/trash。

#### `delete_comment(comment_id, force=False) -> dict`

刪除留言。`force=True` 永久刪除，`force=False` 移到垃圾桶。

### CLI

```bash
uv run python wp_comments.py list [post_id] [status]
uv run python wp_comments.py get <comment_id>
uv run python wp_comments.py approve <comment_id>
uv run python wp_comments.py hold <comment_id>
uv run python wp_comments.py spam <comment_id>
uv run python wp_comments.py reply <post_id> <parent_comment_id> <content>
uv run python wp_comments.py delete <comment_id>
```

---

## wp_publish.py — 整合發文

### Python API — 發布

```python
from wp_publish import publish_from_markdown, publish_tech_post, update_tech_post
```

#### `publish_from_markdown(file_path, categories=None, tags=None, featured_image=None, excerpt=None, status="publish") -> dict`

從 Markdown 檔案發布。自動：讀取 YAML front matter、轉換 Markdown → HTML、解析分類/標籤、上傳封面圖。

```python
result = publish_from_markdown(
    file_path="./article.md",
    categories=["程式語言/Python", "教學"],
    tags=["python", "入門"],
    featured_image="https://example.com/cover.jpg",
    excerpt="文章摘要"
)
```

支援的 YAML front matter 欄位：`title`、`categories`、`tags`、`excerpt`、`featured_image`。

#### `publish_tech_post(title, content, categories=None, tags=None, featured_image=None, excerpt=None, status="publish") -> dict`

發布 HTML 格式文章。自動處理分類/標籤解析與封面圖上傳。

| 參數             | 類型       | 說明                                       |
| ---------------- | ---------- | ------------------------------------------ |
| `title`          | str        | 文章標題                                   |
| `content`        | str        | HTML 內容                                  |
| `categories`     | list[str]  | 分類名稱（支援路徑格式，不存在自動建立）   |
| `tags`           | list[str]  | 標籤名稱（不存在自動建立）                 |
| `featured_image` | str        | 封面圖路徑或 URL                           |
| `excerpt`        | str        | 文章摘要                                   |
| `status`         | str        | 狀態：publish/draft/pending/private         |

#### `update_tech_post(post_id, title=None, content=None, categories=None, tags=None, featured_image=None, excerpt=None, status=None) -> dict`

更新文章，只更新有提供的欄位。參數同 `publish_tech_post`。

#### 回傳格式

所有 publish/update 函數回傳：

```python
{
    "success": bool,
    "post": {"id": int, "title": str, "link": str, "status": str},
    "categories_resolved": [(name, id), ...],
    "tags_resolved": [(name, id), ...],
    "featured_media": {"id": int, "url": str},
    "errors": [str, ...]
}
```

### Python API — Markdown 轉換

```python
from wp_publish import markdown_to_html, read_markdown_file
```

#### `markdown_to_html(markdown_text) -> str`

Markdown → WordPress Gutenberg block HTML。支援：

- 標題（`#` ~ `######`）
- 粗體（`**text**`、`__text__`）、斜體（`*text*`、`_text_`）
- 連結（`[text](url)`）、圖片（`![alt](url)`）
- 無序列表（`- item`）、有序列表（`1. item`）、巢狀列表
- 程式碼區塊（` ```language `）、行內程式碼（`` `code` ``）
- 表格（`| col | col |`）
- 引用（`> text`）
- 分隔線（`---`）

#### `read_markdown_file(file_path) -> (title, html_content, front_matter)`

讀取 Markdown 檔案，提取 YAML front matter、標題、轉換後的 HTML。

### Python API — HTML 嵌入

```python
from wp_publish import extract_embeddable_html, read_quiz_file
```

#### `extract_embeddable_html(html_content, container_id=None) -> str`

從完整 HTML 檔案提取可嵌入內容。自動：

1. 移除 `<!DOCTYPE>`、`<html>`、`<head>`、`<body>` 標籤
2. 將全域 CSS 選擇器（`*`、`body`、`h1`、`code`）移除
3. 為 class/id 選擇器加上容器前綴（scope CSS）
4. 用 `<div id="container_id">` 包裹內容

#### `read_quiz_file(file_path, container_id=None) -> str`

讀取測驗 HTML 檔案並轉換為可嵌入格式。底層呼叫 `extract_embeddable_html()`。

### CLI

```bash
uv run python wp_publish.py publish --title <標題> --content <內容> [--categories <c1,c2>] [--tags <t1,t2>] [--featured-image <path|url>] [--excerpt <摘要>] [--status <狀態>]
uv run python wp_publish.py publish-markdown <file.md> [--categories <c1,c2>] [--tags <t1,t2>] [--featured-image <path|url>] [--excerpt <摘要>] [--status <狀態>]
uv run python wp_publish.py update <post_id> [--title <標題>] [--content <內容>] [--categories <c1,c2>] [--tags <t1,t2>] [--featured-image <path|url>] [--excerpt <摘要>] [--status <狀態>]
```

---

## 狀態參考

### 文章狀態

| 狀態      | 說明             |
| --------- | ---------------- |
| `publish` | 公開發布（預設） |
| `draft`   | 草稿             |
| `pending` | 待審核           |
| `private` | 私密             |

### 留言狀態

| 狀態       | 說明     |
| ---------- | -------- |
| `approved` | 已核准   |
| `hold`     | 待審核   |
| `spam`     | 垃圾留言 |
| `trash`    | 垃圾桶   |

## 錯誤處理

所有腳本使用 `requests.raise_for_status()`，失敗時拋出 `HTTPError`。

| 錯誤碼 | 說明                          |
| ------ | ----------------------------- |
| 400    | 請求格式錯誤                  |
| 401    | 認證失敗（檢查 App Password） |
| 403    | 權限不足                      |
| 404    | 資源不存在                    |
