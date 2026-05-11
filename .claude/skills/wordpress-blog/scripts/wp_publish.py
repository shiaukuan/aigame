#!/usr/bin/env python3
"""
WordPress 完整發文工具
整合文章、媒體、分類、標籤功能
針對技術部落格優化，支援智慧分類/標籤建立
支援 Markdown 自動轉換為 HTML（WordPress Gutenberg block 格式）
"""
import json
import re
import uuid
from pathlib import Path
from wp_posts import create_post, update_post
from wp_media import upload_image, upload_image_from_url
from wp_taxonomy import resolve_categories, resolve_tags


def extract_embeddable_html(html_content: str, container_id: str = None) -> str:
    """
    從完整的 HTML 檔案中提取可嵌入的內容。

    處理步驟：
    1. 提取 <body> 內的內容（移除 <!DOCTYPE>, <html>, <head>, <body> 標籤）
    2. 提取 <style> 標籤內的 CSS，並將全域選擇器改成 scoped 選擇器
    3. 提取 <script> 標籤
    4. 用容器 div 包裹內容，確保樣式只作用於該區塊

    Args:
        html_content: 完整的 HTML 檔案內容
        container_id: 容器 ID（可選，會自動生成）

    Returns:
        可嵌入的 HTML 內容
    """
    if container_id is None:
        container_id = f"quiz-{uuid.uuid4().hex[:8]}"

    # 提取 <style> 內容
    style_match = re.search(r'<style[^>]*>(.*?)</style>', html_content, re.DOTALL)
    style_content = style_match.group(1) if style_match else ""

    # 提取 <body> 內容
    body_match = re.search(r'<body[^>]*>(.*?)</body>', html_content, re.DOTALL)
    body_content = body_match.group(1).strip() if body_match else html_content

    # 提取 <script> 內容
    script_match = re.search(r'<script[^>]*>(.*?)</script>', html_content, re.DOTALL)
    script_content = script_match.group(1) if script_match else ""

    # 從 body 中移除 <script> 標籤（稍後會重新加入）
    body_content = re.sub(r'<script[^>]*>.*?</script>', '', body_content, flags=re.DOTALL).strip()

    # 將全域 CSS 選擇器改成 scoped 選擇器
    if style_content:
        # 移除會影響全域的選擇器
        # 移除 * { } 規則
        style_content = re.sub(r'\*\s*\{[^}]*\}', '', style_content)
        # 移除 body { } 規則
        style_content = re.sub(r'body\s*\{[^}]*\}', '', style_content)
        # 移除獨立的 h1 { } 規則（不是 .class h1）
        style_content = re.sub(r'(?<![.\w-])h1\s*\{[^}]*\}', '', style_content)
        # 移除獨立的 code { } 規則
        style_content = re.sub(r'(?<![.\w-])code\s*\{[^}]*\}', '', style_content)

        # 為所有 class 選擇器加上容器前綴
        def add_container_prefix(match):
            selector = match.group(1)
            rules = match.group(2)
            # 跳過已經處理過的選擇器
            if selector.startswith(f'#{container_id}'):
                return match.group(0)
            # 處理多個選擇器（用逗號分隔）
            selectors = [s.strip() for s in selector.split(',')]
            prefixed_selectors = []
            for sel in selectors:
                if sel.startswith('.') or sel.startswith('#'):
                    prefixed_selectors.append(f'#{container_id} {sel}')
                else:
                    prefixed_selectors.append(sel)
            return ', '.join(prefixed_selectors) + ' {' + rules + '}'

        # 匹配 CSS 規則
        style_content = re.sub(r'([^{]+)\{([^}]*)\}', add_container_prefix, style_content)

        # 清理多餘空白
        style_content = re.sub(r'\n\s*\n', '\n', style_content).strip()

    # 組合嵌入式 HTML
    result = f'<div id="{container_id}">\n'
    if style_content:
        result += f'<style>\n{style_content}\n</style>\n'
    result += body_content + '\n'
    if script_content:
        result += f'<script>\n{script_content}\n</script>\n'
    result += '</div>'

    return result


