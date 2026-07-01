-- Noise impact comparison views:
-- compare each real festival venue with the highest-scoring non-real candidate
-- in the same regional cluster, using 2 km, 5 km, and 10 km buffers.

DROP VIEW IF EXISTS v_noise_impact_comparison_summary;
DROP VIEW IF EXISTS v_noise_impact_comparison_overlay;
DROP VIEW IF EXISTS v_noise_impact_comparison_site_points;
DROP VIEW IF EXISTS v_noise_impact_comparison_buffers;
DROP VIEW IF EXISTS v_real_venue_candidate_comparison_sites;

CREATE OR REPLACE VIEW v_real_venue_candidate_comparison_sites AS
WITH real_candidate_matches AS (
    SELECT DISTINCT c.site_id
    FROM candidate_sites c
    JOIN venues v
      ON ST_DWithin(c.geom_polygon, v.geom_polygon, 1)
      OR c.name IN (
          'Walibi Holland',
          'Lake Resort Beekse Bergen',
          'Provinciaal Domein De Schorre'
      )
),
candidate_regions AS (
    SELECT
        c.site_id,
        c.display_name,
        c.name,
        c.total_score,
        v.venue_id,
        v.name AS venue_name,
        ROW_NUMBER() OVER (
            PARTITION BY c.site_id
            ORDER BY ST_Distance(c.geom_polygon, v.geom_polygon)
        ) AS nearest_venue_rank
    FROM v_site_score_explanation c
    CROSS JOIN venues v
    WHERE c.site_id NOT IN (SELECT site_id FROM real_candidate_matches)
),
regional_top_candidates AS (
    SELECT
        venue_id,
        venue_name,
        site_id,
        display_name,
        name,
        total_score,
        ROW_NUMBER() OVER (
            PARTITION BY venue_id
            ORDER BY total_score DESC, site_id
        ) AS regional_rank
    FROM candidate_regions
    WHERE nearest_venue_rank = 1
)
SELECT
    'real_venue'::text AS site_role,
    v.venue_id,
    v.name AS venue_name,
    NULL::integer AS site_id,
    v.name::text AS site_name,
    NULL::numeric AS total_score,
    v.area_sqm,
    v.data_source,
    v.geom_polygon
FROM venues v
UNION ALL
SELECT
    'top_non_real_candidate'::text AS site_role,
    c.venue_id,
    c.venue_name,
    c.site_id,
    c.display_name AS site_name,
    c.total_score,
    s.area_sqm,
    s.data_source,
    s.geom_polygon
FROM regional_top_candidates c
JOIN candidate_sites s
  ON s.site_id = c.site_id
WHERE c.regional_rank = 1;

CREATE OR REPLACE VIEW v_noise_impact_comparison_buffers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY venue_name, site_role, outer_radius_km) AS buffer_id,
    site_role,
    venue_id,
    venue_name,
    site_id,
    site_name,
    total_score,
    inner_radius_km,
    outer_radius_km AS radius_km,
    outer_radius_km,
    inner_radius_km * 1000 AS inner_radius_m,
    outer_radius_km * 1000 AS radius_m,
    outer_radius_km * 1000 AS outer_radius_m,
    CASE
        WHEN inner_radius_km = 0 THEN
            ST_Multi(ST_Buffer(geom_polygon, outer_radius_km * 1000))::geometry(MultiPolygon, 3035)
        ELSE
            ST_Multi(
                ST_Difference(
                    ST_Buffer(geom_polygon, outer_radius_km * 1000),
                    ST_Buffer(geom_polygon, inner_radius_km * 1000)
                )
            )::geometry(MultiPolygon, 3035)
    END AS geom_buffer
FROM v_real_venue_candidate_comparison_sites
CROSS JOIN (VALUES (0, 2), (2, 5), (5, 10)) AS r(inner_radius_km, outer_radius_km);

CREATE OR REPLACE VIEW v_noise_impact_comparison_site_points AS
SELECT
    ROW_NUMBER() OVER (ORDER BY venue_name, site_role) AS comparison_site_id,
    site_role,
    venue_id,
    venue_name,
    site_id,
    site_name,
    total_score,
    area_sqm,
    data_source,
    ST_PointOnSurface(geom_polygon)::geometry(Point, 3035) AS geom_point
FROM v_real_venue_candidate_comparison_sites;

