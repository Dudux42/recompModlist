param(
  [Parameter(Mandatory = $true)]
  [string]$Destination
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$destinationPath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Destination))
$destinationDirectory = Split-Path -Parent $destinationPath
[System.IO.Directory]::CreateDirectory($destinationDirectory) | Out-Null

# BSD tar is the writer used by the last known-good archive. Its ZIP entries
# carry UNIX file/directory mode attributes and streamed data descriptors;
# Gen1Recomp's PhysFS importer depends on those attributes to distinguish the
# directory tree correctly. .NET's attribute-less DOS entries can make its
# recursive copy/rollback overflow and leave a partial installation.
if ([System.IO.File]::Exists($destinationPath)) {
  [System.IO.File]::Delete($destinationPath)
}

Push-Location $projectRoot
try {
  & tar.exe -a -c -f $destinationPath `
    manifest.json main.lua README.md BAG_PROVIDER_API_V1.md `
    BAG_PROVIDER_API_V2.md POKEMON_STORAGE_PROVIDER_API_V1.md assets
  if ($LASTEXITCODE -ne 0) {
    throw "BSD tar failed with exit code $LASTEXITCODE"
  }
}
finally {
  Pop-Location
}

Write-Output $destinationPath
