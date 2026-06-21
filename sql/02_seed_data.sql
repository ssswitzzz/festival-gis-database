-- Seed data for the Benelux electronic music festival database.
-- Public facts are used for names, cities, venues and broad dates.
-- Prices, quotas, capacities, costs, fan indexes and population samples are simulated for coursework demonstration.

BEGIN;

INSERT INTO organizers (organizer_id, name, country, website) VALUES
    (1, 'We Are One World', 'Belgium', 'https://www.tomorrowland.com/'),
    (2, 'Q-dance', 'Netherlands', 'https://www.q-dance.com/'),
    (3, 'Awakenings', 'Netherlands', 'https://www.awakenings.com/');

INSERT INTO festivals (festival_id, organizer_id, name, founded_year, home_country, website) VALUES
    (1, 1, 'Tomorrowland', 2005, 'Belgium', 'https://www.tomorrowland.com/'),
    (2, 2, 'Defqon.1', 2003, 'Netherlands', 'https://www.q-dance.com/'),
    (3, 3, 'Awakenings Summer Festival', 1997, 'Netherlands', 'https://www.awakenings.com/');

-- Geometry helper pattern:
-- ST_Transform(ST_SetSRID(ST_MakePoint(longitude, latitude), 4326), 3035)
INSERT INTO venues (venue_id, name, city, country, area_sqm, data_source, geom_polygon, geom_point) VALUES
    (
        1,
        'De Schorre',
        'Boom',
        'Belgium',
        750000,
        'Public venue location from official festival materials and OpenStreetMap-style coordinates; boundary approximated for coursework.',
        ST_Multi(ST_Transform(ST_MakeEnvelope(4.3610, 51.0830, 4.3920, 51.0995, 4326), 3035)),
        ST_Transform(ST_SetSRID(ST_MakePoint(4.3766, 51.0910), 4326), 3035)
    ),
    (
        2,
        'Walibi Holland event grounds',
        'Biddinghuizen',
        'Netherlands',
        950000,
        'Public venue location from official festival materials and OpenStreetMap-style coordinates; boundary approximated for coursework.',
        ST_Multi(ST_Transform(ST_MakeEnvelope(5.7390, 52.4290, 5.7800, 52.4495, 4326), 3035)),
        ST_Transform(ST_SetSRID(ST_MakePoint(5.7598, 52.4384), 4326), 3035)
    ),
    (
        3,
        'Beekse Bergen',
        'Hilvarenbeek',
        'Netherlands',
        1200000,
        'Public venue location from official festival materials and OpenStreetMap-style coordinates; boundary approximated for coursework.',
        ST_Multi(ST_Transform(ST_MakeEnvelope(5.1100, 51.5120, 5.1540, 51.5360, 4326), 3035)),
        ST_Transform(ST_SetSRID(ST_MakePoint(5.1322, 51.5240), 4326), 3035)
    );

INSERT INTO festival_editions
    (edition_id, festival_id, venue_id, year, start_date, end_date, expected_attendance, attendance_note)
VALUES
    (1, 1, 1, 2025, DATE '2025-07-18', DATE '2025-07-27', 400000, 'Approximate total across two weekends; use official/report sources in final report if exact count is required.'),
    (2, 2, 2, 2025, DATE '2025-06-26', DATE '2025-06-29', 250000, 'Approximate multi-day attendance for demonstration.'),
    (3, 3, 3, 2025, DATE '2025-07-11', DATE '2025-07-13', 100000, 'Approximate multi-day attendance for demonstration.');