def read_quiz_file(file_path: str, container_id: str = None) -> str:
    """
    讀取測驗 HTML 檔案並轉換為可嵌入格式。

    Args:
        file_path: HTML 檔案路徑
        container_id: 容器 ID（可選）

    Returns:
        可嵌入的 HTML 內容
    """
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"找不到檔案: {file_path}")

    content = path.read_text(encoding='utf-8')
    return extract_embeddable_html(content, container_id)


def markdown_to_html(markdown_text: str) -> str:
    """
    將 Markdown 轉換為 HTML（WordPress Gutenberg block 格式）
    """
    html = markdown_text

    # 使用佔位符保護程式碼區塊
    code_blocks = {}

    def protect_code_block(match):
        code = match.group(2)
        code = code.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("[", "&#91;")
        placeholder = f"%%CODEBLOCK{uuid.uuid4().hex}%%"

        code_blocks[placeholder] = f'<!-- wp:code -->\n<pre class="wp-block-code"><code>{code}</code></pre>\n<!-- /wp:code -->'
        return placeholder

    html = re.sub(r'```(\w*)\n(.*?)```', protect_code_block, html, flags=re.DOTALL)

    # 行內程式碼 - 使用佔位符保護，避免內部 ** 和 _ 被格式化規則匹配
    inline_codes = {}

    def inline_code_replace(match):
        code = match.group(1)
        code = code.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        placeholder = f"%%INLINECODE{uuid.uuid4().hex}%%"
        inline_codes[placeholder] = f'<code>{code}</code>'
        return placeholder

    html = re.sub(r'`([^`]+)`', inline_code_replace, html)

    # 表格處理
    tables = {}

    def split_table_row(line):
        """分割表格列，保護佔位符內的 | 符號"""
        # 保護佔位符內的 |
        protected_line = re.sub(
            r'%%INLINECODE[a-f0-9]+%%',
            lambda m: m.group(0).replace('|', '%%PIPE%%'),
            line
        )
        # 分割後還原 |
        cells = [cell.strip().replace('%%PIPE%%', '|') for cell in protected_line.split('|') if cell.strip()]
        return cells

    def table_replace(match):
        lines = match.group(0).strip().split('\n')
        if len(lines) < 2:
            return match.group(0)

        result = ['<!-- wp:table {"hasFixedLayout":false} -->', '<figure class="wp-block-table"><table>', '<thead>', '<tr>']
        headers = split_table_row(lines[0])
        for header in headers:
            result.append(f'<th>{header}</th>')
        result.extend(['</tr>', '</thead>', '<tbody>'])

        for line in lines[2:]:
            cells = split_table_row(line)
            if cells:
                result.append('<tr>')
                for cell in cells:
                    cell = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', cell)
                    result.append(f'<td>{cell}</td>')
                result.append('</tr>')

        result.extend(['</tbody>', '</table></figure>', '<!-- /wp:table -->'])
        placeholder = f"%%TABLE{uuid.uuid4().hex}%%"
        tables[placeholder] = '\n'.join(result)
        return placeholder

    html = re.sub(r'(\|[^\n]+\|\n)+', table_replace, html)

    # 標題
    headings = {}

    def heading_replace(level, match):
        text = match.group(1)
        placeholder = f"%%HEADING{uuid.uuid4().hex}%%"
        if level == 2:
            headings[placeholder] = f'<!-- wp:heading -->\n<h2 class="wp-block-heading">{text}</h2>\n<!-- /wp:heading -->'
        else:
            headings[placeholder] = f'<!-- wp:heading {{"level":{level}}} -->\n<h{level} class="wp-block-heading">{text}</h{level}>\n<!-- /wp:heading -->'
        return placeholder

    html = re.sub(r'^######\s+(.+)$', lambda m: heading_replace(6, m), html, flags=re.MULTILINE)
    html = re.sub(r'^#####\s+(.+)$', lambda m: heading_replace(5, m), html, flags=re.MULTILINE)
    html = re.sub(r'^####\s+(.+)$', lambda m: heading_replace(4, m), html, flags=re.MULTILINE)
    html = re.sub(r'^###\s+(.+)$', lambda m: heading_replace(3, m), html, flags=re.MULTILINE)
    html = re.sub(r'^##\s+(.+)$', lambda m: heading_replace(2, m), html, flags=re.MULTILINE)
    html = re.sub(r'^#\s+(.+)$', lambda m: heading_replace(1, m), html, flags=re.MULTILINE)

    # 分隔線
    separators = {}

    def separator_replace(match):
        placeholder = f"%%SEPARATOR{uuid.uuid4().hex}%%"
        separators[placeholder] = '<!-- wp:separator -->\n<hr class="wp-block-separator has-alpha-channel-opacity"/>\n<!-- /wp:separator -->'
        return placeholder

    html = re.sub(r'^[-*]{3,}\s*$', separator_replace, html, flags=re.MULTILINE)

    # 引用
    quotes = {}

    def blockquote_replace(match):
        content = match.group(0)
        lines = content.split('\n')
        processed = []
        for line in lines:
            if line.startswith('>'):
                processed.append(line[1:].strip())
        quote_content = '<br>'.join(processed)
        placeholder = f"%%QUOTE{uuid.uuid4().hex}%%"
        quotes[placeholder] = f'<!-- wp:quote -->\n<blockquote class="wp-block-quote"><!-- wp:paragraph -->\n<p>{quote_content}</p>\n<!-- /wp:paragraph --></blockquote>\n<!-- /wp:quote -->'
        return placeholder

    html = re.sub(r'^(?:>.*\n?)+', blockquote_replace, html, flags=re.MULTILINE)

    # 內聯格式轉換函數（用於列表項目）
    def convert_inline_formats(text):
        # 粗體（先處理，避免被斜體規則吃掉）
        text = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', text)
        text = re.sub(r'__([^_]+)__', r'<strong>\1</strong>', text)
        # 斜體
        text = re.sub(r'(?<![*])\*([^*\n]+)\*(?![*])', r'<em>\1</em>', text)
        text = re.sub(r'(?<![_])_([^_\n]+)_(?![_])', r'<em>\1</em>', text)
        # 連結
        text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', text)
        return text

    # 巢狀列表處理
    lists = {}

    def get_indent_level(line):
        """計算縮排層級（每 2-4 個空格為一層）"""
        stripped = line.lstrip()
        indent = len(line) - len(stripped)
        return indent // 2

    def parse_list_line(line):
        """解析列表行，回傳 (類型, 內容) 或 None"""
        stripped = line.lstrip()
        ol_match = re.match(r'^(\d+)\.\s+(.*)$', stripped)
        if ol_match:
            return ('ol', ol_match.group(2))
        ul_match = re.match(r'^[\-\*]\s+(.*)$', stripped)
        if ul_match:
            return ('ul', ul_match.group(1))
        return None

    def parse_nested_list(lines, start_idx=0, base_indent=0):
        items = []
        i = start_idx

        while i < len(lines):
            line = lines[i]
            if not line.strip():
                i += 1
                continue

            current_indent = get_indent_level(line)

            if current_indent < base_indent:
                break

            parsed = parse_list_line(line)

            if parsed is None:
                if current_indent == base_indent:
                    break
                i += 1
                continue

            if current_indent > base_indent:
                i += 1
                continue

            list_type, content = parsed
            item = {
                'type': list_type,
                'content': convert_inline_formats(content),
                'children': []
            }

            i += 1
            if i < len(lines):
                next_line = lines[i]
                if next_line.strip():
                    next_indent = get_indent_level(next_line)
                    next_parsed = parse_list_line(next_line)
                    if next_indent > base_indent and next_parsed is not None:
                        children, i = parse_nested_list(lines, i, next_indent)
                        item['children'] = children

            items.append(item)

        return items, i

    def render_nested_list(items, is_top_level=True):
        """遞迴渲染巢狀列表為 WordPress HTML"""
        if not items:
            return ''

        first_type = items[0]['type']
        is_ordered = (first_type == 'ol')

        result = []

        if is_top_level:
            if is_ordered:
                result.append('<!-- wp:list {"ordered":true,"className":"wp-block-list"} -->')
                result.append('<ol class="wp-block-list">')
            else:
                result.append('<!-- wp:list {"className":"wp-block-list"} -->')
                result.append('<ul class="wp-block-list">')
        else:
            if is_ordered:
                result.append('<ol>')
            else:
                result.append('<ul>')

        for item in items:
            content = item['content']
            children = item['children']

            if children:
                result.append('<!-- wp:list-item -->')
                result.append(f'<li>{content}')
                result.append(render_nested_list(children, is_top_level=False))
                result.append('</li>')
                result.append('<!-- /wp:list-item -->')
            else:
                result.append('<!-- wp:list-item -->')
                result.append(f'<li>{content}</li>')
                result.append('<!-- /wp:list-item -->')

        if is_ordered:
            result.append('</ol>')
        else:
            result.append('</ul>')

        if is_top_level:
            result.append('<!-- /wp:list -->')

        return '\n'.join(result)

    def find_list_blocks(text):
        """找出所有列表區塊（包含巢狀）"""
        lines = text.split('\n')
        blocks = []
        i = 0

        while i < len(lines):
            line = lines[i]
            parsed = parse_list_line(line)

            if parsed is not None and get_indent_level(line) <= 1:
                block_start = i
                base_indent = get_indent_level(line)

                while i < len(lines):
                    current_line = lines[i]

                    if not current_line.strip():
                        j = i + 1
                        while j < len(lines) and not lines[j].strip():
                            j += 1
                        if j < len(lines):
                            next_parsed = parse_list_line(lines[j])
                            next_indent = get_indent_level(lines[j])
                            if next_parsed and next_indent >= base_indent:
                                i = j
                                continue
                        break

                    current_indent = get_indent_level(current_line)
                    current_parsed = parse_list_line(current_line)

                    if current_parsed is None and current_indent <= base_indent:
                        break

                    if current_parsed and current_indent < base_indent:
                        break

                    i += 1

                block_end = i
                block_lines = lines[block_start:block_end]
                blocks.append((block_start, block_end, block_lines))
            else:
                i += 1

        return blocks

    def process_all_lists(text):
        """處理所有列表區塊"""
        blocks = find_list_blocks(text)

        lines = text.split('\n')
        for start, end, block_lines in reversed(blocks):
            items, _ = parse_nested_list(block_lines, 0, get_indent_level(block_lines[0]))
            if items:
                html_output = render_nested_list(items)
                placeholder = f"%%LIST{uuid.uuid4().hex}%%"
                lists[placeholder] = html_output
                lines[start:end] = [placeholder]

        return '\n'.join(lines)

    html = process_all_lists(html)

    # 粗體
    html = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', html)
    html = re.sub(r'__([^_]+)__', r'<strong>\1</strong>', html)

    # 斜體
    html = re.sub(r'(?<!%)(?<![a-zA-Z0-9])\*([^*\n]+)\*(?![a-zA-Z0-9])(?!%)', r'<em>\1</em>', html)
    html = re.sub(r'(?<!%)(?<![a-zA-Z0-9])_([^_\n]+)_(?![a-zA-Z0-9])(?!%)', r'<em>\1</em>', html)

    # 連結
    html = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', html)

    # 圖片
    images = {}

    def image_replace(match):
        alt = match.group(1)
        url = match.group(2)
        placeholder = f"%%IMAGE{uuid.uuid4().hex}%%"
        images[placeholder] = f'<!-- wp:image -->\n<figure class="wp-block-image"><img src="{url}" alt="{alt}"/></figure>\n<!-- /wp:image -->'
        return placeholder

    html = re.sub(r'!\[([^\]]*)\]\(([^)]+)\)', image_replace, html)

    # 段落處理
    paragraphs = []
    current = []

    for line in html.split('\n'):
        stripped = line.strip()
        is_placeholder = (stripped.startswith('%%') and stripped.endswith('%%'))

        if is_placeholder or not stripped:
            if current:
                text = ' '.join(current)
                paragraphs.append(f'<!-- wp:paragraph -->\n<p>{text}</p>\n<!-- /wp:paragraph -->')
                current = []
            if stripped:
                paragraphs.append(line)
        else:
            current.append(stripped)

    if current:
        text = ' '.join(current)
        paragraphs.append(f'<!-- wp:paragraph -->\n<p>{text}</p>\n<!-- /wp:paragraph -->')

    html = '\n\n'.join(paragraphs)

    # 還原所有佔位符
    for placeholder, content in code_blocks.items():
        html = html.replace(placeholder, content)
    for placeholder, content in tables.items():
        html = html.replace(placeholder, content)
    for placeholder, content in headings.items():
        html = html.replace(placeholder, content)
    for placeholder, content in separators.items():
        html = html.replace(placeholder, content)
    for placeholder, content in quotes.items():
        html = html.replace(placeholder, content)
    for placeholder, content in lists.items():
        html = html.replace(placeholder, content)
    for placeholder, content in images.items():
        html = html.replace(placeholder, content)
    for placeholder, content in inline_codes.items():
        html = html.replace(placeholder, content)

    # 清理多餘空行
    html = re.sub(r'\n{3,}', '\n\n', html)

    return html.strip()


