$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$outputRoot = Join-Path $projectRoot "..\..\outputs"
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$outputRoot = (Resolve-Path $outputRoot).Path

$unpackedDir = Join-Path $outputRoot "win-unpacked"
$zipPath = Join-Path $outputRoot "ZahpyBusinessPro-Windows.zip"
$readmePath = Join-Path $outputRoot "README.txt"
$sourceReadme = Join-Path $PSScriptRoot "standalone-readme.txt"

if (!(Test-Path -LiteralPath $unpackedDir)) {
  throw "Standalone app folder was not found: $unpackedDir"
}

Copy-Item -LiteralPath $sourceReadme -Destination $readmePath -Force

if (Test-Path -LiteralPath $zipPath) {
  Remove-Item -LiteralPath $zipPath -Force
}

$paths = @((Join-Path $unpackedDir "*"), $readmePath)
Compress-Archive -Path $paths -DestinationPath $zipPath -Force

Write-Host "Standalone package written to $zipPath"
