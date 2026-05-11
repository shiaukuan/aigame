#!/usr/bin/env python3
"""
WordPress 文章管理模組
支援：發文、更新、刪除、查詢、列表（分頁、搜尋、篩選）
"""
import json
import requests
from wp_config import get_config


def create_post(
    title: str,
    content: str,
    status: str = "publish",
    categories: list[int] = None,
    tags: list[int] = None,
    featured_media: int = None,
    excerpt: str = None
) -> dict:
    """
    建立新文章

    Args:
        title: 文章標題
        content: 文章內容（支援 HTML）
        status: 發布狀態 (publish/draft/pending/private)，預設 publish
        categories: 分類 ID 列表
        tags: 標籤 ID 列表
        featured_media: 精選圖片（封面圖）的 Media ID
        excerpt: 文章摘要

    Returns:
        新建文章的完整資料
    """
    config = get_config()

    data = {
        "title": title,
        "content": content,
        "status": status
    }

    if categories:
        data["categories"] = categories
    if tags:
        data["tags"] = tags
    if featured_media:
        data["featured_media"] = featured_media
    if excerpt:
        data["excerpt"] = excerpt

    response = requests.post(
        f"{config.api_url}/posts",
        headers={**config.auth_header, "Content-Type": "application/json"},
        json=data
    )
    response.raise_for_status()
    return response.json()


def update_post(
    post_id: int,
    title: str = None,
    content: str = None,
    status: str = None,
    categories: list[int] = None,
    tags: list[int] = None,
    featured_media: int = None,
    excerpt: str = None
) -> dict:
    """
    更新文章

    Args:
        post_id: 文章 ID
        其他參數同 create_post，只更新有提供的欄位

    Returns:
        更新後文章的完整資料
    """
    config = get_config()

    data = {}
    if title is not None:
        data["title"] = title
    if content is not None:
        data["content"] = content
    if status is not None:
        data["status"] = status
    if categories is not None:
        data["categories"] = categories
    if tags is not None:
        data["tags"] = tags
    if featured_media is not None:
        data["featured_media"] = featured_media
    if excerpt is not None:
        data["excerpt"] = excerpt

    response = requests.post(
        f"{config.api_url}/posts/{post_id}",
        headers={**config.auth_header, "Content-Type": "application/json"},
        json=data
    )
    response.raise_for_status()
    return response.json()


def delete_post(post_id: int, force: bool = False) -> dict:
    """
    刪除文章

    Args:
        post_id: 文章 ID
        force: True=永久刪除, False=移到垃圾桶

    Returns:
        刪除的文章資料
    """
    config = get_config()

    params = {"force": force}
    response = requests.delete(
        f"{config.api_url}/posts/{post_id}",
        headers=config.auth_header,
        params=params
    )
    response.raise_for_status()
    return response.json()


def get_post(post_id: int) -> dict:
    """
    查詢單篇文章

    Args:
        post_id: 文章 ID

    Returns:
        文章完整資料
    """
    config = get_config()

    response = requests.get(
        f"{config.api_url}/posts/{post_id}",
        headers=config.auth_header
    )
    response.raise_for_status()
    return response.json()


def list_posts(
    page: int = 1,
    per_page: int = 10,
    search: str = None,
    categories: list[int] = None,
    tags: list[int] = None,
    status: str = None,
    order: str = "desc",
    orderby: str = "date"
) -> tuple[list[dict], dict]:
    """
    查詢文章列表（支援分頁、搜尋、篩選）

    Args:
        page: 頁碼（從 1 開始）
        per_page: 每頁筆數（最大 100）
        search: 搜尋關鍵字
        categories: 篩選分類 ID 列表
        tags: 篩選標籤 ID 列表
        status: 篩選狀態 (publish/draft/pending/private/trash)
        order: 排序方向 (asc/desc)
        orderby: 排序欄位 (date/id/title/slug/modified)

    Returns:
        (文章列表, 分頁資訊)
        分頁資訊包含 total, total_pages
    """
    config = get_config()

    params = {
        "page": page,
        "per_page": per_page,
        "order": order,
        "orderby": orderby
    }

    if search:
        params["search"] = search
    if categories:
        params["categories"] = ",".join(map(str, categories))
    if tags:
        params["tags"] = ",".join(map(str, tags))
    if status:
        params["status"] = status

    response = requests.get(
        f"{config.api_url}/posts",
        headers=config.auth_header,
        params=params
    )
    response.raise_for_status()

    pagination = {
        "total": int(response.headers.get("X-WP-Total", 0)),
        "total_pages": int(response.headers.get("X-WP-TotalPages", 0)),
        "page": page,
        "per_page": per_page
    }

    return response.json(), pagination


