-- Reusable analysis queries for report screenshots and validation.

-- 1. Complete timetable for Tomorrowland 2025.
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
  AND e.year = 2025
ORDER BY p.start_time, s.name;

-- 2. Performance count by genre, festival and year.
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
GROUP BY f.name, e.year, g.name
ORDER BY f.name, e.year, performance_count DESC;

-- 3. Spatial multi-criteria filtering.
SELECT s.site_id, s.name, s.area_sqm
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

-- 4. Affected population estimate for every candidate site's 5 km noise buffer.
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
GROUP BY site_id, site_name
ORDER BY total_affected_population DESC;

-- 5. Match top candidate sites to real festival venues within 10 km.
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
  ON e.festival_id = f.festival_id
ORDER BY distance_to_real_venue_m ASC;

-- 6. Venue operating scale and high-sensitivity facility count within 5 km.
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
GROUP BY v.venue_id, v.name
ORDER BY max_expected_attendance DESC;

-- 7. Recompute site evaluation metrics from the current spatial sample.
-- This query returns a dynamic score table without overwriting site_evaluations.
WITH nearest AS (
    SELECT
        s.site_id,
        MIN(ST_Distance(s.geom_polygon, h.geom_point)) FILTER (WHERE h.hub_type = 'airport') AS nearest_airport_m,
        MIN(ST_Distance(s.geom_polygon, n.geom_point)) FILTER (WHERE n.sensitivity_level >= 4) AS nearest_sensitive_m,
        MIN(ST_Distance(s.geom_polygon, e.geom_polygon)) AS nearest_ecology_m
    FROM candidate_sites s
    LEFT JOIN transport_hubs h ON h.hub_type = 'airport'
    LEFT JOIN noise_sensitive_facilities n ON n.sensitivity_level >= 4
    LEFT JOIN ecological_protected_areas e ON true
    GROUP BY s.site_id
),
pop AS (
    SELECT
        s.site_id,
        COALESCE(SUM(g.population * g.edm_fan_index), 0) AS weighted_population
    FROM candidate_sites s
    LEFT JOIN population_grids g
      ON ST_DWithin(s.geom_polygon, g.geom_polygon, 50000)
    GROUP BY s.site_id
),
scored AS (
    SELECT
        s.site_id,
        s.name,
        ROUND(GREATEST(0, LEAST(100, 100 - (nearest_airport_m / 1000.0)))::numeric, 2) AS airport_score,
        ROUND(GREATEST(0, LEAST(100, weighted_population / 3000.0))::numeric, 2) AS population_score,
        ROUND(GREATEST(0, LEAST(100, nearest_ecology_m / 100.0))::numeric, 2) AS ecology_safety_score,
        ROUND(GREATEST(0, LEAST(100, nearest_sensitive_m / 100.0))::numeric, 2) AS noise_safety_score
    FROM candidate_sites s
    JOIN nearest n ON s.site_id = n.site_id
    JOIN pop p ON s.site_id = p.site_id
)
SELECT
    *,
    ROUND((0.30 * airport_score + 0.25 * population_score + 0.20 * ecology_safety_score + 0.25 * noise_safety_score)::numeric, 2) AS total_score
FROM scored
ORDER BY total_score DESC;
