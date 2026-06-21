from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RAW_DIR = PROJECT_ROOT / "data" / "raw" / "festival_network_capture"
DEFAULT_OUT_DIR = PROJECT_ROOT / "data" / "processed"


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def capture_timestamp(path: Path) -> str:
    parts = path.name.split("_")
    for part in parts:
        if len(part) == 14 and part.isdigit():
            return part
    return ""


def source_url_from_name(path: Path) -> str:
    name = path.name
    marker = "_https_artist-lineup-cdn.tomorrowland.com_"
    if marker not in name:
        return ""
    timestamp = capture_timestamp(path)
    resource = name.split(marker, 1)[1].removesuffix(".txt")
    if resource.startswith("config-"):
        resource = resource + "fd6c-aa71-43a9-87d1-0334f759a95b.json"
    elif resource.startswith("stages-"):
        resource = resource + "fd6c-aa71-43a9-87d1-0334f759a95b.json"
    elif resource.startswith("TLBE25-"):
        resource = resource + "-aa71-43a9-87d1-0334f759a95b.json"
    if timestamp:
        return f"https://web.archive.org/web/{timestamp}/https://artist-lineup-cdn.tomorrowland.com/{resource}"
    return f"https://artist-lineup-cdn.tomorrowland.com/{resource}"


def choose_latest(paths: list[Path], token: str) -> Path | None:
    candidates = [p for p in paths if token in p.name and p.stat().st_size > 0]
    if not candidates:
        return None
    return sorted(candidates, key=lambda p: (capture_timestamp(p), p.stat().st_size))[-1]


