param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,
    [Parameter(Mandatory = $true)]
    [string]$OutputFile,
    [ValidateSet("polygon", "point")]
    [string]$Mode = "point"
)

$ErrorActionPreference = "Stop"

$json = Get-Content -Raw -LiteralPath $InputFile | ConvertFrom-Json
$features = New-Object System.Collections.Generic.List[object]

foreach ($element in $json.elements) {
    $geometry = $null

    if ($Mode -eq "polygon") {
        if ($element.type -ne "way" -or -not $element.geometry -or $element.geometry.Count -lt 4) {
            continue
        }

        $coords = @()
        foreach ($point in $element.geometry) {
            $coords += ,@([double]$point.lon, [double]$point.lat)
        }

        $first = $coords[0]
        $last = $coords[$coords.Count - 1]
        if (($first[0] -ne $last[0]) -or ($first[1] -ne $last[1])) {
            continue
        }

        $geometry = @{
            type = "Polygon"
            coordinates = @($coords)
        }
    }
    else {
        if ($element.type -eq "node" -and $null -ne $element.lon -and $null -ne $element.lat) {
            $geometry = @{
                type = "Point"
                coordinates = @([double]$element.lon, [double]$element.lat)
            }
        }
        elseif ($element.center) {
            $geometry = @{
                type = "Point"
                coordinates = @([double]$element.center.lon, [double]$element.center.lat)
            }
        }
        elseif ($element.geometry -and $element.geometry.Count -gt 0) {
            $lon = 0.0
            $lat = 0.0
            foreach ($point in $element.geometry) {
                $lon += [double]$point.lon
                $lat += [double]$point.lat
            }
            $geometry = @{
                type = "Point"
                coordinates = @($lon / $element.geometry.Count, $lat / $element.geometry.Count)
            }
        }
    }

    if ($null -eq $geometry) {
        continue
    }

    $tags = @{}
    if ($element.tags) {
        foreach ($property in $element.tags.PSObject.Properties) {
            $tags[$property.Name] = $property.Value
        }
    }

    $tags["osm_type"] = $element.type
    $tags["osm_id"] = [string]$element.id

    $feature = @{
        type = "Feature"
        geometry = $geometry
        properties = $tags
    }
    $features.Add($feature)
}

$geojson = @{
    type = "FeatureCollection"
    features = $features
}

$geojson | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutputFile -Encoding UTF8
Write-Host "Wrote $($features.Count) features to $OutputFile"
