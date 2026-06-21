-- Migrate performances from a single-artist model to a performance block
-- plus performance_artists many-to-many model.

BEGIN;

DROP VIEW IF EXISTS v_tomorrowland_2025_timetable;
DROP VIEW IF EXISTS v_performance_count_by_genre;

ALTER TABLE performances
    ADD COLUMN IF NOT EXISTS official_performance_id varchar(120),
    ADD COLUMN IF NOT EXISTS performance_name varchar(240);

ALTER TABLE performances
    ALTER COLUMN artist_id DROP NOT NULL;

CREATE TABLE IF NOT EXISTS performance_artists (
    performance_id integer NOT NULL REFERENCES performances(performance_id) ON DELETE CASCADE,
    artist_id integer NOT NULL REFERENCES artists(artist_id),
    artist_order integer NOT NULL DEFAULT 1 CHECK (artist_order > 0),
    role varchar(40) NOT NULL DEFAULT 'primary',
    PRIMARY KEY (performance_id, artist_id)
);

-- Preserve existing non-Tomorrowland seed rows before dropping performances.artist_id.
INSERT INTO performance_artists (performance_id, artist_id, artist_order)
SELECT p.performance_id, p.artist_id, 1
FROM performances p
JOIN stages s ON s.stage_id = p.stage_id
WHERE s.edition_id <> 1
  AND p.artist_id IS NOT NULL
ON CONFLICT (performance_id, artist_id) DO NOTHING;

UPDATE performances p
SET performance_name = a.name
FROM artists a
WHERE p.artist_id = a.artist_id
  AND p.performance_name IS NULL;

-- Rebuild Tomorrowland 2025 as one row per official performance block.
DELETE FROM performances p
USING stages s
WHERE p.stage_id = s.stage_id
  AND s.edition_id = 1;

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
ON CONFLICT DO NOTHING;

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

ALTER TABLE performances DROP CONSTRAINT IF EXISTS uq_performance_slot;
ALTER TABLE performances DROP COLUMN IF EXISTS artist_id;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_performance_official_id'
    ) THEN
        ALTER TABLE performances
            ADD CONSTRAINT uq_performance_official_id UNIQUE (stage_id, official_performance_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_performance_block'
    ) THEN
        ALTER TABLE performances
            ADD CONSTRAINT uq_performance_block UNIQUE (stage_id, start_time, end_time, performance_name);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_performance_artists_artist_id
    ON performance_artists(artist_id);

SELECT setval(pg_get_serial_sequence('performances', 'performance_id'), (SELECT MAX(performance_id) FROM performances));

COMMIT;
