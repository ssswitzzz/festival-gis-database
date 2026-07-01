-- Add the reviewed Walibi Holland OSM boundary as a candidate site.
-- This is a targeted correction for Defqon.1's real venue: the general
-- candidate-site Overpass query did not include tourism=theme_park.

BEGIN;

WITH walibi AS (
    SELECT
        'Walibi Holland'::varchar(160) AS name,
        'way/409832086'::varchar(80) AS source_osm_id,
        'theme_park'::varchar(80) AS terrain_type,
        'OpenStreetMap Nominatim boundary lookup: Walibi Holland way/409832086, tourism=theme_park; added as reviewed Defqon.1 real-venue candidate.'::text AS data_source,
        ST_Multi(
            ST_Transform(
                ST_SetSRID(
                    ST_GeomFromGeoJSON($geojson$
{
  "type": "Polygon",
  "coordinates": [[
    [5.7580118, 52.4436992],
    [5.7587212, 52.4427455],
    [5.7593179, 52.4425393],
    [5.7596879, 52.4424134],
    [5.7601183, 52.4424832],
    [5.7604871, 52.4424024],
    [5.7605719, 52.4422477],
    [5.760392, 52.4421568],
    [5.7590574, 52.4415905],
    [5.7583469, 52.4412839],
    [5.7596084, 52.4402383],
    [5.7589338, 52.4397846],
    [5.7593066, 52.439461],
    [5.7596097, 52.4395982],
    [5.7600231, 52.4392956],
    [5.7606687, 52.4394788],
    [5.7608286, 52.439182],
    [5.7605229, 52.4389408],
    [5.759471, 52.4385937],
    [5.7590158, 52.438468],
    [5.7592544, 52.438074],
    [5.7596664, 52.4379271],
    [5.7592418, 52.4375852],
    [5.7587994, 52.4376688],
    [5.7584544, 52.4375488],
    [5.7586004, 52.4372363],
    [5.7587937, 52.4370262],
    [5.7589092, 52.4366391],
    [5.7595048, 52.4361883],
    [5.7603294, 52.4354932],
    [5.7608311, 52.4350343],
    [5.7633449, 52.4361153],
    [5.7644473, 52.4365848],
    [5.7654007, 52.436947],
    [5.7655797, 52.4370377],
    [5.7659453, 52.4372006],
    [5.7662721, 52.4373328],
    [5.766789, 52.4375283],
    [5.7670929, 52.4376936],
    [5.767603, 52.4379094],
    [5.768147, 52.4381172],
    [5.76953, 52.4387687],
    [5.7708823, 52.4393354],
    [5.7713022, 52.4395209],
    [5.7730724, 52.4402332],
    [5.7724488, 52.4408492],
    [5.7749127, 52.442026],
    [5.7760391, 52.4411071],
    [5.777926, 52.4418241],
    [5.7771146, 52.4425083],
    [5.7758257, 52.4419532],
    [5.7748755, 52.442225],
    [5.7745372, 52.4421893],
    [5.7708086, 52.4453449],
    [5.7665207, 52.4441403],
    [5.7630673, 52.4426711],
    [5.7605677, 52.4448219],
    [5.7580118, 52.4436992]
  ]]
}
$geojson$),
                    4326
                ),
                3035
            )
        )::geometry(MultiPolygon, 3035) AS geom_polygon
),
updated_candidate AS (
    UPDATE candidate_sites c
    SET
        name = w.name,
        terrain_type = w.terrain_type,
        area_sqm = ROUND(ST_Area(w.geom_polygon)::numeric, 2),
        daily_cost = NULL,
        data_source = w.data_source,
        is_manual_sample = false,
        geom_polygon = w.geom_polygon
    FROM walibi w
    WHERE c.source_osm_id = w.source_osm_id
       OR c.name = w.name
    RETURNING c.site_id
),
inserted_candidate AS (
    INSERT INTO candidate_sites
        (name, source_osm_id, terrain_type, area_sqm, daily_cost, data_source, is_manual_sample, geom_polygon)
    SELECT
        w.name,
        w.source_osm_id,
        w.terrain_type,
        ROUND(ST_Area(w.geom_polygon)::numeric, 2),
        NULL,
        w.data_source,
        false,
        w.geom_polygon
    FROM walibi w
    WHERE NOT EXISTS (SELECT 1 FROM updated_candidate)
    RETURNING site_id
)
UPDATE venues v
SET
    geom_polygon = w.geom_polygon,
    area_sqm = ROUND(ST_Area(w.geom_polygon)::numeric, 2),
    data_source = 'OpenStreetMap Nominatim boundary lookup: Walibi Holland way/409832086; represents theme park boundary, not official Defqon.1 operational perimeter.'
FROM walibi w
WHERE v.name = 'Walibi Holland event grounds';

COMMIT;

SELECT
    site_id,
    name,
    source_osm_id,
    terrain_type,
    area_sqm,
    is_manual_sample,
    data_source
FROM candidate_sites
WHERE source_osm_id = 'way/409832086'
   OR name = 'Walibi Holland';

SELECT
    venue_id,
    name,
    area_sqm,
    data_source,
    ROUND(ST_Area(geom_polygon)) AS geom_area_sqm
FROM venues
WHERE name = 'Walibi Holland event grounds';
