-- Templates for replacing sample spatial data with formal public datasets.
-- These statements assume source data has already been clipped to Belgium + Netherlands
-- and transformed to EPSG:3035 in QGIS or with ogr2ogr.

-- Example staging tables can be created by ogr2ogr first:
-- ogr2ogr -f PostgreSQL PG:"dbname=festival_gis" belgium-latest-free.shp/gis_osm_pois_free_1.shp -nln stg_osm_pois_be -t_srs EPSG:3035
-- ogr2ogr -f PostgreSQL PG:"dbname=festival_gis" netherlands-latest-free.shp/gis_osm_pois_free_1.shp -nln stg_osm_pois_nl -t_srs EPSG:3035
-- ogr2ogr -f PostgreSQL PG:"dbname=festival_gis" natura2000.gpkg -nln stg_natura2000 -t_srs EPSG:3035
-- ogr2ogr -f PostgreSQL PG:"dbname=festival_gis" eurostat_population_grid.gpkg -nln stg_population_grid -t_srs EPSG:3035

-- Candidate sites from OSM polygon layers.
-- Adapt column names to the downloaded Geofabrik layer. Common fields include osm_id, name, fclass and way/geom.
INSERT INTO candidate_sites
    (name, source_osm_id, terrain_type, area_sqm, daily_cost, data_source, is_manual_sample, geom_polygon)
SELECT
    COALESCE(name, 'OSM candidate site ' || osm_id) AS name,
    osm_id::text AS source_osm_id,
    fclass AS terrain_type,
    ST_Area(ST_Multi(geom)) AS area_sqm,
    NULL AS daily_cost,
    'OpenStreetMap / Geofabrik filtered polygon import' AS data_source,
    false AS is_manual_sample,
    ST_Multi(geom)::geometry(MultiPolygon, 3035) AS geom_polygon
FROM stg_osm_landuse
WHERE fclass IN ('park', 'recreation_ground', 'grass', 'camp_site')
  AND ST_Area(geom) >= 50000
  AND ST_IsValid(geom);

-- Transport hubs from OSM POI layers.
INSERT INTO transport_hubs
    (name, hub_type, city, country, daily_capacity, data_source, geom_point)
SELECT
    COALESCE(name, 'OSM transport hub ' || osm_id) AS name,
    CASE
        WHEN fclass = 'airport' THEN 'airport'
        WHEN fclass IN ('railway_station', 'station') THEN 'train_station'
        WHEN fclass = 'bus_station' THEN 'bus_terminal'
        ELSE 'train_station'
    END AS hub_type,
    NULL AS city,
    NULL AS country,
    NULL AS daily_capacity,
    'OpenStreetMap / Geofabrik POI import' AS data_source,
    geom::geometry(Point, 3035) AS geom_point
FROM stg_osm_pois
WHERE fclass IN ('airport', 'railway_station', 'station', 'bus_station')
  AND ST_IsValid(geom);

-- Noise-sensitive facilities from OSM POI layers.
INSERT INTO noise_sensitive_facilities
    (name, facility_type, sensitivity_level, city, country, data_source, geom_point)
SELECT
    COALESCE(name, 'OSM sensitive facility ' || osm_id) AS name,
    CASE
        WHEN fclass = 'hospital' THEN 'hospital'
        WHEN fclass IN ('school', 'college', 'university', 'kindergarten') THEN 'school'
        ELSE 'residential'
    END AS facility_type,
    CASE
        WHEN fclass = 'hospital' THEN 5
        WHEN fclass IN ('school', 'college', 'university', 'kindergarten') THEN 4
        ELSE 4
    END AS sensitivity_level,
    NULL AS city,
    NULL AS country,
    'OpenStreetMap / Geofabrik POI import' AS data_source,
    geom::geometry(Point, 3035) AS geom_point
FROM stg_osm_pois
WHERE fclass IN ('hospital', 'school', 'college', 'university', 'kindergarten')
  AND ST_IsValid(geom);

-- Natura 2000 protected areas.
-- Adapt name/type columns to the EEA download. Typical names vary by release.
INSERT INTO ecological_protected_areas
    (name, protect_type, data_source, geom_polygon)
SELECT
    COALESCE(sitename, sitecode, 'Natura 2000 protected area') AS name,
    COALESCE(designatio, 'Natura 2000') AS protect_type,
    'EEA Natura 2000 spatial dataset' AS data_source,
    ST_Multi(geom)::geometry(MultiPolygon, 3035) AS geom_polygon
FROM stg_natura2000
WHERE ST_IsValid(geom)
  AND ST_Area(geom) > 0;

-- Eurostat/GISCO population grid.
-- Adapt population column to the chosen grid release.
INSERT INTO population_grids
    (population, edm_fan_index, data_source, is_synthetic_sample, geom_polygon)
SELECT
    population::integer AS population,
    0.50 AS edm_fan_index,
    'Eurostat/GISCO population grid; edm_fan_index is a coursework simulation field' AS data_source,
    false AS is_synthetic_sample,
    geom::geometry(Polygon, 3035) AS geom_polygon
FROM stg_population_grid
WHERE population IS NOT NULL
  AND population >= 0
  AND ST_IsValid(geom);
