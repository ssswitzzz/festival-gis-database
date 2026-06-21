-- Normalize downloaded public spatial data from staging tables into project tables.
-- Run after scripts/download_public_data.ps1 and scripts/import_public_data.ps1.

BEGIN;

INSERT INTO candidate_sites
    (name, source_osm_id, terrain_type, area_sqm, daily_cost, data_source, is_manual_sample, geom_polygon)
SELECT
    COALESCE(NULLIF(name, ''), 'OSM candidate site ' || osm_id) AS name,
    osm_id AS source_osm_id,
    COALESCE(leisure, tourism, amenity, landuse, 'osm_candidate') AS terrain_type,
    ROUND(ST_Area(geom)::numeric, 2) AS area_sqm,
    NULL AS daily_cost,
    'OpenStreetMap Overpass API, downloaded into stg_osm_candidate_sites' AS data_source,
    false AS is_manual_sample,
    ST_Multi(geom)::geometry(MultiPolygon, 3035) AS geom_polygon
FROM stg_osm_candidate_sites
WHERE ST_IsValid(geom)
  AND ST_Area(geom) >= 50000
  AND NOT EXISTS (
      SELECT 1
      FROM candidate_sites existing
      WHERE existing.source_osm_id = stg_osm_candidate_sites.osm_id
  );

INSERT INTO noise_sensitive_facilities
    (name, facility_type, sensitivity_level, city, country, data_source, geom_point)
SELECT
    COALESCE(NULLIF(name, ''), 'OSM sensitive facility ' || osm_id) AS name,
    CASE
        WHEN amenity = 'hospital' THEN 'hospital'
        WHEN amenity IN ('school', 'kindergarten') THEN 'school'
        ELSE 'school'
    END AS facility_type,
    CASE
        WHEN amenity = 'hospital' THEN 5
        ELSE 4
    END AS sensitivity_level,
    NULL AS city,
    NULL AS country,
    'OpenStreetMap Overpass API, downloaded into stg_osm_sensitive_facilities' AS data_source,
    geom::geometry(Point, 3035) AS geom_point
FROM stg_osm_sensitive_facilities
WHERE ST_IsValid(geom)
  AND NOT EXISTS (
      SELECT 1
      FROM noise_sensitive_facilities existing
      WHERE existing.data_source LIKE 'OpenStreetMap Overpass API%'
        AND existing.name = COALESCE(NULLIF(stg_osm_sensitive_facilities.name, ''), 'OSM sensitive facility ' || stg_osm_sensitive_facilities.osm_id)
        AND ST_DWithin(existing.geom_point, stg_osm_sensitive_facilities.geom, 1)
  );

INSERT INTO transport_hubs
    (name, hub_type, city, country, daily_capacity, data_source, geom_point)
SELECT
    COALESCE(NULLIF(name, ''), 'OSM transport hub ' || osm_id) AS name,
    CASE
        WHEN aeroway = 'aerodrome' THEN 'airport'
        WHEN railway = 'station' THEN 'train_station'
        WHEN amenity = 'bus_station' THEN 'bus_terminal'
        ELSE 'train_station'
    END AS hub_type,
    NULL AS city,
    NULL AS country,
    NULL AS daily_capacity,
    'OpenStreetMap Overpass API, downloaded into stg_osm_transport_hubs' AS data_source,
    geom::geometry(Point, 3035) AS geom_point
FROM stg_osm_transport_hubs
WHERE ST_IsValid(geom)
  AND (
      aeroway = 'aerodrome'
      OR railway = 'station'
      OR amenity = 'bus_station'
  )
  AND NOT EXISTS (
      SELECT 1
      FROM transport_hubs existing
      WHERE existing.data_source LIKE 'OpenStreetMap Overpass API%'
        AND existing.name = COALESCE(NULLIF(stg_osm_transport_hubs.name, ''), 'OSM transport hub ' || stg_osm_transport_hubs.osm_id)
        AND ST_DWithin(existing.geom_point, stg_osm_transport_hubs.geom, 1)
  );

INSERT INTO ecological_protected_areas
    (name, protect_type, data_source, geom_polygon)
SELECT
    COALESCE(NULLIF("SITENAME", ''), NULLIF("SITECODE", ''), 'Natura 2000 protected area') AS name,
    COALESCE(NULLIF("SITETYPE", ''), 'Natura 2000') AS protect_type,
    'EEA Natura 2000 ArcGIS REST service, downloaded into stg_natura2000_be_nl' AS data_source,
    ST_Multi(ST_CollectionExtract(geom, 3))::geometry(MultiPolygon, 3035) AS geom_polygon
FROM stg_natura2000_be_nl
WHERE ST_IsValid(geom)
  AND NOT ST_IsEmpty(ST_CollectionExtract(geom, 3))
  AND NOT EXISTS (
      SELECT 1
      FROM ecological_protected_areas existing
      WHERE existing.data_source LIKE 'EEA Natura 2000 ArcGIS REST service%'
        AND existing.name = COALESCE(NULLIF(stg_natura2000_be_nl."SITENAME", ''), NULLIF(stg_natura2000_be_nl."SITECODE", ''), 'Natura 2000 protected area')
  );

COMMIT;

SELECT 'candidate_sites' AS table_name, COUNT(*) AS total_rows, COUNT(*) FILTER (WHERE is_manual_sample = false) AS public_rows
FROM candidate_sites
UNION ALL
SELECT 'noise_sensitive_facilities', COUNT(*), COUNT(*) FILTER (WHERE data_source LIKE 'OpenStreetMap Overpass API%')
FROM noise_sensitive_facilities
UNION ALL
SELECT 'transport_hubs', COUNT(*), COUNT(*) FILTER (WHERE data_source LIKE 'OpenStreetMap Overpass API%')
FROM transport_hubs
UNION ALL
SELECT 'ecological_protected_areas', COUNT(*), COUNT(*) FILTER (WHERE data_source LIKE 'EEA Natura 2000 ArcGIS REST service%')
FROM ecological_protected_areas;
