$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$outputRoot = Join-Path $projectRoot "..\..\outputs"
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$outputRoot = (Resolve-Path $outputRoot).Path

$sourceHtml = Join-Path $projectRoot "src\index.html"
$sourceVendor = Join-Path $projectRoot "src\vendor"
$outputHtml = Join-Path $outputRoot "ZahpyBusinessPro_html.html"
$outputVendor = Join-Path $outputRoot "vendor"

if (!(Test-Path -LiteralPath $sourceHtml)) {
  throw "Source HTML file was not found: $sourceHtml"
}

if (!(Test-Path -LiteralPath $sourceVendor)) {
  throw "Source vendor folder was not found: $sourceVendor"
}

if (Test-Path -LiteralPath $outputVendor) {
  $resolvedVendor = (Resolve-Path $outputVendor).Path
  if (!$resolvedVendor.StartsWith($outputRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove vendor folder outside output root: $resolvedVendor"
  }
  Remove-Item -LiteralPath $outputVendor -Recurse -Force
}

Copy-Item -LiteralPath $sourceHtml -Destination $outputHtml -Force
Copy-Item -LiteralPath $sourceVendor -Destination $outputVendor -Recurse -Force

Write-Host "HTML copy written to $outputHtml"
Write-Host "HTML vendor assets written to $outputVendor"
