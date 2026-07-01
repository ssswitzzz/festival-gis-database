from __future__ import annotations

import argparse
import csv
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ARTISTS_CSV = PROJECT_ROOT / "data" / "processed" / "tomorrowland_2025_artists_official.csv"
DEFAULT_OUT_CSV = PROJECT_ROOT / "data" / "processed" / "tomorrowland_2025_artist_genres_enriched.csv"

WIKIDATA_ENDPOINT = "https://query.wikidata.org/sparql"
MUSICBRAINZ_ENDPOINT = "https://musicbrainz.org/ws/2/artist/"
USER_AGENT = "festival-gis-db-course-project/1.0 (local academic enrichment)"

GENRE_SYNONYMS = {
    "edm": "electronic dance music",
    "electronic dance music": "electronic dance music",
    "electronic music": "electronic dance music",
    "dance music": "electronic dance music",
    "progressive house music": "progressive house",
    "deep house music": "deep house",
    "tech house music": "tech house",
    "big room": "big room house",
    "big room house": "big room house",
    "drum and bass": "drum and bass",
    "drum & bass": "drum and bass",
    "dnb": "drum and bass",
    "melodic techno": "melodic techno",
    "melodic house": "melodic house",
    "hard techno": "hard techno",
    "hardstyle": "hardstyle",
    "hardcore": "hardcore",
    "gabber": "hardcore",
    "trance": "trance",
    "psytrance": "psytrance",
    "psychedelic trance": "psytrance",
    "house": "house",
    "house music": "house",
    "techno": "techno",
    "dubstep": "dubstep",
    "future house": "future house",
    "bass house": "bass house",
    "electro house": "electro house",
    "afro house": "afro house",
    "minimal techno": "minimal techno",
    "industrial techno": "industrial techno",
    "acid techno": "acid techno",
    "pop dance": "dance-pop",
    "dance-pop": "dance-pop",
    "dutch house": "dutch house",
    "moombahton": "moombahton",
    "electropop": "electropop",
    "rave music": "rave",
    "rave": "rave",
    "trap music": "trap",
    "edm trap music": "trap",
    "speedcore": "speedcore",
    "frenchcore": "frenchcore",
    "rawstyle": "rawstyle",
    "euphoric hardstyle": "euphoric hardstyle",
    "uptempo hardcore": "uptempo hardcore",
}

ALLOWED_GENRES = set(GENRE_SYNONYMS.values()) | {
    "afro tech",
    "ambient techno",
    "bass music",
    "belgian techno",
    "breakbeat",
    "club music",
    "dance",
    "dance-pop",
    "dark techno",
    "deep techno",
    "disco",
    "drum and bass",
    "dub techno",
    "electro",
    "electronic dance music",
    "electronic music",
    "eurodance",
    "future bass",
    "future rave",
    "garage house",
    "hard dance",
    "hard trance",
    "hi-nrg",
    "hip house",
    "latin house",
    "mainstage",
    "melodic house and techno",
    "minimal",
    "progressive trance",
    "tech trance",
    "uk garage",
}
EDM_KEYWORDS = set(GENRE_SYNONYMS)


def normalize_genre(value: str) -> str:
    cleaned = " ".join(value.strip().lower().replace("_", " ").split())
    return GENRE_SYNONYMS.get(cleaned, cleaned)


def keep_genre(value: str) -> bool:
    genre = normalize_genre(value)
    if genre in ALLOWED_GENRES:
        return True
    return any(
        token in genre
        for token in (
            "house",
            "techno",
            "trance",
            "hardstyle",
            "hardcore",
            "bass",
            "dubstep",
            "dance",
            "electro",
        )
    )


