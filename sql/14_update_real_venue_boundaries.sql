-- Replace coarse venue demonstration polygons with reviewed public boundary
-- geometries where a suitable OSM candidate-site boundary exists.

BEGIN;

UPDATE venues v
SET
    geom_polygon = c.geom_polygon,
    area_sqm = c.area_sqm,
    data_source = 'OpenStreetMap candidate_sites boundary: Provinciaal Domein De Schorre; represents park/venue boundary, not official Tomorrowland operational perimeter.'
FROM candidate_sites c
WHERE v.name = 'De Schorre'
  AND c.name = 'Provinciaal Domein De Schorre';

COMMIT;

SELECT
    venue_id,
    name,
    area_sqm,
    data_source,
    ROUND(ST_Area(geom_polygon)) AS geom_area_sqm
FROM venues
WHERE name = 'De Schorre';
