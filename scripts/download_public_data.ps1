param(
    [string]$ProjectRoot = (Resolve-Path ".").Path
)

$ErrorActionPreference = "Stop"

$rawDir = Join-Path $ProjectRoot "data\raw"
$queryDir = Join-Path $ProjectRoot "data\queries"
New-Item -ItemType Directory -Force -Path $rawDir | Out-Null

function Invoke-OverpassQuery {
    param(
        [string]$QueryFile,
        [string]$OutputFile
    )

    $query = Get-Content -Raw -LiteralPath $QueryFile
    $curl = Join-Path $env:SystemRoot "System32\curl.exe"
    & $curl -L -G "https://overpass.kumi.systems/api/interpreter" `
        --data-urlencode "data=$query" `
        -o $OutputFile
    if ($LASTEXITCODE -ne 0) {
        throw "Overpass download failed for $QueryFile"
    }
}

Invoke-OverpassQuery `
    -QueryFile (Join-Path $queryDir "osm_candidate_sites.overpassql") `
    -OutputFile (Join-Path $rawDir "osm_candidate_sites.json")

Invoke-OverpassQuery `
    -QueryFile (Join-Path $queryDir "osm_sensitive_facilities.overpassql") `
    -OutputFile (Join-Path $rawDir "osm_sensitive_facilities.json")

Invoke-OverpassQuery `
    -QueryFile (Join-Path $queryDir "osm_transport_hubs.overpassql") `
    -OutputFile (Join-Path $rawDir "osm_transport_hubs.json")

# EEA Natura 2000 ArcGIS REST service, filtered to Belgium and Netherlands.
$naturaBase = "https://bio.discomap.eea.europa.eu/arcgis/rest/services/ProtectedSites/Natura2000_Dyna_WM/MapServer/0/query"
$naturaParams = @{
    f = "geojson"
    where = "MS IN ('BE','NL')"
    outFields = "*"
    returnGeometry = "true"
    outSR = "4326"
}
$naturaQuery = ($naturaParams.GetEnumerator() | ForEach-Object {
    [uri]::EscapeDataString($_.Key) + "=" + [uri]::EscapeDataString($_.Value)
}) -join "&"
Invoke-WebRequest -Uri "${naturaBase}?${naturaQuery}" -OutFile (Join-Path $rawDir "natura2000_be_nl.geojson")

# Eurostat/GISCO population grid source page can change filenames between releases.
# Keep the URL manifest here so the exact ZIP chosen for the report is traceable.
$manifest = @"
Eurostat/GISCO population grid source:
https://ec.europa.eu/eurostat/web/gisco/geodata/population-distribution/population-grids

Recommended dataset:
GEOSTAT / Census grid 2021, 1 km or 5 km grid.

Download manually if the direct ZIP endpoint changes, then place it in:
data/raw/eurostat_population_grid.zip
"@
Set-Content -LiteralPath (Join-Path $rawDir "eurostat_population_grid_source.txt") -Value $manifest -Encoding UTF8

Get-ChildItem -LiteralPath $rawDir | Select-Object Name,Length,LastWriteTime