def read_artists(path: Path) -> list[str]:
    with path.open(newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        names = sorted({row["artist_name"].strip() for row in reader if row.get("artist_name", "").strip()})
    return names


def urlopen_json(url: str, headers: dict[str, str] | None = None) -> dict:
    request = urllib.request.Request(url, headers=headers or {"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=45) as response:
        return json.loads(response.read().decode("utf-8"))


def query_wikidata(batch: list[str]) -> dict[str, set[str]]:
    values = " ".join(json.dumps(name) + "@en" for name in batch)
    query = f"""
SELECT ?artistLabel ?genreLabel WHERE {{
  VALUES ?artistLabel {{ {values} }}
  ?artist rdfs:label ?artistLabel.
  ?artist wdt:P136 ?genre.
  {{
    ?artist wdt:P31/wdt:P279* wd:Q215380.
  }}
  UNION
  {{
    ?artist wdt:P106/wdt:P279* wd:Q639669.
  }}
  UNION
  {{
    ?artist wdt:P106/wdt:P279* wd:Q177220.
  }}
  UNION
  {{
    ?artist wdt:P106/wdt:P279* wd:Q183945.
  }}
  ?genre rdfs:label ?genreLabel.
  FILTER(LANG(?artistLabel) = "en")
  FILTER(LANG(?genreLabel) = "en")
}}
"""
    params = urllib.parse.urlencode({"query": query, "format": "json"})
    url = f"{WIKIDATA_ENDPOINT}?{params}"
    data = urlopen_json(url, {"Accept": "application/sparql-results+json", "User-Agent": USER_AGENT})
    by_artist: dict[str, set[str]] = {name: set() for name in batch}
    for binding in data.get("results", {}).get("bindings", []):
        artist = binding.get("artistLabel", {}).get("value", "")
        genre = binding.get("genreLabel", {}).get("value", "")
        if artist in by_artist and genre and keep_genre(genre):
            by_artist[artist].add(normalize_genre(genre))
    return by_artist


def query_musicbrainz(name: str) -> set[str]:
    query = urllib.parse.quote(f'artist:"{name}"')
    url = f"{MUSICBRAINZ_ENDPOINT}?query={query}&fmt=json&limit=1&inc=tags"
    data = urlopen_json(url)
    artists = data.get("artists", [])
    if not artists:
        return set()
    tags = artists[0].get("tags", []) or []
    genres: set[str] = set()
    for tag in tags:
        tag_name = normalize_genre(tag.get("name", ""))
        if tag_name in EDM_KEYWORDS or any(token in tag_name for token in ("house", "techno", "trance", "hardstyle", "hardcore", "bass", "dubstep")):
            genres.add(tag_name)
    return genres


def write_rows(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = ["artist_name", "genre_name", "source", "confidence", "source_url"]
    with path.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description="Enrich Tomorrowland 2025 artist genres from public music metadata.")
    parser.add_argument("--artists-csv", type=Path, default=DEFAULT_ARTISTS_CSV)
    parser.add_argument("--out-csv", type=Path, default=DEFAULT_OUT_CSV)
    parser.add_argument("--limit", type=int, default=0, help="Optional artist limit for smoke tests.")
    parser.add_argument("--musicbrainz", action="store_true", help="Also query MusicBrainz tags for artists not covered by Wikidata.")
    args = parser.parse_args()

    artists = read_artists(args.artists_csv)
    if args.limit:
        artists = artists[: args.limit]

    rows: list[dict[str, str]] = []
    found: dict[str, set[str]] = {name: set() for name in artists}

    for idx in range(0, len(artists), 50):
        batch = artists[idx : idx + 50]
        enriched = query_wikidata(batch)
        for artist, genres in enriched.items():
            found[artist].update(genres)
            for genre in sorted(genres):
                rows.append(
                    {
                        "artist_name": artist,
                        "genre_name": genre,
                        "source": "Wikidata SPARQL P136",
                        "confidence": "structured_exact_label",
                        "source_url": "https://query.wikidata.org/",
                    }
                )
        time.sleep(0.5)

    if args.musicbrainz:
        for artist in artists:
            if found[artist]:
                continue
            try:
                genres = query_musicbrainz(artist)
            except Exception:
                genres = set()
            for genre in sorted(genres):
                rows.append(
                    {
                        "artist_name": artist,
                        "genre_name": genre,
                        "source": "MusicBrainz artist tag",
                        "confidence": "community_tag_top_result",
                        "source_url": "https://musicbrainz.org/doc/MusicBrainz_API",
                    }
                )
            if genres:
                found[artist].update(genres)
            time.sleep(1.1)

    unique_rows = sorted({tuple(row.items()) for row in rows})
    write_rows(args.out_csv, [dict(items) for items in unique_rows])

    covered = sum(1 for genres in found.values() if genres)
    print(f"artists={len(artists)} covered={covered} genre_links={len(unique_rows)} out={args.out_csv}")


if __name__ == "__main__":
    main()
