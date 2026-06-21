-- Import representative Belgium/Netherlands airports from OurAirports into transport_hubs.
-- Run after scripts/import_ourairports.ps1.

BEGIN;

WITH selected_airports AS (
    SELECT
        name,
        type,
        municipality,
        CASE
            WHEN iso_country = 'BE' THEN 'Belgium'
            WHEN iso_country = 'NL' THEN 'Netherlands'
            ELSE iso_country
        END AS country,
        ident,
        iata_code,
        scheduled_service,
        ST_Transform(
            ST_SetSRID(ST_MakePoint(longitude_deg, latitude_deg), 4326),
            3035
        )::geometry(Point, 3035) AS geom_point
    FROM stg_ourairports_airports
    WHERE iso_country IN ('BE', 'NL')
      AND latitude_deg IS NOT NULL
      AND longitude_deg IS NOT NULL
      AND (
          type IN ('large_airport', 'medium_airport')
          OR (type = 'small_airport' AND scheduled_service = 'yes')
      )
),
deduped_airports AS (
    SELECT *
    FROM selected_airports source
    WHERE NOT EXISTS (
        SELECT 1
        FROM transport_hubs existing
        WHERE existing.hub_type = 'airport'
          AND (
              lower(existing.name) = lower(source.name)
              OR ST_DWithin(existing.geom_point, source.geom_point, 2000)
          )
    )
)
INSERT INTO transport_hubs
    (name, hub_type, city, country, daily_capacity, data_source, geom_point)
SELECT
    name,
    'airport' AS hub_type,
    NULLIF(municipality, '') AS city,
    country,
    NULL AS daily_capacity,
    'OurAirports airports.csv, filtered to BE/NL large/medium airports and scheduled small airports; ident=' ||
        COALESCE(ident, '') ||
        CASE WHEN NULLIF(iata_code, '') IS NOT NULL THEN ', iata=' || iata_code ELSE '' END ||
        ', type=' || COALESCE(type, '') ||
        ', scheduled_service=' || COALESCE(scheduled_service, '') AS data_source,
    geom_point
FROM deduped_airports;

COMMIT;

SELECT
    hub_type,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE data_source LIKE 'OurAirports airports.csv%') AS ourairports_rows
FROM transport_hubs
GROUP BY hub_type
ORDER BY hub_type;