INSERT INTO stages (stage_id, edition_id, name, capacity, geom_point) VALUES
    (1, 1, 'Mainstage', 60000, ST_Transform(ST_SetSRID(ST_MakePoint(4.3770, 51.0907), 4326), 3035)),
    (2, 1, 'Freedom', 25000, ST_Transform(ST_SetSRID(ST_MakePoint(4.3810, 51.0920), 4326), 3035)),
    (3, 1, 'Atmosphere', 18000, ST_Transform(ST_SetSRID(ST_MakePoint(4.3727, 51.0938), 4326), 3035)),
    (4, 2, 'RED', 55000, ST_Transform(ST_SetSRID(ST_MakePoint(5.7595, 52.4380), 4326), 3035)),
    (5, 2, 'BLUE', 22000, ST_Transform(ST_SetSRID(ST_MakePoint(5.7540, 52.4405), 4326), 3035)),
    (6, 2, 'BLACK', 16000, ST_Transform(ST_SetSRID(ST_MakePoint(5.7640, 52.4365), 4326), 3035)),
    (7, 3, 'Area V', 30000, ST_Transform(ST_SetSRID(ST_MakePoint(5.1326, 51.5241), 4326), 3035)),
    (8, 3, 'Area W', 18000, ST_Transform(ST_SetSRID(ST_MakePoint(5.1260, 51.5260), 4326), 3035));

INSERT INTO artists (artist_id, name, country) VALUES
    (1, 'Armin van Buuren', 'Netherlands'),
    (2, 'Charlotte de Witte', 'Belgium'),
    (3, 'Martin Garrix', 'Netherlands'),
    (4, 'Amelie Lens', 'Belgium'),
    (5, 'Angerfist', 'Netherlands'),
    (6, 'Sub Zero Project', 'Netherlands'),
    (7, 'Reinier Zonneveld', 'Netherlands'),
    (8, 'Kris Kross Amsterdam', 'Netherlands'),
    (9, 'Hardwell', 'Netherlands'),
    (10, 'Indira Paganotto', 'Spain');

INSERT INTO genres (genre_id, name) VALUES
    (1, 'trance'),
    (2, 'techno'),
    (3, 'big room house'),
    (4, 'hardstyle'),
    (5, 'hardcore'),
    (6, 'house');

INSERT INTO artist_genres (artist_id, genre_id) VALUES
    (1, 1),
    (2, 2),
    (3, 3),
    (4, 2),
    (5, 5),
    (6, 4),
    (7, 2),
    (8, 6),
    (9, 3),
    (10, 2);

INSERT INTO performances (performance_id, stage_id, performance_name, start_time, end_time, estimated_crowd) VALUES
    (1, 1, 'Martin Garrix', TIMESTAMP '2025-07-18 22:30', TIMESTAMP '2025-07-18 23:45', 52000),
    (2, 1, 'Armin van Buuren', TIMESTAMP '2025-07-19 21:00', TIMESTAMP '2025-07-19 22:15', 50000),
    (3, 2, 'Charlotte de Witte', TIMESTAMP '2025-07-19 23:00', TIMESTAMP '2025-07-20 00:30', 23000),
    (4, 3, 'Amelie Lens', TIMESTAMP '2025-07-20 20:00', TIMESTAMP '2025-07-20 21:30', 16000),
    (5, 4, 'Sub Zero Project', TIMESTAMP '2025-06-27 22:00', TIMESTAMP '2025-06-27 23:15', 48000),
    (6, 4, 'Hardwell', TIMESTAMP '2025-06-28 23:15', TIMESTAMP '2025-06-29 00:30', 50000),
    (7, 5, 'Angerfist', TIMESTAMP '2025-06-28 01:00', TIMESTAMP '2025-06-28 02:00', 21000),
    (8, 6, 'Sub Zero Project', TIMESTAMP '2025-06-29 20:00', TIMESTAMP '2025-06-29 21:00', 15000),
    (9, 7, 'Reinier Zonneveld', TIMESTAMP '2025-07-12 20:00', TIMESTAMP '2025-07-12 21:30', 27000),
    (10, 7, 'Indira Paganotto', TIMESTAMP '2025-07-12 22:00', TIMESTAMP '2025-07-12 23:30', 26000),
    (11, 8, 'Charlotte de Witte', TIMESTAMP '2025-07-13 19:00', TIMESTAMP '2025-07-13 20:30', 17000);

