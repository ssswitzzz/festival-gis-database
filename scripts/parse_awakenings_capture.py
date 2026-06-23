from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RAW_DIR = PROJECT_ROOT / "data" / "raw" / "awakenings_capture_2025"
DEFAULT_OUT_DIR = PROJECT_ROOT / "data" / "processed"


def read_json(path: Path) -> Any | None:
    text = path.read_text(encoding="utf-8", errors="replace").strip()
    if not text or text[0] not in "[{":
        return None
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return None


def source_page_hint(path: Path) -> str:
    parts = [part for part in path.parts if part.startswith("awakenings_current_")]
    if not parts:
        return ""
    name = parts[-1].removeprefix("awakenings_current_")
    route_hints = {
        "weekend_tickets_route": "https://www.awakenings.com/en/shop/awakenings-festival-2025-weekend/367651/weekend-tickets/",
        "day_tickets_route": "https://www.awakenings.com/en/shop/awakenings-festival-2025-main/375194/day-tickets/",
    }
    if name in route_hints:
        return route_hints[name]
    if name.startswith("www.awakenings.com_"):
        name = name.removeprefix("www.awakenings.com_")
    elif "_www.awakenings.com_" in name:
        name = name.split("_www.awakenings.com_", 1)[1]
    name = name.replace("_", "/")
    return f"https://www.awakenings.com/{name}"


def first_list(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)]
    if isinstance(payload, dict) and isinstance(payload.get("data"), list):
        return [item for item in payload["data"] if isinstance(item, dict)]
    return []


def bool_text(value: Any) -> str:
    if value is None:
        return ""
    return "true" if bool(value) else "false"


def clean_html_text(value: Any) -> str:
    text = re.sub(r"<[^>]+>", " ", str(value or ""))
    return re.sub(r"\s+", " ", text).strip()


def deposit_note(item: dict[str, Any]) -> str:
    content = " ".join(str(block) for block in item.get("content") or [])
    deposits = sorted(set(re.findall(r"(?:deposit of\s*)?€\s*\d+(?:[.,]\d{2})?", content, re.I)))
    if deposits:
        return "deposit/additional fee mentioned: " + "|".join(deposits)
    return ""


def parse_settings(path: Path, payload: Any) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for item in first_list(payload):
        categories = item.get("category") if isinstance(item.get("category"), list) else []
        rows.append(
            {
                "festival": "Awakenings Festival",
                "edition_year": "2025",
                "official_event_id": str(item.get("id") or ""),
                "name": str(item.get("name") or ""),
                "title": str(item.get("title") or ""),
                "location": str(item.get("location") or ""),
                "start_date": str(item.get("startDate") or ""),
                "start_time": str(item.get("startTime") or ""),
                "end_date": str(item.get("endDate") or ""),
                "end_time": str(item.get("endTime") or ""),
                "minimal_age": str(item.get("minimalAge") or ""),
                "state": str(item.get("state") or ""),
                "currency": str(item.get("currency") or "EUR"),
                "category_count": str(len(categories)),
                "category_titles": "|".join(str(cat.get("title") or "") for cat in categories if isinstance(cat, dict)),
                "source_url_hint": source_page_hint(path),
                "source_file": str(path),
                "confidence": "current_official_shop_json",
            }
        )
    return rows


def parse_packages(path: Path, payload: Any) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for item in first_list(payload):
        state = item.get("state") if isinstance(item.get("state"), dict) else {}
        category = item.get("category") if isinstance(item.get("category"), dict) else {}
        tickets = item.get("tickets") if isinstance(item.get("tickets"), list) else []
        rows.append(
            {
                "festival": "Awakenings Festival",
                "edition_year": "2025",
                "package_id": str(item.get("id") or ""),
                "event_id": str(item.get("eventId") or ""),
                "accommodation_id": str(item.get("accommodationId") or ""),
                "package_name": str(item.get("name") or ""),
                "main_category": str(category.get("main_category") or ""),
                "category_title": str(category.get("title") or ""),
                "basic_sale_price_eur": str(item.get("basicSalePrice") or ""),
                "basic_sale_price_cents": str(item.get("basicSalePriceInCents") or ""),
                "currency": "EUR",
                "regular_stay_from_date": str(item.get("regularStayFromDate") or ""),
                "regular_stay_until_date": str(item.get("regularStayUntilDate") or ""),
                "extended_stay_from_date": str(item.get("extendedStayFromDate") or ""),
                "extended_stay_until_date": str(item.get("extendedStayUntilDate") or ""),
                "bookable": bool_text(state.get("bookable")),
                "show_price": bool_text(state.get("showprice")),
                "sold_out": bool_text(state.get("soldout")),
                "wishlist_only": bool_text(state.get("wishlistOnly")),
                "ticket_descriptions": "|".join(
                    str(ticket.get("ticketTypeDescription") or "") for ticket in tickets if isinstance(ticket, dict)
                ),
                "deposit_note": deposit_note(item),
                "source_url_hint": source_page_hint(path),
                "source_file": str(path),
                "confidence": "current_official_shop_json_accommodation_package",
            }
        )
    return rows


