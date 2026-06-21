-- Staging tables for reviewed business-data candidates scraped from official festival pages.
-- These tables keep source URL and evidence snippets so values remain auditable.

DROP TABLE IF EXISTS stg_business_fact_candidates;
DROP TABLE IF EXISTS stg_business_ticket_candidates;
DROP TABLE IF EXISTS stg_business_lineup_candidates;
DROP TABLE IF EXISTS stg_business_scrape_pages;

CREATE TABLE stg_business_scrape_pages (
    festival text,
    edition_year integer,
    label text,
    url text,
    final_url text,
    status integer,
    content_type text,
    elapsed_seconds numeric,
    saved_html text,
    content_hash text,
    scraped_at timestamptz
);

CREATE TABLE stg_business_fact_candidates (
    festival text,
    edition_year integer,
    source_label text,
    source_url text,
    fact_type text,
    value text,
    confidence text,
    evidence text,
    scraped_at timestamptz
);

CREATE TABLE stg_business_ticket_candidates (
    festival text,
    edition_year integer,
    source_label text,
    source_url text,
    ticket_name text,
    price_eur numeric(10,2),
    currency text,
    confidence text,
    evidence text,
    scraped_at timestamptz
);

CREATE TABLE stg_business_lineup_candidates (
    festival text,
    edition_year integer,
    source_label text,
    source_url text,
    artist_name text,
    stage_name text,
    start_time text,
    end_time text,
    confidence text,
    evidence text,
    scraped_at timestamptz
);

-- Example import commands from psql:
-- \copy stg_business_scrape_pages FROM 'data/processed/business_scrape_pages.csv' WITH CSV HEADER ENCODING 'UTF8'
-- \copy stg_business_fact_candidates FROM 'data/processed/business_fact_candidates.csv' WITH CSV HEADER ENCODING 'UTF8'
-- \copy stg_business_ticket_candidates FROM 'data/processed/business_ticket_candidates.csv' WITH CSV HEADER ENCODING 'UTF8'
-- \copy stg_business_lineup_candidates FROM 'data/processed/business_lineup_candidates.csv' WITH CSV HEADER ENCODING 'UTF8'

CREATE INDEX idx_stg_business_facts_festival ON stg_business_fact_candidates (festival, edition_year, fact_type);
CREATE INDEX idx_stg_business_tickets_festival ON stg_business_ticket_candidates (festival, edition_year);
CREATE INDEX idx_stg_business_lineup_festival ON stg_business_lineup_candidates (festival, edition_year);
