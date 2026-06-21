-- Recalculate site_evaluations from current real spatial datasets.
-- Inputs: candidate_sites, transport_hubs, population_grids,
-- ecological_protected_areas, noise_sensitive_facilities.

BEGIN;

DELETE FROM site_evaluations;

WITH metrics AS (
    SELECT
        s.site_id,
        COALESCE(airport.nearest_airport_m, 1000000) AS nearest_airport_m,
        COALESCE(sensitive.nearest_sensitive_m, 1000000) AS nearest_sensitive_m,
        COALESCE(ecology.nearest_ecology_m, 1000000) AS nearest_ecology_m,
        COALESCE(pop.weighted_population_25km, 0) AS weighted_population_25km
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
        SELECT SUM(g.population * g.edm_fan_index) AS weighted_population_25km
        FROM population_grids g
        WHERE g.geom_polygon && ST_Expand(s.geom_polygon, 25000)
          AND ST_DWithin(s.geom_polygon, g.geom_polygon, 25000)
    ) pop ON true
),
scored AS (
    SELECT
        site_id,
        ROUND(GREATEST(0, LEAST(100, 100 - nearest_airport_m / 1000.0))::numeric, 2) AS airport_score,
        ROUND(
            CASE
                WHEN MAX(weighted_population_25km) OVER () = 0 THEN 0
                ELSE GREATEST(0, LEAST(100, weighted_population_25km / MAX(weighted_population_25km) OVER () * 100))
            END::numeric,
            2
        ) AS population_score,
        ROUND(GREATEST(0, LEAST(100, nearest_ecology_m / 1000.0))::numeric, 2) AS ecology_safety_score,
        ROUND(GREATEST(0, LEAST(100, nearest_sensitive_m / 100.0))::numeric, 2) AS noise_safety_score,
        nearest_airport_m,
        nearest_sensitive_m,
        nearest_ecology_m,
        weighted_population_25km
    FROM metrics
)
INSERT INTO site_evaluations
    (site_id, evaluated_at, airport_score, population_score, ecology_safety_score, noise_safety_score, total_score, method_note)
SELECT
    site_id,
    CURRENT_DATE AS evaluated_at,
    airport_score,
    population_score,
    ecology_safety_score,
    noise_safety_score,
    ROUND((0.30 * airport_score + 0.25 * population_score + 0.20 * ecology_safety_score + 0.25 * noise_safety_score)::numeric, 2) AS total_score,
    'Recalculated from PostGIS spatial metrics: nearest airport, 25 km Eurostat/GISCO weighted population, nearest Natura 2000 area, and nearest high-sensitivity OSM facility. Raw metrics: airport_m=' ||
        ROUND(nearest_airport_m)::text ||
        ', sensitive_m=' || ROUND(nearest_sensitive_m)::text ||
        ', ecology_m=' || ROUND(nearest_ecology_m)::text ||
        ', weighted_population_25km=' || ROUND(weighted_population_25km)::text AS method_note
FROM scored;

COMMIT;

SELECT
    s.site_id,
    s.name,
    e.airport_score,
    e.population_score,
    e.ecology_safety_score,
    e.noise_safety_score,
    e.total_score
FROM site_evaluations e
JOIN candidate_sites s ON s.site_id = e.site_id
ORDER BY e.total_score DESC
LIMIT 15;
