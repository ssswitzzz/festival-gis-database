param(
    [string]$ProjectRoot = (Resolve-Path ".").Path,
    [string]$Database = "festival_gis",
    [string]$User = "postgres",
    [string]$PgBin = "E:\PostgreSQL\18\bin",
    [string]$CountryWhere = "CNTR_ID LIKE '%BE%' OR CNTR_ID LIKE '%NL%'"
)

$ErrorActionPreference = "Stop"

$rawDir = Join-Path $ProjectRoot "data\raw"
$processedDir = Join-Path $ProjectRoot "data\processed"
New-Item -ItemType Directory -Force -Path $processedDir | Out-Null

$ogr2ogr = Join-Path $PgBin "ogr2ogr.exe"
$psql = Join-Path $PgBin "psql.exe"
$sourceGpkg = Join-Path $rawDir "Eurostat_Census-GRID_2021_V3\ESTAT_Census_2021_V3.gpkg"
$dumpFile = Join-Path $processedDir "stg_eurostat_census_grid_2021.sql"
$cleanDumpFile = Join-Path $processedDir "stg_eurostat_census_grid_2021.clean.sql"

if (-not (Test-Path -LiteralPath $sourceGpkg)) {
    throw "Missing Eurostat/GISCO population grid GeoPackage: $sourceGpkg"
}

$env:GDAL_DATA = Join-Path $PgBin "..\gdal-data"
$env:PROJ_LIB = Join-Path $PgBin "..\share\contrib\postgis-3.6\proj"

& $ogr2ogr -f PGDUMP $dumpFile $sourceGpkg ESTAT_Census_2021_V3 `
    -nln stg_eurostat_census_grid_2021 `
    -overwrite `
    -lco GEOMETRY_NAME=geom `
    -lco LAUNDER=NO `
    -lco DROP_TABLE=ON `
    -lco CREATE_SCHEMA=OFF `
    -where $CountryWhere
if ($LASTEXITCODE -ne 0) {
    throw "ogr2ogr PGDUMP export failed for $sourceGpkg"
}

& $psql -U $User -d $Database -v ON_ERROR_STOP=1 -c 'DROP TABLE IF EXISTS public."stg_eurostat_census_grid_2021" CASCADE;'
if ($LASTEXITCODE -ne 0) {
    throw "psql failed while dropping old staging table"
}

Get-Content -LiteralPath $dumpFile | Where-Object { $_ -notmatch '^DROP TABLE ' } | Set-Content -LiteralPath $cleanDumpFile -Encoding UTF8

& $psql -q -U $User -d $Database -v ON_ERROR_STOP=1 -f $cleanDumpFile
if ($LASTEXITCODE -ne 0) {
    throw "psql failed while importing $cleanDumpFile"
}

& $psql -U $User -d $Database -v ON_ERROR_STOP=1 -c 'CREATE INDEX IF NOT EXISTS idx_stg_eurostat_census_grid_2021_geom ON public."stg_eurostat_census_grid_2021" USING gist (geom);'
& $psql -U $User -d $Database -c 'SELECT COUNT(*) AS imported_grid_rows FROM public."stg_eurostat_census_grid_2021";'
