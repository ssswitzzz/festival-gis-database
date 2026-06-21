#!/usr/bin/env python3
"""
Fetch official festival pages and extract auditable business-data candidates.

The scraper intentionally writes raw pages plus candidate CSVs instead of
updating production tables directly. Official festival pages are dynamic and
change often, so every extracted value should remain traceable to a source URL
and evidence snippet before it is imported into the coursework database.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import html
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Dict, Iterable, List


USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/126 Safari/537.36 festival-gis-coursework-scraper/1.0"
)

MONTHS = (
    "January|February|March|April|May|June|July|August|September|October|November|December|"
    "Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec"
)

DATE_PATTERNS = [
    re.compile(rf"\b(?:{MONTHS})\s+\d{{1,2}}(?:\s*[-\u2013\u2014]\s*\d{{1,2}})?(?:,\s*)?\s*20\d{{2}}\b", re.I),
    re.compile(rf"\b\d{{1,2}}\s+(?:{MONTHS})(?:\s*[-\u2013\u2014]\s*\d{{1,2}}\s+(?:{MONTHS}))?\s+20\d{{2}}\b", re.I),
    re.compile(r"\b20\d{2}[-/]\d{1,2}[-/]\d{1,2}\b"),
    re.compile(r"\b\d{1,2}[-/]\d{1,2}[-/]20\d{2}\b"),
]

PRICE_PATTERN = re.compile(
    r"(?P<currency>\u20ac|EUR|eur)\s*(?P<amount>\d{1,4}(?:[.,]\d{2})?)|"
    r"(?P<amount2>\d{1,4}(?:[.,]\d{2})?)\s*(?P<currency2>\u20ac|EUR|eur)",
    re.I,
)

ATTENDANCE_PATTERN = re.compile(
    r"\b(?P<number>\d{1,3}(?:[.,]\d{3})+|\d{4,6})\s+"
    r"(?P<label>visitors|attendees|people|festivalgoers|guests|fans|bezoekers)\b",
    re.I,
)

LINEUP_CONTEXT_PATTERN = re.compile(
    r"\b(line[- ]?up|artists?|timetable|schedule|stages?)\b",
    re.I,
)

SCRIPT_JSON_RE = re.compile(
    r"<script[^>]+type=[\"']application/ld\+json[\"'][^>]*>(.*?)</script>",
    re.I | re.S,
)

TAG_RE = re.compile(r"<[^>]+>")
SPACE_RE = re.compile(r"\s+")


def now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def safe_name(text: str, max_len: int = 90) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "_", text).strip("_")
    return cleaned[:max_len] or "page"


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def read_json(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def fetch_url(url: str, timeout: int) -> Dict[str, Any]:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept-Language": "en-US,en;q=0.9"})
    started = time.time()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read()
            final_url = response.geturl()
            content_type = response.headers.get("content-type", "")
            status = getattr(response, "status", 200)
    except urllib.error.HTTPError as exc:
        body = exc.read()
        final_url = exc.geturl()
        content_type = exc.headers.get("content-type", "") if exc.headers else ""
        status = exc.code
    return {
        "url": url,
        "final_url": final_url,
        "status": status,
        "content_type": content_type,
        "elapsed_seconds": round(time.time() - started, 3),
        "body": body,
    }


def decode_body(body: bytes, content_type: str) -> str:
    charset = "utf-8"
    match = re.search(r"charset=([\w-]+)", content_type or "", re.I)
    if match:
        charset = match.group(1)
    try:
        return body.decode(charset, errors="replace")
    except LookupError:
        return body.decode("utf-8", errors="replace")


def page_text(markup: str) -> str:
    without_scripts = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", markup, flags=re.I | re.S)
    text = TAG_RE.sub(" ", without_scripts)
    return SPACE_RE.sub(" ", html.unescape(text)).strip()


def snippet(text: str, start: int, end: int, radius: int = 90) -> str:
    left = max(0, start - radius)
    right = min(len(text), end + radius)
    return text[left:right].strip()


def flatten_json(value: Any) -> Iterable[Any]:
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from flatten_json(child)
    elif isinstance(value, list):
        for item in value:
            yield from flatten_json(item)


def extract_json_ld(markup: str) -> List[Dict[str, Any]]:
    items: List[Dict[str, Any]] = []
    for match in SCRIPT_JSON_RE.finditer(markup):
        raw = html.unescape(match.group(1)).strip()
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            continue
        for item in flatten_json(parsed):
            if isinstance(item, dict):
                items.append(item)
    return items


def add_fact(facts: List[Dict[str, Any]], **kwargs: Any) -> None:
    kwargs.setdefault("confidence", "candidate")
    kwargs.setdefault("evidence", "")
    facts.append(kwargs)


def extract_date_candidates(text: str, base: Dict[str, Any]) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    seen = set()
    for pattern in DATE_PATTERNS:
        for match in pattern.finditer(text):
            value = match.group(0)
            key = value.lower()
            if key in seen:
                continue
            seen.add(key)
            add_fact(
                rows,
                **base,
                fact_type="date_candidate",
                value=value,
                year_matches_edition=str(base["edition_year"]) in value,
                evidence=snippet(text, match.start(), match.end()),
            )
    return rows


def extract_price_candidates(text: str, base: Dict[str, Any]) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    seen = set()
    for match in PRICE_PATTERN.finditer(text):
        amount = match.group("amount") or match.group("amount2")
        currency = match.group("currency") or match.group("currency2") or "EUR"
        amount_norm = amount.replace(",", ".")
        context = snippet(text, match.start(), match.end(), 140)
        if not re.search(r"\b(ticket|pass|package|camping|day|weekend|price|sale|shop|regular|comfort|madness|premium)\b", context, re.I):
            continue
        key = (amount_norm, context.lower()[:80])
        if key in seen:
            continue
        seen.add(key)
        rows.append({
            **base,
            "ticket_name": infer_ticket_name(context),
            "price_eur": amount_norm,
            "currency": "EUR" if currency == "\u20ac" else currency.upper(),
            "evidence": context,
            "confidence": "candidate",
        })
    return rows


def infer_ticket_name(context: str) -> str:
    patterns = [
        r"([A-Z][A-Za-z0-9& +'-]{2,60}\s+(?:Pass|Ticket|Package|Upgrade))",
        r"((?:Full Madness|Day Pass|Weekend Ticket|Premium Weekend|DreamVille|Camping)[A-Za-z0-9& +'-]{0,40})",
    ]
    for pattern in patterns:
        match = re.search(pattern, context)
        if match:
            return SPACE_RE.sub(" ", match.group(1)).strip(" -:")
    return "ticket_price_candidate"


def extract_attendance_candidates(text: str, base: Dict[str, Any]) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    seen = set()
    for match in ATTENDANCE_PATTERN.finditer(text):
        value = f"{match.group('number')} {match.group('label')}"
        if value.lower() in seen:
            continue
        seen.add(value.lower())
        add_fact(
            rows,
            **base,
            fact_type="attendance_candidate",
            value=value,
            evidence=snippet(text, match.start(), match.end(), 140),
        )
    return rows


def extract_lineup_candidates(text: str, base: Dict[str, Any]) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    if not LINEUP_CONTEXT_PATTERN.search(text):
        return rows

    known_artists = [
        "Armin van Buuren",
        "Charlotte de Witte",
        "Martin Garrix",
        "Amelie Lens",
        "Hardwell",
        "Sub Zero Project",
        "Angerfist",
        "Reinier Zonneveld",
        "Indira Paganotto",
        "Tiësto",
        "David Guetta",
        "Afrojack",
        "Dimitri Vegas",
        "Like Mike",
    ]
    seen = set()
    for artist in known_artists:
        match = re.search(re.escape(artist), text, re.I)
        if match and artist.lower() not in seen:
            seen.add(artist.lower())
            rows.append({
                **base,
                "artist_name": artist,
                "stage_name": "",
                "start_time": "",
                "end_time": "",
                "evidence": snippet(text, match.start(), match.end(), 120),
                "confidence": "candidate",
            })

    # Generic artist-name fallback near lineup-related sections. Conservative by design.
    for context_match in LINEUP_CONTEXT_PATTERN.finditer(text):
        window = text[context_match.start(): min(len(text), context_match.start() + 2500)]
        for name_match in re.finditer(r"\b[A-Z][A-Za-zÀ-ÿ0-9'&.-]+(?:\s+[A-Z][A-Za-zÀ-ÿ0-9'&.-]+){1,4}\b", window):
            name = name_match.group(0)
            if any(skip in name.lower() for skip in ("line up", "buy tickets", "privacy policy", "terms conditions")):
                continue
            if name.lower() in seen:
                continue
            seen.add(name.lower())
            rows.append({
                **base,
                "artist_name": name,
                "stage_name": "",
                "start_time": "",
                "end_time": "",
                "evidence": snippet(window, name_match.start(), name_match.end(), 80),
                "confidence": "low_candidate",
            })
            if len(rows) >= 80:
                return rows
    return rows


def extract_jsonld_event_facts(items: List[Dict[str, Any]], base: Dict[str, Any]) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for item in items:
        item_type = item.get("@type")
        if isinstance(item_type, list):
            is_event = any(str(t).lower() == "event" for t in item_type)
        else:
            is_event = str(item_type).lower() == "event"
        if not is_event:
            continue
        for key in ("name", "startDate", "endDate", "eventAttendanceMode"):
            if item.get(key):
                add_fact(
                    rows,
                    **base,
                    fact_type=f"jsonld_{key}",
                    value=str(item.get(key)),
                    confidence="structured",
                    evidence=json.dumps({key: item.get(key)}, ensure_ascii=False),
                )
        offers = item.get("offers")
        for offer in flatten_json(offers):
            if not isinstance(offer, dict):
                continue
            if offer.get("price"):
                rows.append({
                    **base,
                    "ticket_name": str(offer.get("name") or offer.get("@type") or "jsonld_offer"),
                    "price_eur": str(offer.get("price")),
                    "currency": str(offer.get("priceCurrency") or "EUR"),
                    "evidence": json.dumps(offer, ensure_ascii=False)[:500],
                    "confidence": "structured",
                })
    return rows


def write_csv(path: Path, rows: List[Dict[str, Any]], fieldnames: List[str]) -> None:
    ensure_dir(path.parent)
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def process_page(page: Dict[str, Any], festival_cfg: Dict[str, Any], raw_dir: Path, processed_rows: Dict[str, List[Dict[str, Any]]]) -> None:
    body = page["body"]
    content_hash = hashlib.sha256(body).hexdigest()[:16]
    festival = festival_cfg["festival"]
    label = page["label"]
    filename = f"{safe_name(festival)}_{festival_cfg['edition_year']}_{safe_name(label)}_{content_hash}.html"
    html_path = raw_dir / filename
    html_path.write_bytes(body)

    metadata = {
        "festival": festival,
        "edition_year": festival_cfg["edition_year"],
        "label": label,
        "url": page["url"],
        "final_url": page["final_url"],
        "status": page["status"],
        "content_type": page["content_type"],
        "elapsed_seconds": page["elapsed_seconds"],
        "saved_html": str(html_path),
        "content_hash": content_hash,
        "scraped_at": page["scraped_at"],
    }
    (raw_dir / f"{html_path.stem}.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    processed_rows["pages"].append(metadata)

    if int(page["status"]) >= 400:
        return

    markup = decode_body(body, page["content_type"])
    text = page_text(markup)
    base = {
        "festival": festival,
        "edition_year": festival_cfg["edition_year"],
        "source_label": label,
        "source_url": page["final_url"],
        "scraped_at": page["scraped_at"],
    }

    jsonld_items = extract_json_ld(markup)
    jsonld_rows = extract_jsonld_event_facts(jsonld_items, base)
    for row in jsonld_rows:
        if "ticket_name" in row:
            processed_rows["tickets"].append(row)
        else:
            processed_rows["facts"].append(row)

    processed_rows["facts"].extend(extract_date_candidates(text, base))
    processed_rows["facts"].extend(extract_attendance_candidates(text, base))
    processed_rows["tickets"].extend(extract_price_candidates(text, base))
    processed_rows["lineup"].extend(extract_lineup_candidates(text, base))


def iter_targets(config: Dict[str, Any], only_festival: str | None) -> Iterable[Dict[str, Any]]:
    for festival in config.get("festivals", []):
        if only_festival and festival.get("festival", "").lower() != only_festival.lower():
            continue
        yield festival


def main() -> int:
    parser = argparse.ArgumentParser(description="Scrape official business-data candidates for EDM festivals.")
    parser.add_argument("--sources", default="data/sources/festival_business_sources.json", help="JSON source config.")
    parser.add_argument("--raw-dir", default="data/raw/festival_business_pages", help="Directory for raw HTML and page metadata.")
    parser.add_argument("--processed-dir", default="data/processed", help="Directory for extracted CSV files.")
    parser.add_argument("--festival", help="Optional exact festival name filter.")
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--delay", type=float, default=1.0)
    parser.add_argument("--offline", action="store_true", help="Do not fetch. Reserved for future parsing of saved pages.")
    args = parser.parse_args()

    if args.offline:
        raise SystemExit("--offline parsing is not implemented yet; run without --offline to fetch configured pages.")

    source_path = Path(args.sources)
    raw_dir = Path(args.raw_dir)
    processed_dir = Path(args.processed_dir)
    ensure_dir(raw_dir)
    ensure_dir(processed_dir)

    config = read_json(source_path)
    rows: Dict[str, List[Dict[str, Any]]] = {"pages": [], "facts": [], "tickets": [], "lineup": []}

    for festival in iter_targets(config, args.festival):
        for target in festival.get("urls", []):
            scraped_at = now_iso()
            page = fetch_url(target["url"], args.timeout)
            page.update({"label": target["label"], "scraped_at": scraped_at})
            process_page(page, festival, raw_dir, rows)
            time.sleep(args.delay)

    write_csv(
        processed_dir / "business_scrape_pages.csv",
        rows["pages"],
        ["festival", "edition_year", "label", "url", "final_url", "status", "content_type", "elapsed_seconds", "saved_html", "content_hash", "scraped_at"],
    )
    write_csv(
        processed_dir / "business_fact_candidates.csv",
        rows["facts"],
        ["festival", "edition_year", "source_label", "source_url", "fact_type", "value", "year_matches_edition", "confidence", "evidence", "scraped_at"],
    )
    write_csv(
        processed_dir / "business_ticket_candidates.csv",
        rows["tickets"],
        ["festival", "edition_year", "source_label", "source_url", "ticket_name", "price_eur", "currency", "confidence", "evidence", "scraped_at"],
    )
    write_csv(
        processed_dir / "business_lineup_candidates.csv",
        rows["lineup"],
        ["festival", "edition_year", "source_label", "source_url", "artist_name", "stage_name", "start_time", "end_time", "confidence", "evidence", "scraped_at"],
    )

    print(f"Saved raw pages to {raw_dir}")
    print(f"Pages: {len(rows['pages'])}")
    print(f"Fact candidates: {len(rows['facts'])}")
    print(f"Ticket candidates: {len(rows['tickets'])}")
    print(f"Lineup candidates: {len(rows['lineup'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
