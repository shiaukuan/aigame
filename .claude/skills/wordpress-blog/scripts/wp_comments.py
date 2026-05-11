#!/usr/bin/env python3
"""
WordPress 留言管理模組
支援：讀取留言、審核留言、回覆留言
預設為直接公開回覆
"""
import requests
from wp_config import get_config


def list_comments(
    page: int = 1,
    per_page: int = 10,
    post: int = None,
    status: str = None,
    order: str = "desc",
    orderby: str = "date"
) -> tuple[list[dict], dict]:
    """
    查詢留言列表

    Args:
        page: 頁碼
        per_page: 每頁筆數
        post: 篩選特定文章的留言
        status: 留言狀態 (approve/hold/spam/trash/all)
        order: 排序方向 (asc/desc)
        orderby: 排序欄位 (date/id)

    Returns:
        (留言列表, 分頁資訊)
    """
    config = get_config()

    params = {
        "page": page,
        "per_page": per_page,
        "order": order,
        "orderby": orderby
    }
    if post:
        params["post"] = post
    if status:
        params["status"] = status

    response = requests.get(
        f"{config.api_url}/comments",
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


def get_comment(comment_id: int) -> dict:
    """
    查詢單一留言

    Args:
        comment_id: 留言 ID

    Returns:
        留言完整資料
    """
    config = get_config()

    response = requests.get(
        f"{config.api_url}/comments/{comment_id}",
        headers=config.auth_header
    )
    response.raise_for_status()
    return response.json()


def approve_comment(comment_id: int) -> dict:
    """
    核准留言

    Args:
        comment_id: 留言 ID

    Returns:
        更新後的留言資料
    """
    return update_comment_status(comment_id, "approved")


def hold_comment(comment_id: int) -> dict:
    """
    將留言設為待審核

    Args:
        comment_id: 留言 ID

    Returns:
        更新後的留言資料
    """
    return update_comment_status(comment_id, "hold")


def spam_comment(comment_id: int) -> dict:
    """
    將留言標記為垃圾留言

    Args:
        comment_id: 留言 ID

    Returns:
        更新後的留言資料
    """
    return update_comment_status(comment_id, "spam")


def trash_comment(comment_id: int) -> dict:
    """
    將留言移到垃圾桶

    Args:
        comment_id: 留言 ID

    Returns:
        更新後的留言資料
    """
    return update_comment_status(comment_id, "trash")


def update_comment_status(comment_id: int, status: str) -> dict:
    """
    更新留言狀態

    Args:
        comment_id: 留言 ID
        status: 新狀態 (approved/hold/spam/trash)

    Returns:
        更新後的留言資料
    """
    config = get_config()

    response = requests.post(
        f"{config.api_url}/comments/{comment_id}",
        headers={**config.auth_header, "Content-Type": "application/json"},
        json={"status": status}
    )
    response.raise_for_status()
    return response.json()


def reply_comment(
    post_id: int,
    parent_comment_id: int,
    content: str,
    author_name: str = None,
    author_email: str = None
) -> dict:
    """
    回覆留言（預設直接公開）

    Args:
        post_id: 文章 ID
        parent_comment_id: 要回覆的留言 ID
        content: 回覆內容
        author_name: 作者名稱（如未登入）
        author_email: 作者 Email（如未登入）

    Returns:
        新建留言資料
    """
    config = get_config()

    data = {
        "post": post_id,
        "parent": parent_comment_id,
        "content": content,
        "status": "approved"  # 預設直接公開
    }

    if author_name:
        data["author_name"] = author_name
    if author_email:
        data["author_email"] = author_email

    response = requests.post(
        f"{config.api_url}/comments",
        headers={**config.auth_header, "Content-Type": "application/json"},
        json=data
    )
    response.raise_for_status()
    return response.json()


def create_comment(
    post_id: int,
    content: str,
    author_name: str = None,
    author_email: str = None,
    parent: int = 0,
    status: str = "approved"
) -> dict:
    """
    建立新留言

    Args:
        post_id: 文章 ID
        content: 留言內容
        author_name: 作者名稱
        author_email: 作者 Email
        parent: 父留言 ID（0 = 頂層留言）
        status: 留言狀態（預設 approved）

    Returns:
        新建留言資料
    """
    config = get_config()

    data = {
        "post": post_id,
        "content": content,
        "parent": parent,
        "status": status
    }

    if author_name:
        data["author_name"] = author_name
    if author_email:
        data["author_email"] = author_email

    response = requests.post(
        f"{config.api_url}/comments",
        headers={**config.auth_header, "Content-Type": "application/json"},
        json=data
    )
    response.raise_for_status()
    return response.json()


def delete_comment(comment_id: int, force: bool = False) -> dict:
    """
    刪除留言

    Args:
        comment_id: 留言 ID
        force: True=永久刪除, False=移到垃圾桶

    Returns:
        刪除結果
    """
    config = get_config()

    response = requests.delete(
        f"{config.api_url}/comments/{comment_id}",
        headers=config.auth_header,
        params={"force": force}
    )
    response.raise_for_status()
    return response.json()


if __name__ == "__main__":
    import sys
    import json

    if len(sys.argv) < 2:
        print("用法:")
        print("  python wp_comments.py list [post_id] [status]")
        print("  python wp_comments.py get <comment_id>")
        print("  python wp_comments.py approve <comment_id>")
        print("  python wp_comments.py hold <comment_id>")
        print("  python wp_comments.py spam <comment_id>")
        print("  python wp_comments.py reply <post_id> <parent_comment_id> <content>")
        print("  python wp_comments.py delete <comment_id>")
        sys.exit(1)

    action = sys.argv[1]

    if action == "list":
        post_id = int(sys.argv[2]) if len(sys.argv) > 2 else None
        status = sys.argv[3] if len(sys.argv) > 3 else None
        comments, pagination = list_comments(post=post_id, status=status)
        print(f"共 {pagination['total']} 則留言，第 {pagination['page']}/{pagination['total_pages']} 頁")
        for c in comments:
            status_icon = "✓" if c["status"] == "approved" else "○"
            print(f"  [{c['id']}] {status_icon} {c['author_name']}: {c['content']['rendered'][:50]}...")

    elif action == "get":
        comment_id = int(sys.argv[2])
        comment = get_comment(comment_id)
        print(json.dumps(comment, indent=2, ensure_ascii=False))

    elif action == "approve":
        comment_id = int(sys.argv[2])
        result = approve_comment(comment_id)
        print(f"已核准留言 ID: {comment_id}")

    elif action == "hold":
        comment_id = int(sys.argv[2])
        result = hold_comment(comment_id)
        print(f"已設為待審核 ID: {comment_id}")

    elif action == "spam":
        comment_id = int(sys.argv[2])
        result = spam_comment(comment_id)
        print(f"已標記為垃圾留言 ID: {comment_id}")

    elif action == "reply":
        post_id = int(sys.argv[2])
        parent_id = int(sys.argv[3])
        content = sys.argv[4]
        result = reply_comment(post_id, parent_id, content)
        print(f"已回覆，新留言 ID: {result['id']}")

    elif action == "delete":
        comment_id = int(sys.argv[2])
        delete_comment(comment_id)
        print(f"已刪除留言 ID: {comment_id}")
