-- Import parsed Defqon.1 and Awakenings 2025 capture facts into staging tables.
-- These are staging facts only: Defqon pages did not expose explicit official prices,
-- and Awakenings package prices are accommodation/travel products, not festival tickets.

DROP TABLE IF EXISTS stg_defqon_2025_page_facts;

CREATE TABLE stg_defqon_2025_page_facts (
    festival text,
    edition_year integer,
    source_url text,
    capture_timestamp text,
    page_slug text,
    html_title text,
    page_title text,
    page_festival_year integer,
    description text,
    date_candidates text,
    ticket_terms text,
    shop_or_paylogic_links text,
    price_candidates text,
    price_note text,
    confidence text,
    source_file text
);

\copy stg_defqon_2025_page_facts (festival, edition_year, source_url, capture_timestamp, page_slug, html_title, page_title, page_festival_year, description, date_candidates, ticket_terms, shop_or_paylogic_links, price_candidates, price_note, confidence, source_file) FROM 'data/processed/defqon_2025_wayback_page_facts.csv' WITH CSV HEADER ENCODING 'UTF8'

CREATE INDEX idx_stg_defqon_2025_page_facts_slug ON stg_defqon_2025_page_facts (page_slug);
CREATE INDEX idx_stg_defqon_2025_page_facts_confidence ON stg_defqon_2025_page_facts (confidence);

DROP TABLE IF EXISTS stg_awakenings_2025_event_facts;

CREATE TABLE stg_awakenings_2025_event_facts (
    festival text,
    edition_year integer,
    official_event_id text,
    name text,
    title text,
    location text,
    start_date date,
    start_time time,
    end_date date,
    end_time time,
    minimal_age integer,
    state text,
    currency text,
    category_count integer,
    category_titles text,
    source_url_hint text,
    source_file text,
    confidence text
);

\copy stg_awakenings_2025_event_facts (festival, edition_year, official_event_id, name, title, location, start_date, start_time, end_date, end_time, minimal_age, state, currency, category_count, category_titles, source_url_hint, source_file, confidence) FROM 'data/processed/awakenings_2025_event_facts_current_official.csv' WITH CSV HEADER ENCODING 'UTF8'

DROP TABLE IF EXISTS stg_awakenings_2025_package_prices;

CREATE TABLE stg_awakenings_2025_package_prices (
    festival text,
    edition_year integer,
    package_id text,
    event_id text,
    accommodation_id text,
    package_name text,
    main_category text,
    category_title text,
    basic_sale_price_eur numeric(10,2),
    basic_sale_price_cents integer,
    currency text,
    regular_stay_from_date date,
    regular_stay_until_date date,
    extended_stay_from_date date,
    extended_stay_until_date date,
    bookable boolean,
    show_price boolean,
    sold_out boolean,
    wishlist_only boolean,
    ticket_descriptions text,
    deposit_note text,
    source_url_hint text,
    source_file text,
    confidence text
);

\copy stg_awakenings_2025_package_prices (festival, edition_year, package_id, event_id, accommodation_id, package_name, main_category, category_title, basic_sale_price_eur, basic_sale_price_cents, currency, regular_stay_from_date, regular_stay_until_date, extended_stay_from_date, extended_stay_until_date, bookable, show_price, sold_out, wishlist_only, ticket_descriptions, deposit_note, source_url_hint, source_file, confidence) FROM 'data/processed/awakenings_2025_package_prices_current_official.csv' WITH CSV HEADER ENCODING 'UTF8'

CREATE INDEX idx_stg_awakenings_pkg_category ON stg_awakenings_2025_package_prices (main_category);
CREATE INDEX idx_stg_awakenings_pkg_price ON stg_awakenings_2025_package_prices (basic_sale_price_eur);

DROP TABLE IF EXISTS stg_awakenings_2025_shop_products;

CREATE TABLE stg_awakenings_2025_shop_products (
    festival text,
    edition_year integer,
    product_id text,
    product_name text,
    product_type text,
    price_eur numeric(10,2),
    price_cents integer,
    price_excluding_service_costs numeric(10,2),
    service_costs numeric(10,2),
    max_quantity integer,
    stock_available integer,
    sold_out boolean,
    categories text,
    tags text,
    source_url_hint text,
    source_file text,
    confidence text
);

\copy stg_awakenings_2025_shop_products (festival, edition_year, product_id, product_name, product_type, price_eur, price_cents, price_excluding_service_costs, service_costs, max_quantity, stock_available, sold_out, categories, tags, source_url_hint, source_file, confidence) FROM 'data/processed/awakenings_2025_shop_products_current_official.csv' WITH CSV HEADER ENCODING 'UTF8'

SELECT 'Defqon page facts' AS imported_table, COUNT(*) AS rows FROM stg_defqon_2025_page_facts
UNION ALL
SELECT 'Awakenings event facts', COUNT(*) FROM stg_awakenings_2025_event_facts
UNION ALL
SELECT 'Awakenings package prices', COUNT(*) FROM stg_awakenings_2025_package_prices
UNION ALL
SELECT 'Awakenings shop products', COUNT(*) FROM stg_awakenings_2025_shop_products;
