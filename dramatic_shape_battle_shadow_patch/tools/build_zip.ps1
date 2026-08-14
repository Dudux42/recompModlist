param(
  [string]$OutputDirectory = "..\..\Releases"
)

$ErrorActionPreference = "Stop"
$modRoot = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -LiteralPath (Join-Path $modRoot "manifest.json") -Raw |
  ConvertFrom-Json
$name = "dramatic_shape_battle_shadow_patch_v$($manifest.version).zip"
$output = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $OutputDirectory))
New-Item -ItemType Directory -Path $output -Force | Out-Null
$target = Join-Path $output $name

$entries = @(
  "manifest.json",
  "main.lua",
  "README.md"
)

foreach ($entry in $entries) {
  $path = Join-Path $modRoot $entry
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "missing release entry: $entry"
  }
}

if (Test-Path -LiteralPath $target) {
  throw "refusing to overwrite existing release: $target"
}

Compress-Archive -LiteralPath ($entries | ForEach-Object { Join-Path $modRoot $_ }) `
  -DestinationPath $target -CompressionLevel Optimal
Write-Output $target
