-- Real-venue noise impact ring buffers for mapping.
-- Buffers are centered on the three current real festival venues only.

DROP VIEW IF EXISTS v_real_venue_noise_summary;
DROP VIEW IF EXISTS v_real_venue_noise_ring_buffers;
DROP VIEW IF EXISTS v_real_venue_noise_site_points;

CREATE OR REPLACE VIEW v_real_venue_noise_ring_buffers AS
WITH venue_centers AS (
    SELECT
        venue_id,
        name,
        city,
        country,
        ST_PointOnSurface(geom_polygon)::geometry(Point, 3035) AS venue_center
    FROM venues
)
SELECT
    ROW_NUMBER() OVER (ORDER BY v.name, r.outer_radius_km) AS buffer_id,
    v.venue_id,
    v.name AS venue_name,
    v.city,
    v.country,
    r.inner_radius_km,
    r.outer_radius_km AS radius_km,
    r.outer_radius_km,
    r.inner_radius_km * 1000 AS inner_radius_m,
    r.outer_radius_km * 1000 AS radius_m,
    r.outer_radius_km * 1000 AS outer_radius_m,
    CASE
        WHEN r.inner_radius_km = 0 THEN
            ST_Multi(ST_Buffer(v.venue_center, r.outer_radius_km * 1000))::geometry(MultiPolygon, 3035)
        ELSE
            ST_Multi(
                ST_Difference(
                    ST_Buffer(v.venue_center, r.outer_radius_km * 1000),
                    ST_Buffer(v.venue_center, r.inner_radius_km * 1000)
                )
            )::geometry(MultiPolygon, 3035)
    END AS geom_buffer
FROM venue_centers v
CROSS JOIN (VALUES (0, 2), (2, 5), (5, 10)) AS r(inner_radius_km, outer_radius_km);

CREATE OR REPLACE VIEW v_real_venue_noise_site_points AS
SELECT
    venue_id,
    name AS venue_name,
    city,
    country,
    area_sqm,
    data_source,
    ST_PointOnSurface(geom_polygon)::geometry(Point, 3035) AS geom_point
FROM venues;

CREATE OR REPLACE VIEW v_real_venue_noise_summary AS
SELECT
    b.venue_id,
    b.venue_name,
    b.city,
    b.country,
    b.radius_km,
    COALESCE(f.high_sensitive_facilities, 0) AS high_sensitive_facilities,
    COALESCE(f.schools, 0) AS schools,
    COALESCE(f.hospitals, 0) AS hospitals,
    COALESCE(p.raw_population, 0) AS raw_population,
    COALESCE(p.weighted_population, 0) AS weighted_population,
    COALESCE(e.intersecting_protected_areas, 0) AS intersecting_protected_areas,
    COALESCE(t.airports, 0) AS airports,
    COALESCE(t.train_stations, 0) AS train_stations,
    COALESCE(t.bus_terminals, 0) AS bus_terminals
FROM v_real_venue_noise_ring_buffers b
LEFT JOIN LATERAL (
    SELECT
        COUNT(*) FILTER (WHERE n.sensitivity_level >= 4) AS high_sensitive_facilities,
        COUNT(*) FILTER (WHERE n.facility_type = 'school') AS schools,
        COUNT(*) FILTER (WHERE n.facility_type = 'hospital') AS hospitals
    FROM noise_sensitive_facilities n
    WHERE ST_Intersects(b.geom_buffer, n.geom_point)
) f ON true
LEFT JOIN LATERAL (
    SELECT
        ROUND(SUM(g.population))::integer AS raw_population,
        ROUND(SUM(g.population * g.edm_fan_index))::integer AS weighted_population
    FROM population_grids g
    WHERE g.geom_polygon && b.geom_buffer
      AND ST_Intersects(g.geom_polygon, b.geom_buffer)
) p ON true
LEFT JOIN LATERAL (
    SELECT COUNT(DISTINCT e.reserve_id) AS intersecting_protected_areas
    FROM ecological_protected_areas e
    WHERE e.geom_polygon && b.geom_buffer
      AND ST_Intersects(e.geom_polygon, b.geom_buffer)
) e ON true
LEFT JOIN LATERAL (
    SELECT
        COUNT(*) FILTER (WHERE h.hub_type = 'airport') AS airports,
        COUNT(*) FILTER (WHERE h.hub_type = 'train_station') AS train_stations,
        COUNT(*) FILTER (WHERE h.hub_type = 'bus_terminal') AS bus_terminals
    FROM transport_hubs h
    WHERE ST_Intersects(b.geom_buffer, h.geom_point)
) t ON true;

SELECT *
FROM v_real_venue_noise_summary
ORDER BY venue_name, radius_km;