def read_markdown_file(file_path: str) -> tuple[str, str, dict]:
    """讀取 Markdown 檔案，提取標題和內容"""
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"找不到檔案: {file_path}")

    content = path.read_text(encoding='utf-8')
    front_matter = {}

    if content.startswith('---'):
        parts = content.split('---', 2)
        if len(parts) >= 3:
            yaml_content = parts[1].strip()
            content = parts[2].strip()

            for line in yaml_content.split('\n'):
                if ':' in line:
                    key, value = line.split(':', 1)
                    key = key.strip()
                    value = value.strip().strip('"\'')
                    if value.startswith('[') and value.endswith(']'):
                        value = [v.strip().strip('"\'') for v in value[1:-1].split(',')]
                    front_matter[key] = value

    title = front_matter.get('title', '')
    lines = content.split('\n')
    content_without_title = []

    for i, line in enumerate(lines):
        if not title and line.startswith('# ') and not line.startswith('## '):
            title = line[2:].strip()
        else:
            content_without_title.append(line)

    html_content = markdown_to_html('\n'.join(content_without_title))
    return title, html_content, front_matter


def publish_from_markdown(
    file_path: str,
    categories: list[str] = None,
    tags: list[str] = None,
    featured_image: str = None,
    excerpt: str = None,
    status: str = "publish"
) -> dict:
    """從 Markdown 檔案發布文章"""
    title, html_content, front_matter = read_markdown_file(file_path)

    if categories is None and 'categories' in front_matter:
        categories = front_matter['categories']
        if isinstance(categories, str):
            categories = [categories]

    if tags is None and 'tags' in front_matter:
        tags = front_matter['tags']
        if isinstance(tags, str):
            tags = [tags]

    if excerpt is None and 'excerpt' in front_matter:
        excerpt = front_matter['excerpt']

    if featured_image is None and 'featured_image' in front_matter:
        featured_image = front_matter['featured_image']

    return publish_tech_post(
        title=title,
        content=html_content,
        categories=categories,
        tags=tags,
        featured_image=featured_image,
        excerpt=excerpt,
        status=status
    )


