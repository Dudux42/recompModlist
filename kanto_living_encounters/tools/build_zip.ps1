param(
  [string]$Output = "..\Releases\kanto_living_encounters_v0.1.0-alpha.4.zip"
)

$ErrorActionPreference = "Stop"
$modRoot = Split-Path -Parent $PSScriptRoot
$outputPath = [System.IO.Path]::GetFullPath((Join-Path $modRoot $Output))
$files = @(
  "manifest.json",
  "main.lua",
  "kle_core.lua",
  "kle_tables.lua",
  "kle_runtime.lua",
  "README.md"
)

foreach ($file in $files) {
  if (-not (Test-Path -LiteralPath (Join-Path $modRoot $file))) {
    throw "Missing release file: $file"
  }
}

if (Test-Path -LiteralPath $outputPath) {
  throw "Refusing to overwrite existing release: $outputPath"
}

Compress-Archive -Path ($files | ForEach-Object { Join-Path $modRoot $_ }) `
  -DestinationPath $outputPath -CompressionLevel Optimal
Write-Output $outputPath