def list_titles(search: str = None) -> list[dict]:
    """
    列出所有文章標題（用於檢查重複）

    Args:
        search: 搜尋關鍵字（可選）

    Returns:
        標題資訊列表，每項包含 id 和 title
    """
    all_titles = []
    page = 1
    per_page = 100

    while True:
        posts, pagination = list_posts(
            page=page,
            per_page=per_page,
            search=search,
            orderby="title",
            order="asc"
        )

        for post in posts:
            all_titles.append({
                "id": post['id'],
                "title": post['title']['rendered']
            })

        if page >= pagination['total_pages']:
            break
        page += 1

    return all_titles


if __name__ == "__main__":
    # 測試用範例
    import sys

    if len(sys.argv) < 2:
        print("用法:")
        print("  python wp_posts.py list [--search <關鍵字>] [--page <頁碼>] [--per-page <筆數>]")
        print("  python wp_posts.py search <關鍵字>")
        print("  python wp_posts.py titles [關鍵字]       # 列出所有標題（用於檢查重複）")
        print("  python wp_posts.py get <post_id>")
        print("  python wp_posts.py create <title> <content>")
        print("  python wp_posts.py delete <post_id>")
        print("")
        print("範例:")
        print("  python wp_posts.py list --search git")
        print("  python wp_posts.py search Python")
        print("  python wp_posts.py titles git")
        sys.exit(1)

    action = sys.argv[1]

    def get_arg(name: str, default=None):
        """解析命令列參數"""
        args = sys.argv[2:]
        try:
            idx = args.index(f"--{name}")
            return args[idx + 1]
        except (ValueError, IndexError):
            return default

    if action == "list":
        search = get_arg("search")
        page = int(get_arg("page", 1))
        per_page = int(get_arg("per-page", 10))
        posts, pagination = list_posts(page=page, per_page=per_page, search=search)

        if search:
            print(f"搜尋「{search}」：共 {pagination['total']} 篇文章，第 {page}/{pagination['total_pages']} 頁")
        else:
            print(f"共 {pagination['total']} 篇文章，第 {page}/{pagination['total_pages']} 頁")

        for post in posts:
            print(f"  [{post['id']}] {post['title']['rendered']}")

    elif action == "search":
        if len(sys.argv) < 3:
            print("錯誤: 請提供搜尋關鍵字")
            sys.exit(1)
        keyword = sys.argv[2]
        posts, pagination = list_posts(search=keyword, per_page=20)
        print(f"搜尋「{keyword}」：共 {pagination['total']} 篇文章")
        for post in posts:
            print(f"  [{post['id']}] {post['title']['rendered']}")

    elif action == "titles":
        keyword = sys.argv[2] if len(sys.argv) > 2 else None
        titles = list_titles(search=keyword)

        if keyword:
            print(f"搜尋「{keyword}」的所有標題（共 {len(titles)} 篇）：")
        else:
            print(f"所有文章標題（共 {len(titles)} 篇）：")

        for item in titles:
            print(f"  [{item['id']}] {item['title']}")

    elif action == "get":
        post_id = int(sys.argv[2])
        post = get_post(post_id)
        print(json.dumps(post, indent=2, ensure_ascii=False))

    elif action == "create":
        title = sys.argv[2]
        content = sys.argv[3]
        post = create_post(title=title, content=content)
        print(f"已建立文章 ID: {post['id']}")
        print(f"連結: {post['link']}")

    elif action == "delete":
        post_id = int(sys.argv[2])
        result = delete_post(post_id)
        print(f"已刪除文章 ID: {post_id}")
