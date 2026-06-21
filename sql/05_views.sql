-- Report views for repeated inspection in pgAdmin, psql or QGIS.

CREATE OR REPLACE VIEW v_tomorrowland_2025_timetable AS
SELECT
    f.name AS festival_name,
    e.year,
    v.name AS venue_name,
    s.name AS stage_name,
    a.name AS artist_name,
    p.start_time,
    p.end_time,
    p.estimated_crowd
FROM festival_editions e
JOIN festivals f ON e.festival_id = f.festival_id
JOIN venues v ON e.venue_id = v.venue_id
JOIN stages s ON e.edition_id = s.edition_id
JOIN performances p ON s.stage_id = p.stage_id
JOIN performance_artists pa ON p.performance_id = pa.performance_id
JOIN artists a ON pa.artist_id = a.artist_id
WHERE f.name = 'Tomorrowland'
  AND e.year = 2025;

CREATE OR REPLACE VIEW v_performance_count_by_genre AS
SELECT
    f.name AS festival_name,
    e.year,
    g.name AS genre_name,
    COUNT(*) AS performance_count
FROM festival_editions e
JOIN festivals f ON e.festival_id = f.festival_id
JOIN stages s ON e.edition_id = s.edition_id
JOIN performances p ON s.stage_id = p.stage_id
JOIN performance_artists pa ON p.performance_id = pa.performance_id
JOIN artist_genres ag ON pa.artist_id = ag.artist_id
JOIN genres g ON ag.genre_id = g.genre_id
GROUP BY f.name, e.year, g.name;

CREATE OR REPLACE VIEW v_multicriteria_candidate_sites AS
SELECT
    s.site_id,
    s.name,
    s.terrain_type,
    s.area_sqm,
    s.geom_polygon
FROM candidate_sites s
WHERE s.area_sqm >= 100000
  AND EXISTS (
      SELECT 1
      FROM transport_hubs h
      WHERE h.hub_type = 'airport'
        AND ST_DWithin(s.geom_polygon, h.geom_point, 80000)
  )
  AND NOT EXISTS (
      SELECT 1
      FROM ecological_protected_areas e
      WHERE ST_Intersects(s.geom_polygon, e.geom_polygon)
  )
  AND NOT EXISTS (
      SELECT 1
      FROM noise_sensitive_facilities n
      WHERE n.sensitivity_level >= 4
        AND ST_DWithin(s.geom_polygon, n.geom_point, 3000)
  );

CREATE OR REPLACE VIEW v_affected_population_5km AS
WITH site_buffer AS (
    SELECT
        site_id,
        name,
        ST_Buffer(geom_polygon, 5000) AS geom_buffer
    FROM candidate_sites
),
intersected_population AS (
    SELECT
        sb.site_id,
        sb.name AS site_name,
        g.grid_id,
        g.population *
        (
            ST_Area(ST_Intersection(sb.geom_buffer, g.geom_polygon))
            / NULLIF(ST_Area(g.geom_polygon), 0)
        ) AS affected_population
    FROM site_buffer sb
    JOIN population_grids g
      ON ST_Intersects(sb.geom_buffer, g.geom_polygon)
)
SELECT
    site_id,
    site_name,
    ROUND(SUM(affected_population))::int AS total_affected_population
FROM intersected_population
GROUP BY site_id, site_name;

CREATE OR REPLACE VIEW v_real_venue_match_validation AS
WITH ranked_sites AS (
    SELECT
        s.site_id,
        s.name,
        ev.total_score,
        s.geom_polygon
    FROM candidate_sites s
    JOIN site_evaluations ev
      ON s.site_id = ev.site_id
    ORDER BY ev.total_score DESC
    LIMIT 20
)
SELECT
    r.site_id,
    r.name AS candidate_site,
    r.total_score,
    v.name AS real_venue,
    f.name AS festival_name,
    e.year,
    ROUND(ST_Distance(r.geom_polygon, v.geom_point)) AS distance_to_real_venue_m
