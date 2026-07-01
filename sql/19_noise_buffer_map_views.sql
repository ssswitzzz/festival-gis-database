-- Helper views for the report map:
-- noise-sensitive facilities and 5 km candidate-site impact buffers.

CREATE OR REPLACE VIEW v_candidate_site_5km_buffers AS
SELECT
    site_id,
    display_name,
    name AS source_name,
    total_score,
    high_sensitive_count_5km,
    ST_Buffer(geom_polygon, 5000) AS geom_buffer
FROM v_site_score_explanation;

CREATE OR REPLACE VIEW v_candidate_site_noise_summary AS
SELECT
    s.site_id,
    s.display_name,
    s.name AS source_name,
    s.total_score,
    COUNT(n.facility_id) FILTER (WHERE n.sensitivity_level >= 4) AS sensitive_count_5km,
    COUNT(n.facility_id) FILTER (WHERE n.facility_type = 'school') AS school_count_5km,
    COUNT(n.facility_id) FILTER (WHERE n.facility_type = 'hospital') AS hospital_count_5km,
    ST_Buffer(s.geom_polygon, 5000) AS geom_buffer
FROM v_site_score_explanation s
LEFT JOIN noise_sensitive_facilities n
  ON ST_DWithin(s.geom_polygon, n.geom_point, 5000)
GROUP BY
    s.site_id,
    s.display_name,
    s.name,
    s.total_score,
    s.geom_polygon;