def write_csv(path: Path, rows: list[dict], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Parse captured Tomorrowland 2025 official lineup JSON into clean CSV files."
    )
    parser.add_argument("--raw-dir", type=Path, default=DEFAULT_RAW_DIR)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    args = parser.parse_args()

    raw_dir = args.raw_dir.resolve()
    out_dir = args.out_dir.resolve()
    paths = list(raw_dir.glob("*TLBE25*.txt"))

    config_path = choose_latest(paths, "config-TLBE25")
    stages_path = choose_latest(paths, "stages-TLBE25")
    w1_path = choose_latest(paths, "TLBE25-W1")
    w2_path = choose_latest(paths, "TLBE25-W2")

    missing = [
        label
        for label, path in {
            "config-TLBE25": config_path,
            "stages-TLBE25": stages_path,
            "TLBE25-W1": w1_path,
            "TLBE25-W2": w2_path,
        }.items()
        if path is None
    ]
    if missing:
        raise SystemExit(f"Missing captured JSON files: {', '.join(missing)}")

    selected_paths = {
        "config": config_path,
        "stages": stages_path,
        "W1": w1_path,
        "W2": w2_path,
    }

    config = read_json(config_path)
    stages_doc = read_json(stages_path)
    perf_docs = {"W1": read_json(w1_path), "W2": read_json(w2_path)}

    weekend_rows: list[dict] = []
    for weekend in config.get("config", {}).get("weekends", []):
        weekend_rows.append(
            {
                "festival": "Tomorrowland",
                "edition_year": 2025,
                "weekend_code": weekend.get("name", ""),
                "start_datetime_local": weekend.get("startDate", ""),
                "end_datetime_local": weekend.get("endDate", ""),
                "with_timetable": config.get("config", {}).get("withTimetable", ""),
                "source_file": str(config_path),
                "capture_timestamp": capture_timestamp(config_path),
                "source_url_hint": source_url_from_name(config_path),
            }
        )

    stage_rows_by_id: dict[str, dict] = {}
    for stage in stages_doc.get("stages", []):
        stage_id = str(stage.get("id", ""))
        host_values = stage.get("hosts", {})
        if isinstance(host_values, dict):
            hosts = "; ".join(f"{date}: {host}" for date, host in sorted(host_values.items()) if host)
        elif isinstance(host_values, list):
            hosts = "; ".join(str(host) for host in host_values if host)
        else:
            hosts = str(host_values or "")
        stage_rows_by_id[stage_id] = {
            "festival": "Tomorrowland",
            "edition_year": 2025,
            "official_stage_id": stage_id,
            "stage_name": stage.get("name", ""),
            "hosts_by_date": hosts,
            "source_file": str(stages_path),
            "capture_timestamp": capture_timestamp(stages_path),
            "source_url_hint": source_url_from_name(stages_path),
        }

    artist_rows_by_id: dict[str, dict] = {}
    performance_rows_by_id: dict[str, dict] = {}

    for weekend_code, doc in perf_docs.items():
        source_path = selected_paths[weekend_code]
        for perf in doc.get("performances", []):
            if not str(perf.get("date", "")).startswith("2025-"):
                continue
            stage = perf.get("stage") or {}
            stage_id = str(stage.get("id", ""))
            if stage_id and stage_id not in stage_rows_by_id:
                stage_rows_by_id[stage_id] = {
                    "festival": "Tomorrowland",
                    "edition_year": 2025,
                    "official_stage_id": stage_id,
                    "stage_name": stage.get("name", ""),
                    "hosts_by_date": "",
                    "source_file": str(source_path),
                    "capture_timestamp": capture_timestamp(source_path),
                    "source_url_hint": source_url_from_name(source_path),
                }

            artists = perf.get("artists") or []
            artist_ids = []
            artist_names = []
            for artist in artists:
                artist_id = str(artist.get("id", ""))
                artist_name = artist.get("name", "")
                if artist_id:
                    artist_ids.append(artist_id)
                    artist_rows_by_id.setdefault(
                        artist_id,
                        {
                            "festival": "Tomorrowland",
                            "edition_year": 2025,
                            "official_artist_id": artist_id,
                            "artist_name": artist_name,
                            "image_url": artist.get("image", ""),
                            "website": artist.get("website", ""),
                            "instagram": artist.get("instagram", ""),
                            "spotify": artist.get("spotify", ""),
                            "source_file": str(source_path),
                            "capture_timestamp": capture_timestamp(source_path),
                            "source_url_hint": source_url_from_name(source_path),
                        },
                    )
                if artist_name:
                    artist_names.append(artist_name)

            performance_id = str(perf.get("id", ""))
            performance_rows_by_id[performance_id] = {
                "festival": "Tomorrowland",
                "edition_year": 2025,
                "weekend_code": weekend_code,
                "official_performance_id": performance_id,
                "performance_name": perf.get("name", ""),
                "official_stage_id": stage_id,
                "stage_name": stage.get("name", ""),
                "official_artist_ids": "|".join(artist_ids),
                "artist_names": "|".join(artist_names),
                "performance_date": perf.get("date", ""),
                "day_name": perf.get("day", ""),
                "start_time_local": perf.get("startTime", ""),
                "end_time_local": perf.get("endTime", ""),
                "source_file": str(source_path),
                "capture_timestamp": capture_timestamp(source_path),
                "source_url_hint": source_url_from_name(source_path),
            }

    weekend_rows.sort(key=lambda row: row["weekend_code"])
    stage_rows = sorted(stage_rows_by_id.values(), key=lambda row: row["stage_name"])
    artist_rows = sorted(artist_rows_by_id.values(), key=lambda row: row["artist_name"].casefold())
    performance_rows = sorted(
        performance_rows_by_id.values(),
        key=lambda row: (
            row["start_time_local"],
            row["stage_name"],
            row["performance_name"].casefold(),
        ),
    )

    write_csv(
        out_dir / "tomorrowland_2025_weekends_official.csv",
        weekend_rows,
        [
            "festival",
            "edition_year",
            "weekend_code",
            "start_datetime_local",
            "end_datetime_local",
            "with_timetable",
            "source_file",
            "capture_timestamp",
            "source_url_hint",
        ],
    )
    write_csv(
        out_dir / "tomorrowland_2025_stages_official.csv",
        stage_rows,
        [
            "festival",
            "edition_year",
            "official_stage_id",
            "stage_name",
            "hosts_by_date",
            "source_file",
            "capture_timestamp",
            "source_url_hint",
        ],
    )
    write_csv(
        out_dir / "tomorrowland_2025_artists_official.csv",
        artist_rows,
        [
            "festival",
            "edition_year",
            "official_artist_id",
            "artist_name",
            "image_url",
            "website",
            "instagram",
            "spotify",
            "source_file",
            "capture_timestamp",
            "source_url_hint",
        ],
    )
    write_csv(
        out_dir / "tomorrowland_2025_performances_official.csv",
        performance_rows,
        [
            "festival",
            "edition_year",
            "weekend_code",
            "official_performance_id",
            "performance_name",
            "official_stage_id",
            "stage_name",
            "official_artist_ids",
            "artist_names",
            "performance_date",
            "day_name",
            "start_time_local",
            "end_time_local",
            "source_file",
            "capture_timestamp",
            "source_url_hint",
        ],
    )

    print(f"Selected config: {config_path.name}")
    print(f"Selected stages: {stages_path.name}")
    print(f"Selected W1: {w1_path.name}")
    print(f"Selected W2: {w2_path.name}")
    print(f"Wrote weekends: {len(weekend_rows)}")
    print(f"Wrote stages: {len(stage_rows)}")
    print(f"Wrote artists: {len(artist_rows)}")
    print(f"Wrote performances: {len(performance_rows)}")


if __name__ == "__main__":
    main()