FROM ranked_sites r
JOIN venues v
  ON ST_DWithin(r.geom_polygon, v.geom_point, 10000)
JOIN festival_editions e
  ON v.venue_id = e.venue_id
JOIN festivals f
  ON e.festival_id = f.festival_id;

CREATE OR REPLACE VIEW v_venue_scale_risk_summary AS
SELECT
    v.venue_id,
    v.name AS venue_name,
    COUNT(DISTINCT e.edition_id) AS edition_count,
    MAX(e.expected_attendance) AS max_expected_attendance,
    COUNT(DISTINCT n.facility_id) AS sensitive_facility_count_5km
FROM venues v
JOIN festival_editions e
  ON v.venue_id = e.venue_id
LEFT JOIN noise_sensitive_facilities n
  ON n.sensitivity_level >= 4
 AND ST_DWithin(v.geom_point, n.geom_point, 5000)
GROUP BY v.venue_id, v.name;

CREATE OR REPLACE VIEW v_dynamic_site_scores AS
WITH metrics AS (
    SELECT
        s.site_id,
        COALESCE(airport.nearest_airport_m, 1000000) AS nearest_airport_m,
        COALESCE(sensitive.nearest_sensitive_m, 1000000) AS nearest_sensitive_m,
        COALESCE(ecology.nearest_ecology_m, 1000000) AS nearest_ecology_m,
        COALESCE(pop.weighted_population, 0) AS weighted_population
    FROM candidate_sites s
    LEFT JOIN LATERAL (
        SELECT ST_Distance(s.geom_polygon, h.geom_point) AS nearest_airport_m
        FROM transport_hubs h
        WHERE h.hub_type = 'airport'
        ORDER BY s.geom_polygon <-> h.geom_point
        LIMIT 1
    ) airport ON true
    LEFT JOIN LATERAL (
        SELECT ST_Distance(s.geom_polygon, n.geom_point) AS nearest_sensitive_m
        FROM noise_sensitive_facilities n
        WHERE n.sensitivity_level >= 4
        ORDER BY s.geom_polygon <-> n.geom_point
        LIMIT 1
    ) sensitive ON true
    LEFT JOIN LATERAL (
        SELECT ST_Distance(s.geom_polygon, e.geom_polygon) AS nearest_ecology_m
        FROM ecological_protected_areas e
        ORDER BY s.geom_polygon <-> e.geom_polygon
        LIMIT 1
    ) ecology ON true
    LEFT JOIN LATERAL (
        SELECT SUM(g.population * g.edm_fan_index) AS weighted_population
        FROM population_grids g
        WHERE g.geom_polygon && ST_Expand(s.geom_polygon, 25000)
          AND ST_DWithin(s.geom_polygon, g.geom_polygon, 25000)
    ) pop ON true
),
scored AS (
    SELECT
        s.site_id,
        s.name,
        ROUND(GREATEST(0, LEAST(100, 100 - (nearest_airport_m / 1000.0)))::numeric, 2) AS airport_score,
        ROUND(
            CASE
                WHEN MAX(weighted_population) OVER () = 0 THEN 0
                ELSE GREATEST(0, LEAST(100, weighted_population / MAX(weighted_population) OVER () * 100))
            END::numeric,
            2
        ) AS population_score,
        ROUND(GREATEST(0, LEAST(100, nearest_ecology_m / 1000.0))::numeric, 2) AS ecology_safety_score,
        ROUND(GREATEST(0, LEAST(100, nearest_sensitive_m / 100.0))::numeric, 2) AS noise_safety_score
    FROM candidate_sites s
    JOIN metrics m ON s.site_id = m.site_id
)
SELECT
    *,
    ROUND((0.30 * airport_score + 0.25 * population_score + 0.20 * ecology_safety_score + 0.25 * noise_safety_score)::numeric, 2) AS total_score
FROM scored;
