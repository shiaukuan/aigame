#!/usr/bin/env python3
"""
WordPress 分類與標籤管理模組
支援：查詢、建立、刪除、智慧取得或建立
針對技術部落格優化
支援多階層分類（使用路徑格式如 "父分類/子分類/孫分類"）
"""
import requests
from typing import Optional
from wp_config import get_config


def _build_list_params(
    page: int,
    per_page: int,
    search: Optional[str],
    hide_empty: bool
) -> dict:
    """建立列表查詢參數"""
    params = {"page": page, "per_page": per_page, "hide_empty": hide_empty}
    if search:
        params["search"] = search
    return params


def _extract_pagination(response: requests.Response) -> dict:
    """從回應標頭提取分頁資訊"""
    return {
        "total": int(response.headers.get("X-WP-Total", 0)),
        "total_pages": int(response.headers.get("X-WP-TotalPages", 0))
    }


def _list_taxonomy(
    endpoint: str,
    page: int = 1,
    per_page: int = 100,
    search: Optional[str] = None,
    hide_empty: bool = False
) -> tuple[list[dict], dict]:
    """通用分類/標籤列表查詢"""
    config = get_config()
    params = _build_list_params(page, per_page, search, hide_empty)

    response = requests.get(
        f"{config.api_url}/{endpoint}",
        headers=config.auth_header,
        params=params
    )
    response.raise_for_status()

    return response.json(), _extract_pagination(response)


def _get_taxonomy(endpoint: str, item_id: int) -> dict:
    """通用分類/標籤單項查詢"""
    config = get_config()
    response = requests.get(
        f"{config.api_url}/{endpoint}/{item_id}",
        headers=config.auth_header
    )
    response.raise_for_status()
    return response.json()


def _create_taxonomy(endpoint: str, data: dict) -> dict:
    """通用分類/標籤建立（處理 term_exists 錯誤）"""
    config = get_config()
    response = requests.post(
        f"{config.api_url}/{endpoint}",
        headers={**config.auth_header, "Content-Type": "application/json"},
        json=data
    )

    # 處理 term_exists：已存在的直接回傳
    if response.status_code == 400:
        try:
            error_data = response.json()
            if error_data.get("code") == "term_exists":
                term_id = error_data["data"]["term_id"]
                return _get_taxonomy(endpoint, term_id)
        except (ValueError, KeyError):
            pass

    response.raise_for_status()
    return response.json()


def _delete_taxonomy(endpoint: str, item_id: int, force: bool = True) -> dict:
    """通用分類/標籤刪除"""
    config = get_config()
    response = requests.delete(
        f"{config.api_url}/{endpoint}/{item_id}",
        headers=config.auth_header,
        params={"force": force}
    )
    response.raise_for_status()
    return response.json()


def _find_by_name(items: list[dict], name: str, parent: Optional[int] = None) -> Optional[dict]:
    """在列表中根據名稱查找項目（不區分大小寫）"""
    name_lower = name.lower().strip()
    for item in items:
        if item["name"].lower().strip() != name_lower:
            continue
        if parent is None or item.get("parent", 0) == parent:
            return item
    return None


# ============ Categories ============

def list_categories(
    page: int = 1,
    per_page: int = 100,
    search: Optional[str] = None,
    hide_empty: bool = False
) -> tuple[list[dict], dict]:
    """查詢分類列表"""
    return _list_taxonomy("categories", page, per_page, search, hide_empty)


def get_category(category_id: int) -> dict:
    """查詢單一分類"""
    return _get_taxonomy("categories", category_id)


def create_category(
    name: str,
    slug: Optional[str] = None,
    description: Optional[str] = None,
    parent: Optional[int] = None
) -> dict:
    """建立分類"""
    data = {"name": name}
    if slug:
        data["slug"] = slug
    if description:
        data["description"] = description
    if parent:
        data["parent"] = parent
    return _create_taxonomy("categories", data)


def delete_category(category_id: int) -> dict:
    """刪除分類（ID=1 的「未分類」無法刪除）"""
    if category_id == 1:
        raise ValueError("無法刪除預設分類「未分類」(ID=1)")
    return _delete_taxonomy("categories", category_id)


def delete_all_categories() -> dict:
    """刪除所有分類（除了預設的「未分類」ID=1）"""
    deleted = 0
    failed = 0
    errors = []

    while True:
        cats, _ = list_categories(per_page=100)
        cats_to_delete = [c for c in cats if c['id'] != 1]

        if not cats_to_delete:
            break

        parent_ids = {c.get('parent', 0) for c in cats_to_delete}
        leaf_cats = [c for c in cats_to_delete if c['id'] not in parent_ids]

        if not leaf_cats:
            leaf_cats = cats_to_delete[:1]

        for cat in leaf_cats:
            try:
                delete_category(cat['id'])
                deleted += 1
                print(f"✓ 已刪除: [{cat['id']}] {cat['name']}")
            except Exception as e:
                failed += 1
                errors.append(f"[{cat['id']}] {cat['name']}: {e}")
                print(f"✗ 失敗: [{cat['id']}] {cat['name']} - {e}")

    return {"deleted": deleted, "failed": failed, "errors": errors}


def find_category_by_name(name: str, parent: Optional[int] = None) -> Optional[dict]:
    """根據名稱查找分類（使用 search 參數精準查找）"""
    categories, _ = list_categories(per_page=100, search=name)
    return _find_by_name(categories, name, parent)


def get_or_create_category(
    name: str,
    description: Optional[str] = None,
    parent: Optional[int] = None
) -> dict:
    """智慧取得或建立分類"""
    existing = find_category_by_name(name, parent=parent)
    if existing:
        return existing
    return create_category(name=name, description=description, parent=parent)