def publish_tech_post(
    title: str,
    content: str,
    categories: list[str] = None,
    tags: list[str] = None,
    featured_image: str = None,
    excerpt: str = None,
    status: str = "publish"
) -> dict:
    """發布技術部落格文章"""
    result = {
        "success": False,
        "post": None,
        "categories_resolved": [],
        "tags_resolved": [],
        "featured_media": None,
        "errors": []
    }

    category_ids = []
    if categories:
        try:
            category_ids = resolve_categories(categories)
            result["categories_resolved"] = list(zip(categories, category_ids))
        except Exception as e:
            result["errors"].append(f"分類解析失敗: {e}")

    tag_ids = []
    if tags:
        try:
            tag_ids = resolve_tags(tags)
            result["tags_resolved"] = list(zip(tags, tag_ids))
        except Exception as e:
            result["errors"].append(f"標籤解析失敗: {e}")

    featured_media_id = None
    if featured_image:
        try:
            if featured_image.startswith(("http://", "https://")):
                media = upload_image_from_url(featured_image, alt_text=title)
            else:
                media = upload_image(featured_image, alt_text=title)
            featured_media_id = media["id"]
            result["featured_media"] = {"id": media["id"], "url": media["source_url"]}
        except Exception as e:
            result["errors"].append(f"封面圖上傳失敗: {e}")

    try:
        post = create_post(
            title=title,
            content=content,
            status=status,
            categories=category_ids if category_ids else None,
            tags=tag_ids if tag_ids else None,
            featured_media=featured_media_id,
            excerpt=excerpt
        )
        result["success"] = True
        result["post"] = {
            "id": post["id"],
            "title": post["title"]["rendered"],
            "link": post["link"],
            "status": post["status"]
        }
    except Exception as e:
        result["errors"].append(f"文章建立失敗: {e}")

    return result


