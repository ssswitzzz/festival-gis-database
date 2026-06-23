from __future__ import annotations

import argparse
import csv
import re
from html import unescape
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RAW_DIR = PROJECT_ROOT / "data" / "raw" / "defqon_capture_2025"
DEFAULT_OUT_DIR = PROJECT_ROOT / "data" / "processed"


TITLE_RE = re.compile(r"<title>(.*?)</title>", re.IGNORECASE | re.DOTALL)
META_RE = re.compile(
    r'<meta[^>]+(?:name|property)=["\'](?P<name>description|og:description|og:url|og:title)["\'][^>]+content=["\'](?P<content>.*?)["\']',
    re.IGNORECASE | re.DOTALL,
)
ROUTE_RE = re.compile(r'routePath:"(?P<route>\\u002F[^"]+)"')
TIMESTAMP_RE = re.compile(r"(?:web_|web/|wayback_)(20\d{12})")
SOURCE_URL_RE = re.compile(
    r"https://web\.archive\.org/web/(20\d{12})/https://www\.q-dance\.com/l/[^\"'< )]+"
)
DATE_RE = re.compile(
    r"\b(?:June|July|August|September)\s+\d{1,2}\s*[-–]\s*\d{1,2}\b",
    re.IGNORECASE,
)
SHOP_RE = re.compile(
    r"https:\\u002F\\u002F(?:web\.archive\.org\\u002Fweb\\u002F20\d{12}\\u002Fhttps:\\u002F\\u002F)?(?:shop\.q-dance\.com|account\.paylogic\.com|customerservice\.paylogic\.com|personalize\.paylogic\.com)[^\"'\\< )]+|"
    r"https://(?:shop\.q-dance\.com|account\.paylogic\.com|customerservice\.paylogic\.com|personalize\.paylogic\.com)[^\"'< )]+",
    re.IGNORECASE,
)
PRICE_RE = re.compile(r"(?:€|EUR)\s*\d{1,4}(?:[.,]\d{2})?|\d{1,4}(?:[.,]\d{2})?\s*(?:€|EUR)", re.IGNORECASE)


TICKET_TERMS = [
    "Weekend Ticket",
    "Weekend Tickets",
    "Day Tickets",
    "Premium Weekend Ticket",
    "Premium",
    "Regular",
    "Friday",
    "Saturday",
    "Sunday",
    "sold out",
]


def clean(value: str) -> str:
    value = value.replace("\\u002F", "/").replace("\\u0026", "&")
    value = value.replace("&amp;", "&")
    return re.sub(r"\s+", " ", unescape(value)).strip()


def capture_timestamp(path: Path, text: str) -> str:
    match = TIMESTAMP_RE.search(str(path)) or TIMESTAMP_RE.search(text)
    return match.group(1) if match else ""


def source_url(text: str, path: Path) -> str:
    match = SOURCE_URL_RE.search(text)
    if match:
        return re.sub(r"^https://web\.archive\.org/web/20\d{12}/", "", match.group(0))
    name_match = re.search(r"www\.q-dance\.com_l_([^\\]+?)\.txt$", path.name)
    if name_match:
        return f"https://www.q-dance.com/l/{name_match.group(1)}"
    return ""


def html_title(text: str) -> str:
    match = TITLE_RE.search(text)
    return clean(match.group(1)) if match else ""


def meta_values(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for match in META_RE.finditer(text):
        values[match.group("name").lower()] = clean(match.group("content"))
    return values


def route_path(text: str) -> str:
    match = ROUTE_RE.search(text)
    return clean(match.group("route")) if match else ""


def page_slug(source: str, route: str) -> str:
    path = route or source
    match = re.search(r"/l/([^/?#]+)", path)
    return match.group(1) if match else ""


def festival_year(*values: str) -> str:
    joined = " ".join(values)
    match = re.search(r"Defqon\.1[^0-9]{0,30}(20\d{2})|(?:Festival|Tickets)[^0-9]{0,30}(20\d{2})", joined, re.I)
    if match:
        return next(group for group in match.groups() if group)
    match = re.search(r"\b(20\d{2})\b", joined)
    return match.group(1) if match else ""


def unique_join(values: list[str]) -> str:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        value = clean(value)
        if value and value not in seen:
            seen.add(value)
            result.append(value)
    return "|".join(result)


def normalize_link(link: str) -> str:
    link = clean(link)
    link = re.sub(r"^https://web\.archive\.org/web/20\d{12}/", "", link)
    return link.rstrip("\\")


def extract_row(path: Path) -> dict[str, str] | None:
    text = path.read_text(encoding="utf-8", errors="replace")
    if "q-dance.com/l/" not in text and "Defqon.1" not in text:
        return None

    meta = meta_values(text)
    source = source_url(text, path)
    if "q-dance.com/l/" not in source:
        return None

    title = html_title(text)
    description = meta.get("description") or meta.get("og:description") or ""
    route = route_path(text)
    slug = page_slug(source, route)
    year = festival_year(title, description, slug)
    dates = unique_join([match.group(0) for match in DATE_RE.finditer(text)])
    ticket_terms = unique_join([term for term in TICKET_TERMS if re.search(re.escape(term), text, re.I)])
    shop_links = unique_join([normalize_link(match.group(0)) for match in SHOP_RE.finditer(text)])
    price_candidates = unique_join([match.group(0) for match in PRICE_RE.finditer(text)])
    confidence = "official_wayback_page" if year == "2025" else "legacy_or_year_mismatch"
    if not price_candidates:
        price_note = "captured_page_has_no_explicit_price"
    else:
        price_note = "price_candidate_needs_review"

    return {
        "festival": "Defqon.1",
        "edition_year": "2025",
        "source_url": source,
        "capture_timestamp": capture_timestamp(path, text),
        "page_slug": slug,
        "html_title": title,
        "page_title": meta.get("og:title") or title,
        "page_festival_year": year,
        "description": description,
        "date_candidates": dates,
        "ticket_terms": ticket_terms,
        "shop_or_paylogic_links": shop_links,
        "price_candidates": price_candidates,
        "price_note": price_note,
        "confidence": confidence,
        "source_file": str(path),
    }


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    fieldnames = [
        "festival",
        "edition_year",
        "source_url",
        "capture_timestamp",
        "page_slug",
        "html_title",
        "page_title",
        "page_festival_year",
        "description",
        "date_candidates",
        "ticket_terms",
        "shop_or_paylogic_links",
        "price_candidates",
        "price_note",
        "confidence",
        "source_file",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description="Parse Defqon.1 2025 Wayback page captures.")
    parser.add_argument("--raw-dir", type=Path, default=DEFAULT_RAW_DIR)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    args = parser.parse_args()

    rows_by_key: dict[tuple[str, str], dict[str, str]] = {}
    for path in args.raw_dir.resolve().rglob("*.txt"):
        row = extract_row(path)
        if row:
            rows_by_key[(row["source_url"], row["capture_timestamp"])] = row

    rows = sorted(rows_by_key.values(), key=lambda row: (row["confidence"], row["source_url"], row["capture_timestamp"]))
    out_path = args.out_dir.resolve() / "defqon_2025_wayback_page_facts.csv"
    write_csv(out_path, rows)
    print(f"Defqon page fact rows: {len(rows)}")
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
