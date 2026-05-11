#!/usr/bin/env python3
"""
WordPress 媒體上傳模組
支援：圖片上傳（內文圖片、封面圖）
"""
import os
import re
import mimetypes
import requests
from pathlib import Path
from wp_config import get_config


def upload_image(
    file_path: str,
    title: str = None,
    alt_text: str = None,
    caption: str = None
) -> dict:
    """
    上傳圖片到 WordPress 媒體庫

    Args:
        file_path: 本地圖片路徑
        title: 圖片標題（預設使用檔名）
        alt_text: 替代文字（SEO 用）
        caption: 圖片說明

    Returns:
        上傳後的媒體資料，包含 id, source_url 等
    """
    config = get_config()
    path = Path(file_path)

    if not path.exists():
        raise FileNotFoundError(f"找不到檔案: {file_path}")

    # 偵測 MIME 類型
    mime_type, _ = mimetypes.guess_type(str(path))
    if not mime_type or not mime_type.startswith("image/"):
        raise ValueError(f"不支援的檔案類型: {mime_type}")

    # 準備上傳（非 ASCII 檔名轉換為安全的 ASCII 檔名）
    filename = path.name
    try:
        filename.encode('latin-1')
        safe_filename = filename
    except UnicodeEncodeError:
        # 只保留 ASCII 可見字元，其餘替換為底線
        stem = re.sub(r'[^\x20-\x7E]', '_', path.stem).strip('_')
        stem = re.sub(r'_+', '_', stem)
        if not stem:
            stem = 'upload'
        safe_filename = f"{stem}{path.suffix}"
    headers = {
        **config.auth_header,
        "Content-Disposition": f'attachment; filename="{safe_filename}"',
        "Content-Type": mime_type
    }

    with open(path, "rb") as f:
        response = requests.post(
            f"{config.api_url}/media",
            headers=headers,
            data=f.read()
        )

    response.raise_for_status()
    media = response.json()

    # 更新 alt_text, caption（需要額外 PATCH）
    if alt_text or caption or title:
        update_data = {}
        if alt_text:
            update_data["alt_text"] = alt_text
        if caption:
            update_data["caption"] = caption
        if title:
            update_data["title"] = title

        update_response = requests.post(
            f"{config.api_url}/media/{media['id']}",
            headers={**config.auth_header, "Content-Type": "application/json"},
            json=update_data
        )
        update_response.raise_for_status()
        media = update_response.json()

    return media


def upload_image_from_url(
    image_url: str,
    filename: str = None,
    title: str = None,
    alt_text: str = None,
    caption: str = None
) -> dict:
    """
    從 URL 下載圖片並上傳到 WordPress

    Args:
        image_url: 圖片網址
        filename: 儲存的檔名（預設從 URL 取得）
        title: 圖片標題
        alt_text: 替代文字
        caption: 圖片說明

    Returns:
        上傳後的媒體資料
    """
    import tempfile

    # 下載圖片
    response = requests.get(image_url)
    response.raise_for_status()

    # 決定檔名
    if not filename:
        from urllib.parse import urlparse
        parsed = urlparse(image_url)
        filename = os.path.basename(parsed.path) or "image.jpg"

    # 暫存後上傳
    with tempfile.NamedTemporaryFile(suffix=os.path.splitext(filename)[1], delete=False) as f:
        f.write(response.content)
        temp_path = f.name

    try:
        return upload_image(temp_path, title=title, alt_text=alt_text, caption=caption)
    finally:
        os.unlink(temp_path)


def get_media(media_id: int) -> dict:
    """
    查詢媒體資料

    Args:
        media_id: 媒體 ID

    Returns:
        媒體完整資料
    """
    config = get_config()

    response = requests.get(
        f"{config.api_url}/media/{media_id}",
        headers=config.auth_header
    )
    response.raise_for_status()
    return response.json()


def list_media(
    page: int = 1,
    per_page: int = 10,
    media_type: str = "image",
    search: str = None
) -> tuple[list[dict], dict]:
    """
    查詢媒體列表

    Args:
        page: 頁碼
        per_page: 每頁筆數
        media_type: 媒體類型 (image/video/audio/application)
        search: 搜尋關鍵字

    Returns:
        (媒體列表, 分頁資訊)
    """
    config = get_config()

    params = {
        "page": page,
        "per_page": per_page,
        "media_type": media_type
    }
    if search:
        params["search"] = search

    response = requests.get(
        f"{config.api_url}/media",
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


def delete_media(media_id: int, force: bool = True) -> dict:
    """
    刪除媒體

    Args:
        media_id: 媒體 ID
        force: 必須為 True（媒體不支援垃圾桶）

    Returns:
        刪除結果
    """
    config = get_config()

    response = requests.delete(
        f"{config.api_url}/media/{media_id}",
        headers=config.auth_header,
        params={"force": True}  # 媒體必須強制刪除
    )
    response.raise_for_status()
    return response.json()


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("用法:")
        print("  python wp_media.py upload <file_path> [alt_text]")
        print("  python wp_media.py upload-url <image_url> [filename]")
        print("  python wp_media.py list [page] [per_page]")
        print("  python wp_media.py get <media_id>")
        print("  python wp_media.py delete <media_id>")
        sys.exit(1)

    action = sys.argv[1]

    if action == "upload":
        file_path = sys.argv[2]
        alt_text = sys.argv[3] if len(sys.argv) > 3 else None
        media = upload_image(file_path, alt_text=alt_text)
        print(f"上傳成功！Media ID: {media['id']}")
        print(f"URL: {media['source_url']}")

    elif action == "upload-url":
        image_url = sys.argv[2]
        filename = sys.argv[3] if len(sys.argv) > 3 else None
        media = upload_image_from_url(image_url, filename=filename)
        print(f"上傳成功！Media ID: {media['id']}")
        print(f"URL: {media['source_url']}")

    elif action == "list":
        page = int(sys.argv[2]) if len(sys.argv) > 2 else 1
        per_page = int(sys.argv[3]) if len(sys.argv) > 3 else 10
        media_list, pagination = list_media(page=page, per_page=per_page)
        print(f"共 {pagination['total']} 筆媒體，第 {page}/{pagination['total_pages']} 頁")
        for m in media_list:
            print(f"  [{m['id']}] {m['title']['rendered']} - {m['source_url']}")

    elif action == "get":
        media_id = int(sys.argv[2])
        media = get_media(media_id)
        print(f"ID: {media['id']}")
        print(f"Title: {media['title']['rendered']}")
        print(f"URL: {media['source_url']}")

    elif action == "delete":
        media_id = int(sys.argv[2])
        delete_media(media_id)
        print(f"已刪除媒體 ID: {media_id}")