def get_or_create_category_path(path: str, separator: str = "/") -> dict:
    """根據階層路徑取得或建立分類"""
    parts = [p.strip() for p in path.split(separator) if p.strip()]
    if not parts:
        raise ValueError("分類路徑不能為空")

    parent_id = None
    current_cat = None

    for part in parts:
        current_cat = get_or_create_category(name=part, parent=parent_id)
        parent_id = current_cat["id"]

    return current_cat


def get_category_path(category_id: int, cats_dict: Optional[dict] = None) -> str:
    """取得分類的完整階層路徑"""
    if cats_dict is None:
        cats, _ = list_categories(per_page=100)
        cats_dict = {cat['id']: cat for cat in cats}

    path_parts = []
    current_id = category_id

    while current_id and current_id in cats_dict:
        cat = cats_dict[current_id]
        path_parts.insert(0, cat['name'])
        current_id = cat.get('parent', 0)

    return '/'.join(path_parts)


def list_categories_tree() -> list[dict]:
    """列出所有分類的階層路徑格式"""
    cats, _ = list_categories(per_page=100)
    cats_dict = {cat['id']: cat for cat in cats}

    result = [
        {
            'id': cat['id'],
            'name': cat['name'],
            'path': get_category_path(cat['id'], cats_dict),
            'parent': cat.get('parent', 0),
            'count': cat.get('count', 0)
        }
        for cat in cats
    ]
    result.sort(key=lambda x: x['path'])
    return result


# ============ Tags ============

def list_tags(
    page: int = 1,
    per_page: int = 100,
    search: Optional[str] = None,
    hide_empty: bool = False
) -> tuple[list[dict], dict]:
    """查詢標籤列表"""
    return _list_taxonomy("tags", page, per_page, search, hide_empty)


def get_tag(tag_id: int) -> dict:
    """查詢單一標籤"""
    return _get_taxonomy("tags", tag_id)


def create_tag(
    name: str,
    slug: Optional[str] = None,
    description: Optional[str] = None
) -> dict:
    """建立標籤"""
    data = {"name": name}
    if slug:
        data["slug"] = slug
    if description:
        data["description"] = description
    return _create_taxonomy("tags", data)


def find_tag_by_name(name: str) -> Optional[dict]:
    """根據名稱查找標籤（使用 search 參數精準查找）"""
    tags, _ = list_tags(per_page=100, search=name)
    return _find_by_name(tags, name)


def get_or_create_tag(name: str, description: Optional[str] = None) -> dict:
    """智慧取得或建立標籤"""
    existing = find_tag_by_name(name)
    if existing:
        return existing
    return create_tag(name=name, description=description)


# ============ 批次處理 ============

def resolve_categories(names: list[str]) -> list[int]:
    """批次解析分類名稱或路徑為 ID"""
    result = []
    for name in names:
        if "/" in name:
            cat = get_or_create_category_path(name)
        else:
            cat = get_or_create_category(name)
        result.append(cat["id"])
    return result


def resolve_tags(names: list[str]) -> list[int]:
    """批次解析標籤名稱為 ID"""
    return [get_or_create_tag(name)["id"] for name in names]


def _print_usage() -> None:
    """顯示使用說明"""
    print("用法:")
    print("  python wp_taxonomy.py categories            # 列出所有分類")
    print("  python wp_taxonomy.py categories-tree       # 階層格式列出所有分類")
    print("  python wp_taxonomy.py delete-all-categories # 刪除所有分類")
    print("  python wp_taxonomy.py tags                  # 列出所有標籤")
    print("  python wp_taxonomy.py get-or-create-category <name>")
    print("  python wp_taxonomy.py get-or-create-category-path <path>")
    print("  python wp_taxonomy.py get-or-create-tag <name>")
    print("  python wp_taxonomy.py resolve-categories <name1> <name2> ...")
    print("  python wp_taxonomy.py resolve-tags <name1> <name2> ...")


def _run_cli(action: str, args: list[str]) -> None:
    """執行 CLI 命令"""
    if action == "categories":
        cats, pagination = list_categories()
        print(f"共 {pagination['total']} 個分類:")
        for cat in cats:
            parent_info = f" (parent: {cat['parent']})" if cat.get('parent') else ""
            print(f"  [{cat['id']}] {cat['name']}{parent_info} (count: {cat['count']})")

    elif action == "categories-tree":
        cats = list_categories_tree()
        print(f"共 {len(cats)} 個分類:\n")
        for cat in cats:
            print(f"[{cat['id']:3d}] {cat['path']}")

    elif action == "delete-all-categories":
        print("正在刪除所有分類...\n")
        result = delete_all_categories()
        print(f"\n完成: 刪除 {result['deleted']} 個, 失敗 {result['failed']} 個")

    elif action == "tags":
        tags, pagination = list_tags()
        print(f"共 {pagination['total']} 個標籤:")
        for tag in tags:
            print(f"  [{tag['id']}] {tag['name']} (count: {tag['count']})")

    elif action == "get-or-create-category":
        cat = get_or_create_category(args[0])
        print(f"分類: [{cat['id']}] {cat['name']}")

    elif action == "get-or-create-category-path":
        cat = get_or_create_category_path(args[0])
        print(f"分類: [{cat['id']}] {cat['name']} (parent: {cat.get('parent', 0)})")

    elif action == "get-or-create-tag":
        tag = get_or_create_tag(args[0])
        print(f"標籤: [{tag['id']}] {tag['name']}")

    elif action == "resolve-categories":
        ids = resolve_categories(args)
        print(f"分類 IDs: {ids}")

    elif action == "resolve-tags":
        ids = resolve_tags(args)
        print(f"標籤 IDs: {ids}")

    else:
        _print_usage()


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        _print_usage()
        sys.exit(1)

    _run_cli(sys.argv[1], sys.argv[2:])
