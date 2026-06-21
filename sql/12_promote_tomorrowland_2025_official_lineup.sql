-- Promote reviewed Tomorrowland 2025 official lineup/timetable staging data
-- into the core business tables.
--
-- Notes:
-- - The source staging tables are loaded by sql/11_import_tomorrowland_2025_lineup.sql.
-- - performances stores one official performance block; collaborations and
--   multi-artist slots are represented in performance_artists.
-- - Existing Tomorrowland 2025 seed performances are removed before importing
--   the official timetable, so the core table does not mix sample and official
--   lineup data for this edition.

BEGIN;

-- Align the edition date range with the official captured timetable window.
UPDATE festival_editions e
SET
    start_date = DATE '2025-07-17',
    end_date = DATE '2025-07-28',
    attendance_note = 'Approximate total across two weekends; lineup/timetable imported from official Tomorrowland TLBE25 JSON captured via Wayback Machine snapshot 2025-07-19.'
FROM festivals f
WHERE e.festival_id = f.festival_id
  AND f.name = 'Tomorrowland'
  AND e.year = 2025;

-- Reuse the three original seed stage rows by renaming them to official names.
UPDATE stages s
SET name = official.name
FROM (
    VALUES
        ('Mainstage', 'MAINSTAGE'),
        ('Freedom', 'FREEDOM BY BUD'),
        ('Atmosphere', 'ATMOSPHERE')
) AS official(old_name, name)
WHERE s.edition_id = 1
  AND s.name = official.old_name
  AND NOT EXISTS (
      SELECT 1
      FROM stages existing
      WHERE existing.edition_id = s.edition_id
        AND existing.name = official.name
        AND existing.stage_id <> s.stage_id
  );

-- Add the remaining official stages. Capacity and exact stage geometry remain
-- null unless a later source gives reliable per-stage details.
INSERT INTO stages (edition_id, name, capacity, geom_point)
SELECT
    1 AS edition_id,
    stg.stage_name,
    NULL::integer AS capacity,
    NULL::geometry(Point, 3035) AS geom_point
FROM stg_tomorrowland_2025_stages stg
WHERE NOT EXISTS (
    SELECT 1
    FROM stages s
    WHERE s.edition_id = 1
      AND s.name = stg.stage_name
);

-- Add missing artists by official artist name. Country remains null unless
-- confirmed from a separate reliable source.
INSERT INTO artists (name, country)
SELECT DISTINCT trim(artist_name), NULL::varchar(80)
FROM stg_tomorrowland_2025_artists
WHERE trim(artist_name) <> ''
  AND NOT EXISTS (
      SELECT 1
      FROM artists a
      WHERE a.name = trim(stg_tomorrowland_2025_artists.artist_name)
  );

-- Remove prior sample Tomorrowland performances before loading official data.
DELETE FROM performances p
USING stages s
WHERE p.stage_id = s.stage_id
  AND s.edition_id = 1;

-- Insert official timetable rows, one row per official performance block.
INSERT INTO performances (
    stage_id,
    official_performance_id,
    performance_name,
    start_time,
    end_time,
    estimated_crowd
)
SELECT
    s.stage_id,
    p.official_performance_id,
    NULLIF(trim(p.performance_name), '') AS performance_name,
    left(p.start_time_local, 19)::timestamp AS start_time,
    left(p.end_time_local, 19)::timestamp AS end_time,
    NULL::integer AS estimated_crowd
FROM stg_tomorrowland_2025_performances p
JOIN stages s
  ON s.edition_id = 1
 AND s.name = p.stage_name
WHERE left(p.end_time_local, 19)::timestamp > left(p.start_time_local, 19)::timestamp
ON CONFLICT (stage_id, official_performance_id) DO UPDATE
SET
    performance_name = EXCLUDED.performance_name,
    start_time = EXCLUDED.start_time,
    end_time = EXCLUDED.end_time,
    estimated_crowd = EXCLUDED.estimated_crowd;

-- Link official timetable rows to their listed artists. Artist order is derived
-- from the pipe-delimited official artist_names field.
WITH official_artist_slots AS (
    SELECT
        s.stage_id,
        p.official_performance_id,
        trim(artist_name.value) AS artist_name,
        artist_name.ordinality::integer AS artist_order
    FROM stg_tomorrowland_2025_performances p
    JOIN stages s
      ON s.edition_id = 1
     AND s.name = p.stage_name
    CROSS JOIN LATERAL regexp_split_to_table(COALESCE(p.artist_names, ''), '\|') WITH ORDINALITY AS artist_name(value, ordinality)
    WHERE trim(artist_name.value) <> ''
)
INSERT INTO performance_artists (performance_id, artist_id, artist_order)
SELECT
    p.performance_id,
    a.artist_id,
    MIN(slots.artist_order) AS artist_order
FROM official_artist_slots slots
JOIN performances p
  ON p.stage_id = slots.stage_id
 AND p.official_performance_id = slots.official_performance_id
JOIN artists a
  ON a.name = slots.artist_name
GROUP BY p.performance_id, a.artist_id
ON CONFLICT (performance_id, artist_id) DO UPDATE
SET artist_order = EXCLUDED.artist_order;

SELECT setval(pg_get_serial_sequence('stages', 'stage_id'), (SELECT MAX(stage_id) FROM stages));
SELECT setval(pg_get_serial_sequence('artists', 'artist_id'), (SELECT MAX(artist_id) FROM artists));
SELECT setval(pg_get_serial_sequence('performances', 'performance_id'), (SELECT MAX(performance_id) FROM performances));

COMMIT;