CREATE OR REPLACE VIEW v_noise_impact_comparison_overlay AS
WITH per_venue AS (
    SELECT
        venue_id,
        venue_name,
        ST_UnaryUnion(ST_Collect(geom_buffer)) AS venue_geom
    FROM v_noise_impact_comparison_buffers
    GROUP BY venue_id, venue_name
),
boundaries AS (
    SELECT
        v.venue_id,
        v.venue_name,
        ST_CollectionExtract(
            ST_Node(
                ST_UnaryUnion(
                    ST_Collect(ST_Boundary(b.geom_buffer))
                )
            ),
            2
        ) AS boundary_geom,
        v.venue_geom
    FROM per_venue v
    JOIN v_noise_impact_comparison_buffers b
      ON b.venue_id = v.venue_id
    GROUP BY v.venue_id, v.venue_name, v.venue_geom
),
polygons AS (
    SELECT
        venue_id,
        venue_name,
        (ST_Dump(ST_Polygonize(line_geom))).geom AS geom_polygon
    FROM (
        SELECT
            venue_id,
            venue_name,
            (ST_Dump(boundary_geom)).geom AS line_geom
        FROM boundaries
    ) linework
    GROUP BY
        venue_id,
        venue_name
),
inside_polygons AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY venue_name, ST_Area(geom_polygon) DESC) AS overlay_id,
        venue_id,
        venue_name,
        ST_Multi(geom_polygon)::geometry(MultiPolygon, 3035) AS geom_polygon
    FROM polygons p
    WHERE ST_Area(geom_polygon) > 1
      AND EXISTS (
          SELECT 1
          FROM per_venue v
          WHERE v.venue_id = p.venue_id
            AND ST_PointOnSurface(p.geom_polygon) && v.venue_geom
            AND ST_Intersects(ST_PointOnSurface(p.geom_polygon), v.venue_geom)
      )
)
SELECT
    p.overlay_id,
    p.venue_id,
    p.venue_name,
    COALESCE(MAX(b.outer_radius_km) FILTER (
        WHERE b.site_role = 'real_venue'
          AND ST_Intersects(ST_PointOnSurface(p.geom_polygon), b.geom_buffer)
    ), 0) AS real_outer_radius_km,
    COALESCE(MAX(b.outer_radius_km) FILTER (
        WHERE b.site_role = 'top_non_real_candidate'
          AND ST_Intersects(ST_PointOnSurface(p.geom_polygon), b.geom_buffer)
    ), 0) AS candidate_outer_radius_km,
    COALESCE(MAX(b.outer_radius_km) FILTER (
        WHERE ST_Intersects(ST_PointOnSurface(p.geom_polygon), b.geom_buffer)
    ), 0) AS max_outer_radius_km,
    CONCAT(
        'real:',
        COALESCE(MAX(b.outer_radius_km) FILTER (
            WHERE b.site_role = 'real_venue'
              AND ST_Intersects(ST_PointOnSurface(p.geom_polygon), b.geom_buffer)
        ), 0),
        ' candidate:',
        COALESCE(MAX(b.outer_radius_km) FILTER (
            WHERE b.site_role = 'top_non_real_candidate'
              AND ST_Intersects(ST_PointOnSurface(p.geom_polygon), b.geom_buffer)
        ), 0)
    ) AS overlap_class,
    p.geom_polygon
FROM inside_polygons p
LEFT JOIN v_noise_impact_comparison_buffers b
  ON b.venue_id = p.venue_id
 AND ST_Intersects(ST_PointOnSurface(p.geom_polygon), b.geom_buffer)
GROUP BY
    p.overlay_id,
    p.venue_id,
    p.venue_name,
    p.geom_polygon;

CREATE OR REPLACE VIEW v_noise_impact_comparison_summary AS
SELECT
    b.site_role,
    b.venue_id,
    b.venue_name,
    b.site_id,
    b.site_name,
    b.total_score,
    b.radius_km,
    COALESCE(f.high_sensitive_facilities, 0) AS high_sensitive_facilities,
    COALESCE(f.schools, 0) AS schools,
    COALESCE(f.hospitals, 0) AS hospitals,
    COALESCE(p.raw_population, 0) AS raw_population,
    COALESCE(p.weighted_population, 0) AS weighted_population,
    COALESCE(e.intersecting_protected_areas, 0) AS intersecting_protected_areas
FROM v_noise_impact_comparison_buffers b
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
) e ON true;

SELECT
    venue_name,
    site_role,
    site_name,
    total_score,
    radius_km,
    high_sensitive_facilities,
    schools,
    hospitals,
    raw_population,
    weighted_population,
    intersecting_protected_areas
FROM v_noise_impact_comparison_summary
ORDER BY venue_name, site_role, radius_km;
