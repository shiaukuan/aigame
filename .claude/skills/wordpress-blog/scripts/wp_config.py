#!/usr/bin/env python3
"""
WordPress API 設定與認證模組
使用 Application Password 進行 REST API 認證
"""
import os
import base64
from pathlib import Path
from dataclasses import dataclass
from dotenv import load_dotenv

_env_path = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(_env_path)


@dataclass
class WPConfig:
    """WordPress 設定"""
    base_url: str
    username: str
    app_password: str

    @property
    def api_url(self) -> str:
        """回傳 REST API 基底 URL"""
        return f"{self.base_url.rstrip(chr(47))}/wp-json/wp/v2"

    @property
    def auth_header(self) -> dict:
        """回傳 Basic Auth Header"""
        password = self.app_password.replace(" ", "")
        credentials = f"{self.username}:{password}"
        token = base64.b64encode(credentials.encode()).decode()
        return {"Authorization": f"Basic {token}"}

    @classmethod
    def from_env(cls) -> "WPConfig":
        """從環境變數讀取設定"""
        return cls(
            base_url=os.environ["WP_BASE_URL"],
            username=os.environ["WP_USERNAME"],
            app_password=os.environ["WP_APP_PASSWORD"]
        )


def get_config() -> WPConfig:
    """取得 WordPress 設定（優先使用環境變數）"""
    return WPConfig.from_env()