INSERT INTO performance_artists (performance_id, artist_id, artist_order) VALUES
    (1, 3, 1),
    (2, 1, 1),
    (3, 2, 1),
    (4, 4, 1),
    (5, 6, 1),
    (6, 9, 1),
    (7, 5, 1),
    (8, 6, 1),
    (9, 7, 1),
    (10, 10, 1),
    (11, 2, 1);

INSERT INTO ticket_types (edition_id, name, price_eur, quota, is_simulated) VALUES
    (1, 'Full Madness Pass', 355.00, 120000, true),
    (1, 'Day Pass', 145.00, 60000, true),
    (1, 'DreamVille Package', 620.00, 45000, true),
    (2, 'Weekend Ticket', 295.00, 70000, true),
    (2, 'Premium Weekend Ticket', 455.00, 12000, true),
    (2, 'Camping Upgrade', 85.00, 45000, true),
    (3, 'Weekend Ticket', 245.00, 45000, true),
    (3, 'Day Ticket', 99.00, 30000, true);

INSERT INTO transport_hubs (hub_id, name, hub_type, city, country, daily_capacity, data_source, geom_point) VALUES
    (1, 'Brussels Airport', 'airport', 'Zaventem', 'Belgium', 70000, 'OurAirports / public airport coordinates', ST_Transform(ST_SetSRID(ST_MakePoint(4.4844, 50.9014), 4326), 3035)),
    (2, 'Antwerp Central Station', 'train_station', 'Antwerp', 'Belgium', 65000, 'Public railway station coordinates', ST_Transform(ST_SetSRID(ST_MakePoint(4.4211, 51.2172), 4326), 3035)),
    (3, 'Amsterdam Airport Schiphol', 'airport', 'Amsterdam', 'Netherlands', 180000, 'OurAirports / public airport coordinates', ST_Transform(ST_SetSRID(ST_MakePoint(4.7639, 52.3105), 4326), 3035)),
    (4, 'Eindhoven Airport', 'airport', 'Eindhoven', 'Netherlands', 20000, 'OurAirports / public airport coordinates', ST_Transform(ST_SetSRID(ST_MakePoint(5.3745, 51.4501), 4326), 3035)),
    (5, 'Tilburg Station', 'train_station', 'Tilburg', 'Netherlands', 45000, 'Public railway station coordinates', ST_Transform(ST_SetSRID(ST_MakePoint(5.0830, 51.5606), 4326), 3035)),
    (6, 'Lelystad Centrum Station', 'train_station', 'Lelystad', 'Netherlands', 25000, 'Public railway station coordinates', ST_Transform(ST_SetSRID(ST_MakePoint(5.4730, 52.5080), 4326), 3035));

INSERT INTO candidate_sites
    (site_id, name, source_osm_id, terrain_type, area_sqm, daily_cost, data_source, is_manual_sample, geom_polygon)
VALUES
    (
        1,
        'Boom recreation candidate near De Schorre',
        'manual-boom-001',
        'recreation_ground',
        620000,
        52000,
        'Manual sample based on the plan''s OSM candidate-site categories; for workflow validation.',
        true,
        ST_Multi(ST_Transform(ST_MakeEnvelope(4.3580, 51.0810, 4.3970, 51.1015, 4326), 3035))
    ),
    (
        2,
        'Biddinghuizen event-field candidate',
        'manual-biddinghuizen-001',
        'events_venue',
        880000,
        61000,
        'Manual sample based on the plan''s OSM candidate-site categories; for workflow validation.',
        true,
        ST_Multi(ST_Transform(ST_MakeEnvelope(5.7350, 52.4260, 5.7835, 52.4510, 4326), 3035))
    ),
    (
        3,
        'Hilvarenbeek lake recreation candidate',
        'manual-hilvarenbeek-001',
        'camp_site_recreation',
        1050000,
        57000,
        'Manual sample based on the plan''s OSM candidate-site categories; for workflow validation.',
        true,
        ST_Multi(ST_Transform(ST_MakeEnvelope(5.1060, 51.5090, 5.1590, 51.5380, 4326), 3035))
    ),
    (
        4,
        'Flevoland open grassland candidate',
        'manual-flevoland-001',
        'grass',
        760000,
        39000,
        'Manual candidate away from existing festival venues for comparison.',
        true,
        ST_Multi(ST_Transform(ST_MakeEnvelope(5.5100, 52.4150, 5.5650, 52.4450, 4326), 3035))
    ),
    (
        5,
        'Kempen rural recreation candidate',
        'manual-kempen-001',
        'grass_recreation',
        680000,
        36000,
        'Manual candidate away from existing festival venues for comparison.',
        true,
        ST_Multi(ST_Transform(ST_MakeEnvelope(5.0100, 51.2850, 5.0600, 51.3180, 4326), 3035))
    );

