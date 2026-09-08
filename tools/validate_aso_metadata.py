#!/usr/bin/env python3
import json
from pathlib import Path

PATH = Path("store/aso/metadata.json")
REQUIRED = {"ja-JP", "en-US", "zh-CN", "zh-TW", "ko-KR", "fr-FR", "es-ES"}
CHAR_LIMITS = {
    ("appStore", "name"): 30,
    ("appStore", "subtitle"): 30,
    ("appStore", "promotionalText"): 170,
    ("appStore", "description"): 4000,
    ("googlePlay", "title"): 30,
    ("googlePlay", "shortDescription"): 80,
    ("googlePlay", "fullDescription"): 4000,
}
APPLE_KEYWORD_BYTE_LIMIT = 100


def fail(message: str) -> None:
    raise SystemExit(f"ASO metadata validation failed: {message}")


data = json.loads(PATH.read_text(encoding="utf-8"))
locales = data.get("locales", {})
if set(locales) != REQUIRED:
    fail(f"locale set mismatch: expected {sorted(REQUIRED)}, got {sorted(locales)}")

for locale, entry in locales.items():
    for (store, field), limit in CHAR_LIMITS.items():
        value = entry.get(store, {}).get(field)
        if not isinstance(value, str) or not value.strip():
            fail(f"{locale}.{store}.{field} is missing")
        if len(value) > limit:
            fail(f"{locale}.{store}.{field} is {len(value)} chars; limit is {limit}")
        if "http://" in value or "https://" in value:
            fail(f"{locale}.{store}.{field} contains a URL; keep store copy URL-free")

    keyword_value = entry.get("appStore", {}).get("keywords")
    if not isinstance(keyword_value, str) or not keyword_value.strip():
        fail(f"{locale}.appStore.keywords is missing")
    keyword_bytes = len(keyword_value.encode("utf-8"))
    if keyword_bytes > APPLE_KEYWORD_BYTE_LIMIT:
        fail(
            f"{locale}.appStore.keywords is {keyword_bytes} UTF-8 bytes; "
            f"limit is {APPLE_KEYWORD_BYTE_LIMIT}"
        )
    keywords = [item.strip().casefold() for item in keyword_value.split(",")]
    if any(not item for item in keywords):
        fail(f"{locale}.appStore.keywords contains an empty keyword")
    if len(keywords) != len(set(keywords)):
        fail(f"{locale}.appStore.keywords contains duplicate keywords")

    if entry["appStore"]["name"] != "NIARIM" or entry["googlePlay"]["title"] != "NIARIM":
        fail(f"{locale}: product name must stay NIARIM")

print(f"ASO metadata validation passed for {len(locales)} locales")
