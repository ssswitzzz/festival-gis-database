-- Estimated Tomorrowland 2025 stage coordinates.
--
-- These are not official engineering coordinates. They are approximate points
-- interpreted from the 2025 Tomorrowland public visitor map supplied for the
-- coursework, placed within the OSM De Schorre venue boundary. Use them for
-- relative routing / timetable feasibility analysis only.

BEGIN;

CREATE TABLE IF NOT EXISTS stage_coordinate_sources (
    stage_id integer PRIMARY KEY REFERENCES stages(stage_id) ON DELETE CASCADE,
    source_type varchar(80) NOT NULL,
    source_description text NOT NULL,
    confidence varchar(80) NOT NULL,
    source_file text,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

WITH tl25 AS (
    SELECT fe.edition_id
    FROM festival_editions fe
    JOIN festivals f ON f.festival_id = fe.festival_id
    WHERE f.name = 'Tomorrowland'
      AND fe.year = 2025
),
coords(stage_name, lon, lat) AS (
    VALUES
        ('MAINSTAGE', 4.38470, 51.08865),
        ('FREEDOM BY BUD', 4.38435, 51.09170),
        ('THE ROSE GARDEN', 4.38300, 51.08895),
        ('PAPILLON', 4.38205, 51.09105),
        ('ELIXIR', 4.38215, 51.08795),
        ('CAGE', 4.38115, 51.09005),
        ('THE RAVE CAVE', 4.38025, 51.09025),
        ('PLANAXIS', 4.37980, 51.08670),
        ('MELODIA BY CORONA', 4.38145, 51.08695),
        ('RISE BY COCA-COLA', 4.38035, 51.08905),
        ('ATMOSPHERE', 4.38020, 51.08985),
        ('CORE', 4.38055, 51.09155),
        ('CRYSTAL GARDEN', 4.37885, 51.08785),
        ('THE GREAT LIBRARY', 4.37770, 51.08745),
        ('MOOSEBAR', 4.37755, 51.08875),
        ('HOUSE OF FORTUNE BY JBL', 4.37925, 51.09105),
        ('THE GATHERING', 4.37810, 51.09030),
        ('THE GATHERING - STAGE II', 4.37935, 51.09145)
)
UPDATE stages s
SET geom_point = ST_Transform(ST_SetSRID(ST_MakePoint(c.lon, c.lat), 4326), 3035)
FROM coords c
JOIN tl25 ON true
WHERE s.edition_id = tl25.edition_id
  AND s.name = c.stage_name;

-- Keep every estimated point inside the current OSM venue polygon. The public
-- visitor map includes operational areas that do not perfectly match the OSM
-- park polygon, so points near concave edges are snapped inward for topology.
UPDATE stages s
SET geom_point = ST_PointOnSurface(ST_Intersection(ST_Buffer(s.geom_point, 80), v.geom_polygon))
FROM festival_editions fe
JOIN festivals f ON f.festival_id = fe.festival_id
JOIN venues v ON v.venue_id = fe.venue_id
WHERE s.edition_id = fe.edition_id
  AND f.name = 'Tomorrowland'
  AND fe.year = 2025
  AND s.geom_point IS NOT NULL
  AND NOT ST_Within(s.geom_point, v.geom_polygon)
  AND NOT ST_IsEmpty(ST_Intersection(ST_Buffer(s.geom_point, 80), v.geom_polygon));

WITH tl25 AS (
    SELECT fe.edition_id
    FROM festival_editions fe
    JOIN festivals f ON f.festival_id = fe.festival_id
    WHERE f.name = 'Tomorrowland'
      AND fe.year = 2025
),
updated_stages AS (
    SELECT s.stage_id
    FROM stages s
    JOIN tl25 ON tl25.edition_id = s.edition_id
    WHERE s.geom_point IS NOT NULL
)
INSERT INTO stage_coordinate_sources (
    stage_id,
    source_type,
    source_description,
    confidence,
    source_file
)
SELECT
    stage_id,
    'estimated_from_public_map',
    'Approximate Tomorrowland 2025 stage point manually interpreted from public visitor map and constrained to the OSM De Schorre venue boundary; not official stage engineering coordinates.',
    'coursework_estimate',
    'C:\Users\12907\Desktop\2025TMLMAP_Alt_Mainstage.jpeg'
FROM updated_stages
ON CONFLICT (stage_id) DO UPDATE
SET
    source_type = EXCLUDED.source_type,
    source_description = EXCLUDED.source_description,
    confidence = EXCLUDED.confidence,
    source_file = EXCLUDED.source_file,
    created_at = CURRENT_TIMESTAMP;

COMMIT;

SELECT
    s.name,
    ROUND(ST_X(ST_Transform(s.geom_point, 4326))::numeric, 6) AS lon,
    ROUND(ST_Y(ST_Transform(s.geom_point, 4326))::numeric, 6) AS lat,
    scs.confidence
FROM stages s
JOIN festival_editions fe ON fe.edition_id = s.edition_id
JOIN festivals f ON f.festival_id = fe.festival_id
LEFT JOIN stage_coordinate_sources scs ON scs.stage_id = s.stage_id
WHERE f.name = 'Tomorrowland'
  AND fe.year = 2025
ORDER BY s.name;
