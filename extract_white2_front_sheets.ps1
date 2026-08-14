param(
    [Parameter(Mandatory = $true)]
    [string]$RomPath,

    [string]$OutputRoot,

    [string]$AnimaEnginePath
)

$ErrorActionPreference = "Stop"

if (-not $OutputRoot) {
    $OutputRoot = Join-Path $PSScriptRoot "pokemon_white2_front_spritesheets"
}
if (-not $AnimaEnginePath) {
    $AnimaEnginePath = Join-Path $PSScriptRoot "tools\AnimaEngine-v1.0.0\AnimaEngine-v1.0.0-windows-x86_64\AnimaEngine.exe"
}

$rom = (Resolve-Path -LiteralPath $RomPath).Path
$engine = (Resolve-Path -LiteralPath $AnimaEnginePath).Path
$root = [System.IO.Path]::GetFullPath($OutputRoot)

function Get-GenerationName([int]$Species) {
    if ($Species -le 151) { return "gen1" }
    if ($Species -le 251) { return "gen2" }
    if ($Species -le 386) { return "gen3" }
    if ($Species -le 493) { return "gen4" }
    return "gen5"
}

foreach ($generation in @("gen1", "gen2", "gen3", "gen4", "gen5")) {
    foreach ($palette in @("regular", "shiny")) {
        New-Item -ItemType Directory -Force -Path (Join-Path $root "$generation\$palette") | Out-Null
    }
}

$results = [System.Collections.Generic.List[object]]::new()
$total = 649 * 2
$completed = 0

foreach ($species in 1..649) {
    $id = $species.ToString("000")
    $generation = Get-GenerationName $species

    foreach ($palette in @("regular", "shiny")) {
        $paletteDir = Join-Path $root "$generation\$palette"
        $destination = Join-Path $paletteDir "$id.png"
        $arguments = @($rom, $species, $destination, "--mode", "single", "--asset", "spritesheet", "--scale", "1")
        if ($palette -eq "shiny") {
            $arguments += "--shiny"
        }

        if (-not (Test-Path -LiteralPath $destination)) {
            & $engine @arguments *> $null
            $exitCode = $LASTEXITCODE
        }
        else {
            $exitCode = 0
        }

        $valid = $exitCode -eq 0 -and (Test-Path -LiteralPath $destination) -and (Get-Item -LiteralPath $destination).Length -gt 0
        $results.Add([pscustomobject]@{
            species_id = $species
            palette = $palette
            file = "$generation\$palette\$id.png"
            success = $valid
        })

        $completed++
        if (($completed % 50) -eq 0 -or $completed -eq $total) {
            Write-Output "PROGRESS $completed/$total"
        }
    }
}

$manifest = Join-Path $root "manifest.csv"
$results | Export-Csv -LiteralPath $manifest -NoTypeInformation -Encoding UTF8

$failed = @($results | Where-Object { -not $_.success })
Write-Output "COMPLETE exported=$($results.Count - $failed.Count) failed=$($failed.Count) manifest=$manifest"
if ($failed.Count -gt 0) {
    exit 1
}