def update_tech_post(
    post_id: int,
    title: str = None,
    content: str = None,
    categories: list[str] = None,
    tags: list[str] = None,
    featured_image: str = None,
    excerpt: str = None,
    status: str = None
) -> dict:
    """更新技術部落格文章"""
    result = {
        "success": False,
        "post": None,
        "categories_resolved": [],
        "tags_resolved": [],
        "featured_media": None,
        "errors": []
    }

    category_ids = None
    if categories is not None:
        try:
            category_ids = resolve_categories(categories)
            result["categories_resolved"] = list(zip(categories, category_ids))
        except Exception as e:
            result["errors"].append(f"分類解析失敗: {e}")

    tag_ids = None
    if tags is not None:
        try:
            tag_ids = resolve_tags(tags)
            result["tags_resolved"] = list(zip(tags, tag_ids))
        except Exception as e:
            result["errors"].append(f"標籤解析失敗: {e}")

    featured_media_id = None
    if featured_image:
        try:
            if featured_image.startswith(("http://", "https://")):
                media = upload_image_from_url(featured_image, alt_text=title or "")
            else:
                media = upload_image(featured_image, alt_text=title or "")
            featured_media_id = media["id"]
            result["featured_media"] = {"id": media["id"], "url": media["source_url"]}
        except Exception as e:
            result["errors"].append(f"封面圖上傳失敗: {e}")

    try:
        post = update_post(
            post_id=post_id,
            title=title,
            content=content,
            status=status,
            categories=category_ids,
            tags=tag_ids,
            featured_media=featured_media_id,
            excerpt=excerpt
        )
        result["success"] = True
        result["post"] = {
            "id": post["id"],
            "title": post["title"]["rendered"],
            "link": post["link"],
            "status": post["status"]
        }
    except Exception as e:
        result["errors"].append(f"文章更新失敗: {e}")

    return result


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("用法:")
        print("  python wp_publish.py publish --title <標題> --content <內容>")
        print("  python wp_publish.py publish-markdown <檔案路徑>")
        print("  python wp_publish.py update <post_id>")
        sys.exit(1)

    action = sys.argv[1]
    args = sys.argv[2:]

    def get_arg(name: str, default=None):
        try:
            idx = args.index(f"--{name}")
            return args[idx + 1]
        except (ValueError, IndexError):
            return default

    if action == "publish":
        title = get_arg("title")
        content = get_arg("content")
        if not title or not content:
            print("錯誤: --title 和 --content 為必填")
            sys.exit(1)
        result = publish_tech_post(
            title=title,
            content=content,
            categories=get_arg("categories").split(",") if get_arg("categories") else None,
            tags=get_arg("tags").split(",") if get_arg("tags") else None,
            featured_image=get_arg("featured-image"),
            excerpt=get_arg("excerpt"),
            status=get_arg("status", "publish")
        )
        print(json.dumps(result, indent=2, ensure_ascii=False))

    elif action == "publish-markdown":
        if not args:
            print("錯誤: 請提供 Markdown 檔案路徑")
            sys.exit(1)
        file_path = args[0]
        args = args[1:]
        result = publish_from_markdown(
            file_path=file_path,
            categories=get_arg("categories").split(",") if get_arg("categories") else None,
            tags=get_arg("tags").split(",") if get_arg("tags") else None,
            featured_image=get_arg("featured-image"),
            excerpt=get_arg("excerpt"),
            status=get_arg("status", "publish")
        )
        print(json.dumps(result, indent=2, ensure_ascii=False))

    elif action == "update":
        post_id = int(args[0])
        args = args[1:]
        result = update_tech_post(
            post_id=post_id,
            title=get_arg("title"),
            content=get_arg("content"),
            categories=get_arg("categories").split(",") if get_arg("categories") else None,
            tags=get_arg("tags").split(",") if get_arg("tags") else None,
            featured_image=get_arg("featured-image"),
            excerpt=get_arg("excerpt"),
            status=get_arg("status")
        )
        print(json.dumps(result, indent=2, ensure_ascii=False))