-- Coarse synthetic grid cells: replace with Eurostat/GISCO population grid during the full data phase.
INSERT INTO population_grids (population, edm_fan_index, data_source, is_synthetic_sample, geom_polygon) VALUES
    (210000, 0.72, 'Synthetic 5 km-style grid around Antwerp/Mechelen for scoring demonstration.', true, ST_Transform(ST_MakeEnvelope(4.25, 51.00, 4.55, 51.22, 4326), 3035)),
    (145000, 0.66, 'Synthetic 5 km-style grid around Flevoland for scoring demonstration.', true, ST_Transform(ST_MakeEnvelope(5.58, 52.34, 5.88, 52.55, 4326), 3035)),
    (235000, 0.70, 'Synthetic 5 km-style grid around Tilburg/Eindhoven for scoring demonstration.', true, ST_Transform(ST_MakeEnvelope(5.00, 51.42, 5.32, 51.62, 4326), 3035)),
    (78000, 0.50, 'Synthetic rural grid for comparison candidate.', true, ST_Transform(ST_MakeEnvelope(5.45, 52.36, 5.72, 52.50, 4326), 3035)),
    (92000, 0.54, 'Synthetic rural grid for comparison candidate.', true, ST_Transform(ST_MakeEnvelope(4.92, 51.22, 5.12, 51.36, 4326), 3035));

INSERT INTO ecological_protected_areas (name, protect_type, data_source, geom_polygon) VALUES
    (
        'Rupel river valley protected-area sample',
        'Natura 2000 sample',
        'Manual simplified polygon; replace with EEA Natura 2000 boundary data.',
        ST_Multi(ST_Transform(ST_MakeEnvelope(4.3300, 51.0700, 4.3600, 51.0950, 4326), 3035))
    ),
    (
        'Veluwemeer protected-area sample',
        'Natura 2000 sample',
        'Manual simplified polygon; replace with EEA Natura 2000 boundary data.',
        ST_Multi(ST_Transform(ST_MakeEnvelope(5.6800, 52.4100, 5.7300, 52.4700, 4326), 3035))
    ),
    (
        'Kempen wetland protected-area sample',
        'Natura 2000 sample',
        'Manual simplified polygon; replace with EEA Natura 2000 boundary data.',
        ST_Multi(ST_Transform(ST_MakeEnvelope(5.0500, 51.2600, 5.1000, 51.3300, 4326), 3035))
    );

INSERT INTO noise_sensitive_facilities
    (name, facility_type, sensitivity_level, city, country, data_source, geom_point)
