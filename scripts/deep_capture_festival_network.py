#!/usr/bin/env python3
"""
Deep browser network capture for dynamic festival shops.

This extends the normal capture flow by scrolling and clicking safe ticket/shop
navigation controls. It records request/response metadata and response bodies
for JSON/text resources. It does not fill forms, log in, or submit checkout.
"""

from __future__ import annotations

import argparse
import asyncio
import csv
import datetime as dt
import json
import re
from pathlib import Path
from typing import Any


INTERESTING_URL_RE = re.compile(
    r"(api|ticket|price|shop|cart|product|category|availability|queue|paylogic|id-t|package|event)",
    re.I,
)
PRICE_RE = re.compile(r"(€|EUR)\s*\d{1,4}(?:[.,]\d{2})?|\d{1,4}(?:[.,]\d{2})?\s*(€|EUR)", re.I)
DATE_RE = re.compile(r"20\d{2}-\d{1,2}-\d{1,2}|\b\d{1,2}[/-]\d{1,2}[/-]20\d{2}\b")
DEFAULT_CLICK_RE = re.compile(
    r"ticket|tickets|day|weekend|regular|premium|book|select|continue|next|camping|hotel|accommodation|packages",
    re.I,
)
BLOCKED_CLICK_RE = re.compile(
    r"checkout|check out|order-overview|pay|payment|login|log in|sign in|account|terms|privacy|delete|remove|facebook|whatsapp|telegram",
    re.I,
)


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def safe_name(text: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", text).strip("_")[:140] or "capture"


def candidate_rows_from_payload(payload: str, source: dict[str, Any]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for regex, fact_type in ((PRICE_RE, "price_candidate"), (DATE_RE, "date_candidate")):
        for match in regex.finditer(payload):
            start = max(0, match.start() - 160)
            end = min(len(payload), match.end() + 160)
            rows.append(
                {
                    **source,
                    "fact_type": fact_type,
                    "value": match.group(0),
                    "year_matches_edition": str(source["edition_year"]) in match.group(0),
                    "evidence": payload[start:end],
                }
            )
    return rows


def should_save_body(url: str, content_type: str) -> bool:
    content_type = content_type.lower()
    if "json" in content_type or "text" in content_type or "javascript" in content_type or "html" in content_type:
        return True
    return bool(INTERESTING_URL_RE.search(url))


async def click_safe_targets(page: Any, click_regex: re.Pattern[str], max_clicks: int, wait_ms: int) -> list[dict[str, str]]:
    clicked: list[dict[str, str]] = []
    seen: set[str] = set()

    for selector in ("button", "a", "[role=button]", "[role=tab]", "label"):
        locators = page.locator(selector)
        count = min(await locators.count(), 80)
        for index in range(count):
            if len(clicked) >= max_clicks:
                return clicked
            locator = locators.nth(index)
            try:
                if not await locator.is_visible(timeout=600):
                    continue
                text = re.sub(r"\s+", " ", (await locator.inner_text(timeout=800)).strip())
                if not text:
                    aria = await locator.get_attribute("aria-label", timeout=800)
                    text = re.sub(r"\s+", " ", (aria or "").strip())
                href = await locator.get_attribute("href", timeout=800)
                key = f"{selector}|{text}|{href or ''}"
                if key in seen:
                    continue
                seen.add(key)
                if not click_regex.search(text) and not (href and click_regex.search(href)):
                    continue
                blocked_target = f"{text} {href or ''}"
                if BLOCKED_CLICK_RE.search(blocked_target):
                    continue
                await locator.scroll_into_view_if_needed(timeout=1500)
                await locator.click(timeout=2500)
                clicked.append(
                    {
                        "selector": selector,
                        "text": text[:200],
                        "href": href or "",
                        "clicked_at": utc_now(),
                        "url_after_click": page.url,
                    }
                )
                await page.wait_for_timeout(wait_ms)
            except Exception as exc:  # noqa: BLE001 - probing should continue.
                clicked.append(
                    {
                        "selector": selector,
                        "text": f"[click failed] {str(exc)[:180]}",
                        "href": "",
                        "clicked_at": utc_now(),
                        "url_after_click": page.url,
                    }
                )
    return clicked


async def scroll_page(page: Any, steps: int, wait_ms: int) -> None:
    for _ in range(steps):
        await page.mouse.wheel(0, 900)
        await page.wait_for_timeout(wait_ms)
    await page.evaluate("window.scrollTo(0, 0)")
    await page.wait_for_timeout(wait_ms)


async def save_page_state(page: Any, processed_dir: Path) -> None:
    text_path = processed_dir / "page_text.txt"
    html_path = processed_dir / "page_dom.html"
    controls_path = processed_dir / "visible_controls.csv"
    screenshot_path = processed_dir / "page_screenshot.png"

    try:
        text_path.write_text(await page.locator("body").inner_text(timeout=3000), encoding="utf-8", errors="replace")
    except Exception as exc:  # noqa: BLE001
        text_path.write_text(f"Failed to read body text: {exc}", encoding="utf-8")
    try:
        html_path.write_text(await page.content(), encoding="utf-8", errors="replace")
    except Exception as exc:  # noqa: BLE001
        html_path.write_text(f"Failed to read DOM: {exc}", encoding="utf-8")
    try:
        await page.screenshot(path=str(screenshot_path), full_page=True)
    except Exception:
        pass

    rows: list[dict[str, str]] = []
    for selector in ("button", "a", "[role=button]", "[role=tab]", "label", "input"):
        locators = page.locator(selector)
        count = min(await locators.count(), 120)
        for index in range(count):
            locator = locators.nth(index)
            try:
                if not await locator.is_visible(timeout=300):
                    continue
                rows.append(
                    {
                        "selector": selector,
                        "text": re.sub(r"\s+", " ", (await locator.inner_text(timeout=600)).strip())[:300],
                        "aria_label": str(await locator.get_attribute("aria-label", timeout=600) or ""),
                        "href": str(await locator.get_attribute("href", timeout=600) or ""),
                        "type": str(await locator.get_attribute("type", timeout=600) or ""),
                        "name": str(await locator.get_attribute("name", timeout=600) or ""),
                    }
                )
            except Exception:
                continue
    with controls_path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["selector", "text", "aria_label", "href", "type", "name"])
        writer.writeheader()
        writer.writerows(rows)


async def main() -> int:
    parser = argparse.ArgumentParser(description="Deep capture dynamic festival shop network responses.")
    parser.add_argument("--url", required=True)
    parser.add_argument("--festival", required=True)
    parser.add_argument("--edition-year", type=int, required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--processed-dir", required=True)
    parser.add_argument("--wait-ms", type=int, default=15000)
    parser.add_argument("--interaction-wait-ms", type=int, default=1800)
    parser.add_argument("--scroll-steps", type=int, default=8)
    parser.add_argument("--max-clicks", type=int, default=18)
    parser.add_argument("--click-regex", default=DEFAULT_CLICK_RE.pattern)
    parser.add_argument("--headed", action="store_true")
    parser.add_argument("--keep-open", action="store_true")
    parser.add_argument("--channel", help="Playwright browser channel, for example msedge or chrome.")
    parser.add_argument("--executable-path")
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

    captured: list[dict[str, Any]] = []
    requests: list[dict[str, Any]] = []
    candidates: list[dict[str, str]] = []
    clicked: list[dict[str, str]] = []
    click_regex = re.compile(args.click_regex, re.I)

    async with async_playwright() as p:
        launch_options: dict[str, Any] = {"headless": not args.headed}
        if args.channel:
            launch_options["channel"] = args.channel
        if args.executable_path:
            launch_options["executable_path"] = args.executable_path
        browser = await p.chromium.launch(**launch_options)
        context = await browser.new_context(viewport={"width": 1440, "height": 1100}, locale="en-US")
        page = await context.new_page()

        async def on_request(request: Any) -> None:
            url = request.url
            if not INTERESTING_URL_RE.search(url):
                return
            requests.append(
                {
                    "festival": args.festival,
                    "edition_year": args.edition_year,
                    "page_url": args.url,
                    "request_url": url,
                    "method": request.method,
                    "resource_type": request.resource_type,
                    "post_data": (request.post_data or "")[:2000],
                    "captured_at": utc_now(),
                }
            )

        async def on_response(response: Any) -> None:
            url = response.url
            content_type = response.headers.get("content-type", "")
            if not INTERESTING_URL_RE.search(url) and not should_save_body(url, content_type):
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
            except Exception as exc:  # noqa: BLE001
                record["error"] = str(exc)
                captured.append(record)
                return
            if should_save_body(url, content_type):
                filename = f"{safe_name(args.festival)}_{safe_name(url)}.txt"
                path = out_dir / filename
                path.write_text(body, encoding="utf-8", errors="replace")
                record["saved_body"] = str(path)
                record["body_preview"] = body[:700]
            captured.append(record)
            source = {
                "festival": args.festival,
                "edition_year": str(args.edition_year),
                "source_url": url,
                "captured_at": record["captured_at"],
            }
            candidates.extend(candidate_rows_from_payload(body, source))

        page.on("request", on_request)
        page.on("response", on_response)
        await page.goto(args.url, wait_until="domcontentloaded", timeout=max(args.wait_ms, 45000))
        await page.wait_for_timeout(args.wait_ms)
        await scroll_page(page, args.scroll_steps, args.interaction_wait_ms)
        await save_page_state(page, processed_dir)
        clicked.extend(await click_safe_targets(page, click_regex, args.max_clicks, args.interaction_wait_ms))
        await scroll_page(page, max(2, args.scroll_steps // 2), args.interaction_wait_ms)
        await save_page_state(page, processed_dir)
        if args.keep_open:
            await asyncio.to_thread(input, "Browser is open. Interact manually, then press Enter here to finish capture...")
            await save_page_state(page, processed_dir)
        await browser.close()

    with (processed_dir / "deep_network_requests.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["festival", "edition_year", "page_url", "request_url", "method", "resource_type", "post_data", "captured_at"],
            extrasaction="ignore",
        )
        writer.writeheader()
        writer.writerows(requests)

    with (processed_dir / "deep_network_responses.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["festival", "edition_year", "page_url", "response_url", "status", "content_type", "saved_body", "body_preview", "error", "captured_at"],
            extrasaction="ignore",
        )
        writer.writeheader()
        writer.writerows(captured)

    with (processed_dir / "deep_network_fact_candidates.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["festival", "edition_year", "source_url", "fact_type", "value", "year_matches_edition", "evidence", "captured_at"],
            extrasaction="ignore",
        )
        writer.writeheader()
        writer.writerows(candidates)

    with (processed_dir / "clicked_controls.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["selector", "text", "href", "clicked_at", "url_after_click"], extrasaction="ignore")
        writer.writeheader()
        writer.writerows(clicked)

    print(f"Requests: {len(requests)}")
    print(f"Responses: {len(captured)}")
    print(f"Candidate facts: {len(candidates)}")
    print(f"Clicked controls: {len(clicked)}")
    print(f"Wrote {processed_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
