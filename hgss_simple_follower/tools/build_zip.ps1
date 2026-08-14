param([Parameter(Mandatory = $true)][string]$Destination)
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$destinationPath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $Destination))
[System.IO.Directory]::CreateDirectory((Split-Path -Parent $destinationPath)) | Out-Null
if ([System.IO.File]::Exists($destinationPath)) { [System.IO.File]::Delete($destinationPath) }
$staging = Join-Path ([System.IO.Path]::GetTempPath()) ("hgss_simple_follower_" + [guid]::NewGuid().ToString("N"))
[System.IO.Directory]::CreateDirectory($staging) | Out-Null
try {
  foreach ($name in @("manifest.json", "main.lua", "README.md")) {
    [System.IO.File]::Copy((Join-Path $projectRoot $name), (Join-Path $staging $name))
  }
  foreach ($dex in 1..151) {
    $number = "{0:D3}" -f $dex
    $assets = @(
      @{ Source = "runtime_followers"; Destination = "follower_$number.png" },
      @{ Source = "runtime_shiny"; Destination = "shiny_$number.png" },
      @{ Source = "proxies"; Destination = "proxy_$number.png" }
    )
    foreach ($asset in $assets) {
      $source = Join-Path $projectRoot ("assets\{0}\{1}.png" -f $asset.Source, $number)
      [System.IO.File]::Copy($source, (Join-Path $staging $asset.Destination))
    }
  }
  $entries = Get-ChildItem -File -LiteralPath $staging | Sort-Object Name | ForEach-Object Name
  & tar.exe -a -c -f $destinationPath -C $staging @entries
  if ($LASTEXITCODE -ne 0) { throw "BSD tar failed with exit code $LASTEXITCODE" }
} finally {
  if ([System.IO.Directory]::Exists($staging)) {
    [System.IO.Directory]::Delete($staging, $true)
  }
}
Write-Output $destinationPath
