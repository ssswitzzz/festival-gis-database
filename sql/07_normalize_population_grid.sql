-- Replace synthetic population grid samples with Eurostat/GISCO Census Grid 2021 data.
-- Run after scripts/import_population_grid.ps1.

BEGIN;

DELETE FROM population_grids
WHERE is_synthetic_sample = true
   OR data_source LIKE 'Eurostat/GISCO Census Grid 2021%';

INSERT INTO population_grids
    (population, edm_fan_index, data_source, is_synthetic_sample, geom_polygon)
SELECT
    GREATEST("T", 0)::integer AS population,
    0.080::numeric(4,3) AS edm_fan_index,
    'Eurostat/GISCO Census Grid 2021 Version 3, downloaded 2026-06, countries filtered by CNTR_ID BE/NL' AS data_source,
    false AS is_synthetic_sample,
    geom::geometry(Polygon, 3035) AS geom_polygon
FROM "stg_eurostat_census_grid_2021"
WHERE geom IS NOT NULL
  AND ST_IsValid(geom)
  AND "T" IS NOT NULL
  AND "T" >= 0
  AND (
      "CNTR_ID" LIKE '%BE%'
      OR "CNTR_ID" LIKE '%NL%'
  );

COMMIT;

ANALYZE population_grids;

SELECT
    COUNT(*) AS total_population_grid_rows,
    COUNT(*) FILTER (WHERE is_synthetic_sample = false) AS real_population_grid_rows,
    SUM(population) AS total_population,
    MIN(population) AS min_cell_population,
    MAX(population) AS max_cell_population
FROM population_grids;
