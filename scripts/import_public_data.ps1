param(
    [string]$ProjectRoot = (Resolve-Path ".").Path,
    [string]$Database = "festival_gis",
    [string]$User = "postgres",
    [string]$PgBin = "E:\PostgreSQL\18\bin"
)

$ErrorActionPreference = "Stop"

$rawDir = Join-Path $ProjectRoot "data\raw"
$processedDir = Join-Path $ProjectRoot "data\processed"
New-Item -ItemType Directory -Force -Path $processedDir | Out-Null

$ogr2ogr = Join-Path $PgBin "ogr2ogr.exe"
$psql = Join-Path $PgBin "psql.exe"
$python = "python"
$convert = Join-Path $ProjectRoot "scripts\convert_overpass_to_geojson.py"

$pythonArgs = @()

& $python $convert `
    --input (Join-Path $rawDir "osm_candidate_sites.json") `
    --output (Join-Path $processedDir "osm_candidate_sites.geojson") `
    --mode polygon

& $python $convert `
    --input (Join-Path $rawDir "osm_sensitive_facilities.json") `
    --output (Join-Path $processedDir "osm_sensitive_facilities.geojson") `
    --mode point

& $python $convert `
    --input (Join-Path $rawDir "osm_transport_hubs.json") `
    --output (Join-Path $processedDir "osm_transport_hubs.geojson") `
    --mode point

$env:GDAL_DATA = "E:\PostgreSQL\18\gdal-data"
$env:PROJ_LIB = "E:\PostgreSQL\18\share\contrib\postgis-3.6\proj"

function Import-GeoJsonViaPgDump {
    param(
        [string]$SourceFile,
        [string]$LayerName
    )

    $dumpFile = Join-Path $processedDir "$LayerName.sql"
    $cleanDumpFile = Join-Path $processedDir "$LayerName.clean.sql"
    & $ogr2ogr -f PGDUMP $dumpFile $SourceFile `
        -nln $LayerName `
        -overwrite `
        -t_srs EPSG:3035 `
        -lco GEOMETRY_NAME=geom `
        -lco LAUNDER=NO `
        -lco DROP_TABLE=ON `
        -lco CREATE_SCHEMA=OFF
    if ($LASTEXITCODE -ne 0) {
        throw "ogr2ogr PGDUMP failed for $SourceFile"
    }

    & $psql -U $User -d $Database -v ON_ERROR_STOP=1 -c "DROP TABLE IF EXISTS public.`"$LayerName`" CASCADE;"
    Get-Content -LiteralPath $dumpFile | Where-Object { $_ -notmatch '^DROP TABLE ' } | Set-Content -LiteralPath $cleanDumpFile -Encoding UTF8

    & $psql -U $User -d $Database -v ON_ERROR_STOP=1 -f $cleanDumpFile
    if ($LASTEXITCODE -ne 0) {
        throw "psql import failed for $dumpFile"
    }
}

Import-GeoJsonViaPgDump -SourceFile (Join-Path $processedDir "osm_candidate_sites.geojson") -LayerName "stg_osm_candidate_sites"
Import-GeoJsonViaPgDump -SourceFile (Join-Path $processedDir "osm_sensitive_facilities.geojson") -LayerName "stg_osm_sensitive_facilities"
Import-GeoJsonViaPgDump -SourceFile (Join-Path $processedDir "osm_transport_hubs.geojson") -LayerName "stg_osm_transport_hubs"
Import-GeoJsonViaPgDump -SourceFile (Join-Path $rawDir "natura2000_be_nl.geojson") -LayerName "stg_natura2000_be_nl"

& $psql -U $User -d $Database -c "\dt stg_*"
