param(
    [string]$ProjectRoot = (Resolve-Path ".").Path,
    [string]$Database = "festival_gis",
    [string]$User = "postgres",
    [string]$PgBin = "E:\PostgreSQL\18\bin"
)

$ErrorActionPreference = "Stop"

$rawDir = Join-Path $ProjectRoot "data\raw"
$psql = Join-Path $PgBin "psql.exe"
$sourceCsv = Join-Path $rawDir "airports.csv"
$sourceCsvForPsql = $sourceCsv.Replace("\", "/")

if (-not (Test-Path -LiteralPath $sourceCsv)) {
    throw "Missing OurAirports CSV: $sourceCsv"
}

& $psql -U $User -d $Database -v ON_ERROR_STOP=1 -c "DROP TABLE IF EXISTS stg_ourairports_airports;"
& $psql -U $User -d $Database -v ON_ERROR_STOP=1 -c @"
CREATE TABLE stg_ourairports_airports (
    id integer,
    ident text,
    type text,
    name text,
    latitude_deg double precision,
    longitude_deg double precision,
    elevation_ft integer,
    continent text,
    iso_country text,
    iso_region text,
    municipality text,
    scheduled_service text,
    icao_code text,
    iata_code text,
    gps_code text,
    local_code text,
    home_link text,
    wikipedia_link text,
    keywords text
);
"@

& $psql -U $User -d $Database -v ON_ERROR_STOP=1 -c "\copy stg_ourairports_airports FROM '$sourceCsvForPsql' WITH CSV HEADER"
& $psql -U $User -d $Database -v ON_ERROR_STOP=1 -c "CREATE INDEX IF NOT EXISTS idx_stg_ourairports_country_type ON stg_ourairports_airports (iso_country, type);"
& $psql -U $User -d $Database -c "SELECT iso_country, type, COUNT(*) FROM stg_ourairports_airports WHERE iso_country IN ('BE','NL') GROUP BY iso_country, type ORDER BY iso_country, type;"
