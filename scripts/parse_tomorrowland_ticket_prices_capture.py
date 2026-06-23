from __future__ import annotations

import argparse
import csv
import json
import re
from html import unescape
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RAW_DIR = PROJECT_ROOT / "data" / "raw" / "passes_packages_capture_2025"
DEFAULT_OUT_DIR = PROJECT_ROOT / "data" / "processed"


NEXT_DATA_RE = re.compile(
    r'<script[^>]+id=["\']__NEXT_DATA__["\'][^>]*>(.*?)</script>',
    re.IGNORECASE | re.DOTALL,
)


def capture_timestamp(text: str) -> str:
    match = re.search(r"web[_/](20\d{12})", text)
    if match:
        return match.group(1)
    match = re.search(r"wayback_(20\d{12})", text)
    return match.group(1) if match else ""


def read_payload(path: Path) -> Any | None:
    text = path.read_text(encoding="utf-8", errors="replace").strip()
    if not text:
        return None
    if text.startswith("{") or text.startswith("["):
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            return None
    match = NEXT_DATA_RE.search(text)
    if not match:
        return None
    try:
        return json.loads(unescape(match.group(1)))
    except json.JSONDecodeError:
        return None


def source_url_from_path(path: Path) -> str:
    text = path.read_text(encoding="utf-8", errors="ignore")
    match = re.search(r'"page_url","response_url"', text)
    if match:
        return ""
    url_match = re.search(r"https://web\.archive\.org/web/20\d{12}/https://belgium\.tomorrowland\.com/[^\"'< )]+", text)
    if url_match:
        return url_match.group(0)
    name = path.name
    match = re.search(r"Tomorrowland_(https_web\.archive\.org_web_20\d{12}_[^.]+)", name)
    if not match:
        return ""
    encoded = match.group(1).removesuffix(".txt")
    return (
        encoded.replace("_https_", "/https://")
        .replace("https_web.archive.org_web_", "https://web.archive.org/web/")
        .replace("_", "/")
    )


def find_doc(payload: Any) -> dict[str, Any]:
    if not isinstance(payload, dict):
        return {}
    props = payload.get("props") or payload.get("pageProps") or {}
    if isinstance(props, dict):
        page_props = props.get("pageProps") if "pageProps" in props else props
        if isinstance(page_props, dict) and isinstance(page_props.get("doc"), dict):
            return page_props["doc"]
    return {}


def iter_dicts(value: Any):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from iter_dicts(child)
    elif isinstance(value, list):
        for child in value:
            yield from iter_dicts(child)


def normalize_price(price: Any) -> tuple[str, str, str]:
    if isinstance(price, dict):
        value = price.get("value")
        formatted = price.get("formatted") or ""
        currency = price.get("iso") or "EUR"
        if isinstance(value, (int, float)):
            return f"{value:.2f}", str(formatted), str(currency)
        no_symbol = price.get("formatted_no_symbol")
        if no_symbol:
            return str(no_symbol), str(formatted), str(currency)
    return "", "", ""


def extract_rows(path: Path) -> list[dict[str, str]]:
    payload = read_payload(path)
    doc = find_doc(payload)
    if not doc:
        return []

    timestamp = capture_timestamp(str(path))
    page_title = str(doc.get("title") or "")
    page_url = str(doc.get("url") or "")
    source_url = source_url_from_path(path)
    rows: list[dict[str, str]] = []
    seen: set[tuple[str, str, str, str]] = set()

    for item in iter_dicts(doc.get("blocks", [])):
        if item.get("type") != "product_prices":
            continue
        product_name = str(item.get("title") or "")
        product_id = str(item.get("id") or "")
        for price_row in item.get("prices") or []:
            if not isinstance(price_row, dict):
                continue
            price_value, formatted, currency = normalize_price(price_row.get("price"))
            if not price_value:
                continue
            category = price_row.get("category") or {}
            if isinstance(category, dict):
                sale_category = str(category.get("title") or price_row.get("title") or "")
            else:
                sale_category = str(price_row.get("title") or "")
            key = (product_name, sale_category, price_value, source_url)
            if key in seen:
                continue
            seen.add(key)
            rows.append(
                {
                    "festival": "Tomorrowland",
                    "edition_year": "2025",
                    "ticket_name": product_name,
                    "sale_category": sale_category,
                    "price_eur": price_value,
                    "currency": currency,
                    "formatted_price": formatted,
                    "price_status": str((price_row.get("price_status") or {}).get("label") or ""),
                    "page_title": page_title,
                    "page_url": page_url,
                    "official_product_id": product_id,
                    "official_price_id": str(price_row.get("id") or ""),
                    "capture_timestamp": timestamp,
                    "source_file": str(path),
                    "source_url_hint": source_url,
                    "confidence": "official_wayback_structured",
                }
            )
    return rows


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    fieldnames = [
        "festival",
        "edition_year",
        "ticket_name",
        "sale_category",
        "price_eur",
        "currency",
        "formatted_price",
        "price_status",
        "page_title",
        "page_url",
        "official_product_id",
        "official_price_id",
        "capture_timestamp",
        "source_file",
        "source_url_hint",
        "confidence",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Parse Tomorrowland 2025 Wayback pass/package pages into official ticket price CSV."
    )
    parser.add_argument("--raw-dir", type=Path, default=DEFAULT_RAW_DIR)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    args = parser.parse_args()

    rows_by_key: dict[tuple[str, str, str, str], dict[str, str]] = {}
    for path in args.raw_dir.resolve().rglob("*.txt"):
        for row in extract_rows(path):
            key = (
                row["ticket_name"],
                row["sale_category"],
                row["price_eur"],
                row["official_price_id"],
            )
            rows_by_key[key] = row

    rows = sorted(
        rows_by_key.values(),
        key=lambda row: (
            row["page_title"],
            row["ticket_name"],
            row["sale_category"],
            row["price_eur"],
        ),
    )
    out_path = args.out_dir.resolve() / "tomorrowland_2025_ticket_prices_official_wayback.csv"
    write_csv(out_path, rows)
    print(f"Ticket price rows: {len(rows)}")
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
