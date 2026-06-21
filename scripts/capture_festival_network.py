#!/usr/bin/env python3
"""
Capture browser network traffic from festival pages.

Use this when ticket prices, lineups or timetables are loaded by JavaScript and
do not appear in the static HTML scraper output. It requires Playwright:

    python -m pip install playwright
    python -m playwright install chromium

On Windows, you can usually skip the Chromium download and use installed Edge:

    python scripts/capture_festival_network.py --channel msedge ...

The script saves response metadata and JSON/text snippets. It does not bypass
logins, paywalls or access controls.
"""

from __future__ import annotations

import argparse
import asyncio
import csv
import datetime as dt
import json
import re
from pathlib import Path
from typing import Any, Dict, List


INTERESTING_URL_RE = re.compile(
    r"(ticket|price|shop|cart|line[-_]?up|lineup|artist|timetable|schedule|event|program|performance)",
    re.I,
)

PRICE_RE = re.compile(r"(\u20ac|EUR)\s*\d{1,4}(?:[.,]\d{2})?|\d{1,4}(?:[.,]\d{2})?\s*(\u20ac|EUR)", re.I)
DATE_RE = re.compile(r"20\d{2}-\d{1,2}-\d{1,2}|\b\d{1,2}[/-]\d{1,2}[/-]20\d{2}\b")


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def safe_name(text: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", text).strip("_")[:100] or "capture"


def flatten(value: Any) -> str:
    if isinstance(value, (dict, list)):
        return json.dumps(value, ensure_ascii=False)
    return str(value)


def candidate_rows_from_payload(payload: str, source: Dict[str, Any]) -> List[Dict[str, str]]:
    rows: List[Dict[str, str]] = []
    for regex, fact_type in ((PRICE_RE, "price_candidate"), (DATE_RE, "date_candidate")):
        for match in regex.finditer(payload):
            start = max(0, match.start() - 120)
            end = min(len(payload), match.end() + 120)
            value = match.group(0)
            rows.append({
                **source,
                "fact_type": fact_type,
                "value": value,
                "year_matches_edition": str(source["edition_year"]) in value,
                "evidence": payload[start:end],
            })
    return rows


async def main() -> int:
    parser = argparse.ArgumentParser(description="Capture dynamic festival webpage network responses.")
    parser.add_argument("--url", required=True)
    parser.add_argument("--festival", required=True)
    parser.add_argument("--edition-year", type=int, required=True)
    parser.add_argument("--out-dir", default="data/raw/festival_network_capture")
    parser.add_argument("--processed-dir", default="data/processed")
    parser.add_argument("--wait-ms", type=int, default=10000)
    parser.add_argument("--headed", action="store_true", help="Show browser window for manual cookie/ticket interactions.")
    parser.add_argument("--keep-open", action="store_true", help="Keep headed browser open until Enter is pressed in the terminal.")
    parser.add_argument("--channel", help="Playwright browser channel, for example msedge or chrome.")
    parser.add_argument("--executable-path", help="Path to an installed Chromium-family browser executable.")
    args = parser.parse_args()

    try:
        from playwright.async_api import async_playwright
    except ImportError as exc:
        raise SystemExit("Playwright is not installed. Install it with: python -m pip install playwright") from exc

    project_root = Path(__file__).resolve().parents[1]
    out_dir = Path(args.out_dir)
    processed_dir = Path(args.processed_dir)
    if not out_dir.is_absolute():
        out_dir = project_root / out_dir
    if not processed_dir.is_absolute():
        processed_dir = project_root / processed_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    processed_dir.mkdir(parents=True, exist_ok=True)

    captured: List[Dict[str, Any]] = []
    candidates: List[Dict[str, str]] = []

    async with async_playwright() as p:
        launch_options: Dict[str, Any] = {"headless": not args.headed}
        if args.channel:
            launch_options["channel"] = args.channel
        if args.executable_path:
            launch_options["executable_path"] = args.executable_path
        browser = await p.chromium.launch(**launch_options)
        page = await browser.new_page()

        async def on_response(response: Any) -> None:
            url = response.url
            content_type = response.headers.get("content-type", "")
            if not INTERESTING_URL_RE.search(url) and "json" not in content_type.lower():
                return
            record = {
                "festival": args.festival,
                "edition_year": args.edition_year,
                "page_url": args.url,
                "response_url": url,
                "status": response.status,
                "content_type": content_type,
                "captured_at": utc_now(),
            }
            try:
                body = await response.text()
            except Exception as exc:  # noqa: BLE001 - capture should continue.
                record["error"] = str(exc)
                captured.append(record)
                return
            filename = f"{safe_name(args.festival)}_{safe_name(url)}.txt"
            path = out_dir / filename
            path.write_text(body, encoding="utf-8", errors="replace")
            record["saved_body"] = str(path)
            record["body_preview"] = body[:500]
            captured.append(record)
            source = {
                "festival": args.festival,
                "edition_year": str(args.edition_year),
                "source_url": url,
                "captured_at": record["captured_at"],
            }
            candidates.extend(candidate_rows_from_payload(body, source))

        page.on("response", on_response)
        await page.goto(args.url, wait_until="domcontentloaded", timeout=max(args.wait_ms, 30000))
        await page.wait_for_timeout(args.wait_ms)
        if args.keep_open:
            await asyncio.to_thread(input, "Browser is still open. Interact with the page, then press Enter here to finish capture...")
        await browser.close()

    metadata_path = processed_dir / "business_network_responses.csv"
    with metadata_path.open("w", encoding="utf-8-sig", newline="") as f:
        fieldnames = ["festival", "edition_year", "page_url", "response_url", "status", "content_type", "saved_body", "body_preview", "error", "captured_at"]
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(captured)

    candidate_path = processed_dir / "business_network_fact_candidates.csv"
    with candidate_path.open("w", encoding="utf-8-sig", newline="") as f:
        fieldnames = ["festival", "edition_year", "source_url", "fact_type", "value", "year_matches_edition", "evidence", "captured_at"]
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(candidates)

    print(f"Captured responses: {len(captured)}")
    print(f"Candidate facts: {len(candidates)}")
    print(f"Wrote {metadata_path}")
    print(f"Wrote {candidate_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
