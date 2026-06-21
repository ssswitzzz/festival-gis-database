import argparse
import json


def tags_to_properties(element):
    tags = element.get("tags", {})
    props = {
        "name": tags.get("name"),
        "amenity": tags.get("amenity"),
        "leisure": tags.get("leisure"),
        "tourism": tags.get("tourism"),
        "landuse": tags.get("landuse"),
        "aeroway": tags.get("aeroway"),
        "railway": tags.get("railway"),
        "public_transport": tags.get("public_transport"),
        "iata": tags.get("iata"),
        "icao": tags.get("icao"),
    }
    props = {k: v for k, v in props.items() if v is not None}
    props["osm_type"] = element.get("type")
    props["osm_id"] = str(element.get("id"))
    return props


def polygon_feature(element):
    if element.get("type") != "way":
        return None
    geometry = element.get("geometry") or []
    if len(geometry) < 4:
        return None

    coords = [[float(point["lon"]), float(point["lat"])] for point in geometry]
    if coords[0] != coords[-1]:
        return None

    return {
        "type": "Feature",
        "geometry": {"type": "Polygon", "coordinates": [coords]},
        "properties": tags_to_properties(element),
    }


def point_feature(element):
    if element.get("type") == "node" and "lon" in element and "lat" in element:
        lon = float(element["lon"])
        lat = float(element["lat"])
    elif "center" in element:
        lon = float(element["center"]["lon"])
        lat = float(element["center"]["lat"])
    elif element.get("geometry"):
        points = element["geometry"]
        lon = sum(float(point["lon"]) for point in points) / len(points)
        lat = sum(float(point["lat"]) for point in points) / len(points)
    else:
        return None

    return {
        "type": "Feature",
        "geometry": {"type": "Point", "coordinates": [lon, lat]},
        "properties": tags_to_properties(element),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--mode", choices=["polygon", "point"], required=True)
    args = parser.parse_args()

    with open(args.input, "r", encoding="utf-8") as f:
        data = json.load(f)

    features = []
    for element in data.get("elements", []):
        feature = polygon_feature(element) if args.mode == "polygon" else point_feature(element)
        if feature is not None:
            features.append(feature)

    collection = {"type": "FeatureCollection", "features": features}
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(collection, f, ensure_ascii=False)

    print(f"Wrote {len(features)} features to {args.output}")


if __name__ == "__main__":
    main()
