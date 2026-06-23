-- Remove early demonstration rows that have been superseded by imported public data.
-- Keep business seed rows that are still referenced by official lineup data or by
-- festivals without a fuller imported workflow.

BEGIN;

-- Manual candidate sites have been replaced by OpenStreetMap candidate_sites.
-- site_evaluations references candidate_sites with ON DELETE CASCADE, so the
-- five manual evaluation rows are removed with their candidate rows.
DELETE FROM candidate_sites
WHERE is_manual_sample = true;

-- Manual simplified protected areas have been replaced by EEA Natura 2000 data.
DELETE FROM ecological_protected_areas
WHERE data_source LIKE 'Manual simplified polygon%';

-- Manual noise-sensitive sample points have been replaced by OSM POI imports.
DELETE FROM noise_sensitive_facilities
WHERE data_source ILIKE '%Manual%'
   OR data_source ILIKE '%approximated%';

-- Early transport hub samples have been replaced by OSM transport POIs and
-- OurAirports imports with source-specific provenance.
DELETE FROM transport_hubs
WHERE data_source IN (
    'OurAirports / public airport coordinates',
    'Public railway station coordinates'
);

COMMIT;

SELECT 'candidate_sites' AS table_name, COUNT(*) AS rows FROM candidate_sites
UNION ALL
SELECT 'site_evaluations', COUNT(*) FROM site_evaluations
UNION ALL
SELECT 'ecological_protected_areas', COUNT(*) FROM ecological_protected_areas
UNION ALL
SELECT 'noise_sensitive_facilities', COUNT(*) FROM noise_sensitive_facilities
UNION ALL
SELECT 'transport_hubs', COUNT(*) FROM transport_hubs
ORDER BY table_name;
