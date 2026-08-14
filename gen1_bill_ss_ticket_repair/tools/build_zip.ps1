param(
  [Parameter(Mandatory = $true)]
  [string]$Destination
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$destinationPath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Destination))
$destinationDirectory = Split-Path -Parent $destinationPath
[System.IO.Directory]::CreateDirectory($destinationDirectory) | Out-Null

# Match the known-good Widescreen archive writer. The launcher/PhysFS import
# path relies on directory-aware UNIX attributes and has previously produced
# partial installs or stack overflows from attribute-less .NET ZIP entries.
if ([System.IO.File]::Exists($destinationPath)) {
  [System.IO.File]::Delete($destinationPath)
}

Push-Location $projectRoot
try {
  & tar.exe -a -c -f $destinationPath manifest.json main.lua README.md
  if ($LASTEXITCODE -ne 0) {
    throw "BSD tar failed with exit code $LASTEXITCODE"
  }
}
finally {
  Pop-Location
}

Write-Output $destinationPath