VALUES
    ('AZ Rivierenland campus Rumst', 'hospital', 5, 'Rumst', 'Belgium', 'Public hospital POI coordinate, approximated.', ST_Transform(ST_SetSRID(ST_MakePoint(4.4240, 51.0790), 4326), 3035)),
    ('Boom town residential center', 'residential', 4, 'Boom', 'Belgium', 'Manual residential center point for coursework demonstration.', ST_Transform(ST_SetSRID(ST_MakePoint(4.3710, 51.0875), 4326), 3035)),
    ('Dronten school cluster sample', 'school', 4, 'Dronten', 'Netherlands', 'Manual school cluster point for coursework demonstration.', ST_Transform(ST_SetSRID(ST_MakePoint(5.7140, 52.5250), 4326), 3035)),
    ('Biddinghuizen residential center', 'residential', 4, 'Biddinghuizen', 'Netherlands', 'Manual residential center point for coursework demonstration.', ST_Transform(ST_SetSRID(ST_MakePoint(5.6930, 52.4550), 4326), 3035)),
    ('Hilvarenbeek residential center', 'residential', 4, 'Hilvarenbeek', 'Netherlands', 'Manual residential center point for coursework demonstration.', ST_Transform(ST_SetSRID(ST_MakePoint(5.1380, 51.4850), 4326), 3035)),
    ('Tilburg hospital sample', 'hospital', 5, 'Tilburg', 'Netherlands', 'Manual hospital point for coursework demonstration.', ST_Transform(ST_SetSRID(ST_MakePoint(5.0820, 51.5550), 4326), 3035));

-- Initial manual scoring. The analysis script can recompute this with live spatial metrics after full data import.
INSERT INTO site_evaluations
    (site_id, evaluated_at, airport_score, population_score, ecology_safety_score, noise_safety_score, total_score, method_note)
VALUES
    (1, DATE '2026-06-19', 86, 88, 74, 62, ROUND((0.30*86 + 0.25*88 + 0.20*74 + 0.25*62)::numeric, 2), 'Manual initial score using the documented weighted model.'),
    (2, DATE '2026-06-19', 82, 71, 60, 78, ROUND((0.30*82 + 0.25*71 + 0.20*60 + 0.25*78)::numeric, 2), 'Manual initial score using the documented weighted model.'),
    (3, DATE '2026-06-19', 90, 84, 82, 75, ROUND((0.30*90 + 0.25*84 + 0.20*82 + 0.25*75)::numeric, 2), 'Manual initial score using the documented weighted model.'),
    (4, DATE '2026-06-19', 76, 55, 91, 86, ROUND((0.30*76 + 0.25*55 + 0.20*91 + 0.25*86)::numeric, 2), 'Manual initial score using the documented weighted model.'),
    (5, DATE '2026-06-19', 68, 58, 42, 81, ROUND((0.30*68 + 0.25*58 + 0.20*42 + 0.25*81)::numeric, 2), 'Manual initial score using the documented weighted model.');

SELECT setval(pg_get_serial_sequence('organizers', 'organizer_id'), (SELECT MAX(organizer_id) FROM organizers));
SELECT setval(pg_get_serial_sequence('festivals', 'festival_id'), (SELECT MAX(festival_id) FROM festivals));
SELECT setval(pg_get_serial_sequence('venues', 'venue_id'), (SELECT MAX(venue_id) FROM venues));
SELECT setval(pg_get_serial_sequence('festival_editions', 'edition_id'), (SELECT MAX(edition_id) FROM festival_editions));
SELECT setval(pg_get_serial_sequence('stages', 'stage_id'), (SELECT MAX(stage_id) FROM stages));
SELECT setval(pg_get_serial_sequence('artists', 'artist_id'), (SELECT MAX(artist_id) FROM artists));
SELECT setval(pg_get_serial_sequence('performances', 'performance_id'), (SELECT MAX(performance_id) FROM performances));
SELECT setval(pg_get_serial_sequence('genres', 'genre_id'), (SELECT MAX(genre_id) FROM genres));
SELECT setval(pg_get_serial_sequence('transport_hubs', 'hub_id'), (SELECT MAX(hub_id) FROM transport_hubs));
SELECT setval(pg_get_serial_sequence('candidate_sites', 'site_id'), (SELECT MAX(site_id) FROM candidate_sites));

COMMIT;
