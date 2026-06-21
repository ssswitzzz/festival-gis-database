param(
    [string]$ProjectRoot = (Resolve-Path ".").Path,
    [string]$Festival = "",
    [int]$TimeoutSeconds = 30,
    [double]$DelaySeconds = 1.0
)

$ErrorActionPreference = "Stop"

$python = "python"
$script = Join-Path $ProjectRoot "scripts\scrape_festival_business_data.py"
$sources = Join-Path $ProjectRoot "data\sources\festival_business_sources.json"
$rawDir = Join-Path $ProjectRoot "data\raw\festival_business_pages"
$processedDir = Join-Path $ProjectRoot "data\processed"

$argsList = @(
    $script,
    "--sources", $sources,
    "--raw-dir", $rawDir,
    "--processed-dir", $processedDir,
    "--timeout", $TimeoutSeconds,
    "--delay", $DelaySeconds
)

if ($Festival.Trim().Length -gt 0) {
    $argsList += @("--festival", $Festival)
}

& $python @argsList
if ($LASTEXITCODE -ne 0) {
    throw "Festival business-data scraper failed"
}

Get-ChildItem -LiteralPath $processedDir -Filter "business_*_candidates.csv" |
    Select-Object Name,Length,LastWriteTime