def parse_products(path: Path, payload: Any) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for item in first_list(payload):
        price = item.get("price")
        cents = ""
        if isinstance(price, (int, float)):
            cents = str(int(round(float(price) * 100)))
        rows.append(
            {
                "festival": "Awakenings Festival",
                "edition_year": "2025",
                "product_id": str(item.get("id") or ""),
                "product_name": str(item.get("name") or ""),
                "product_type": str(item.get("type") or ""),
                "price_eur": str(price if price is not None else ""),
                "price_cents": cents,
                "price_excluding_service_costs": str(item.get("priceExcludingServiceCosts") or ""),
                "service_costs": str(item.get("serviceCosts") or ""),
                "max_quantity": str(item.get("maxQuantity") or ""),
                "stock_available": str(item.get("stockAvailable") or ""),
                "sold_out": bool_text(item.get("soldOut")),
                "categories": "|".join(str(cat) for cat in item.get("categories") or []),
                "tags": "|".join(str(tag) for tag in item.get("tags") or []),
                "source_url_hint": source_page_hint(path),
                "source_file": str(path),
                "confidence": "current_official_shop_json_product",
            }
        )
    return rows


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def dedupe(rows: list[dict[str, str]], key_fields: list[str]) -> list[dict[str, str]]:
    keyed: dict[tuple[str, ...], dict[str, str]] = {}
    for row in rows:
        keyed[tuple(row.get(field, "") for field in key_fields)] = row
    return list(keyed.values())


def main() -> None:
    parser = argparse.ArgumentParser(description="Parse Awakenings 2025 current official shop captures.")
    parser.add_argument("--raw-dir", type=Path, default=DEFAULT_RAW_DIR)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    args = parser.parse_args()

    event_rows: list[dict[str, str]] = []
    package_rows: list[dict[str, str]] = []
    product_rows: list[dict[str, str]] = []
    for path in args.raw_dir.resolve().rglob("*.txt"):
        payload = read_json(path)
        if payload is None:
            continue
        lower_name = path.name.lower()
        if lower_name.endswith("_en_settings.txt"):
            event_rows.extend(parse_settings(path, payload))
        elif lower_name.endswith("_en_packages.txt"):
            package_rows.extend(parse_packages(path, payload))
        elif lower_name.endswith("_api_v2_products.txt"):
            product_rows.extend(parse_products(path, payload))

    event_rows = sorted(dedupe(event_rows, ["official_event_id", "source_url_hint"]), key=lambda row: row["source_url_hint"])
    package_rows = sorted(dedupe(package_rows, ["package_id"]), key=lambda row: (row["main_category"], row["package_name"]))
    product_rows = sorted(dedupe(product_rows, ["product_id", "source_url_hint"]), key=lambda row: (row["source_url_hint"], row["product_name"]))

    write_csv(
        args.out_dir.resolve() / "awakenings_2025_event_facts_current_official.csv",
        list(event_rows[0].keys()) if event_rows else [
            "festival",
            "edition_year",
            "official_event_id",
            "name",
            "title",
            "location",
            "start_date",
            "start_time",
            "end_date",
            "end_time",
            "minimal_age",
            "state",
            "currency",
            "category_count",
            "category_titles",
            "source_url_hint",
            "source_file",
            "confidence",
        ],
        event_rows,
    )
    write_csv(
        args.out_dir.resolve() / "awakenings_2025_package_prices_current_official.csv",
        list(package_rows[0].keys()) if package_rows else [],
        package_rows,
    )
    write_csv(
        args.out_dir.resolve() / "awakenings_2025_shop_products_current_official.csv",
        list(product_rows[0].keys()) if product_rows else [],
        product_rows,
    )

    print(f"Awakenings event rows: {len(event_rows)}")
    print(f"Awakenings package rows: {len(package_rows)}")
    print(f"Awakenings product rows: {len(product_rows)}")


if __name__ == "__main__":
    main()
