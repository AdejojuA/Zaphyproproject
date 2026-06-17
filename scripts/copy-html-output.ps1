$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$outputRoot = Join-Path $projectRoot "..\..\outputs"
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$outputRoot = (Resolve-Path $outputRoot).Path

$sourceHtml = Join-Path $projectRoot "src\index.html"
$sourceVendor = Join-Path $projectRoot "src\vendor"
$outputHtml = Join-Path $outputRoot "ZahpyBusinessPro_html.html"
$outputVendor = Join-Path $outputRoot "vendor"
$singleHtml = Join-Path $outputRoot "ZahpyBusinessPro_all_in_one.html"
$bundleZip = Join-Path $outputRoot "ZahpyBusinessPro-HTML-Bundle.zip"
$singleBuilder = Join-Path $PSScriptRoot "build-html-single.cjs"

if (!(Test-Path -LiteralPath $sourceHtml)) {
  throw "Source HTML file was not found: $sourceHtml"
}

if (!(Test-Path -LiteralPath $sourceVendor)) {
  throw "Source vendor folder was not found: $sourceVendor"
}

if (!(Test-Path -LiteralPath $singleBuilder)) {
  throw "Single-file HTML builder was not found: $singleBuilder"
}

if (Test-Path -LiteralPath $outputVendor) {
  $resolvedVendor = (Resolve-Path $outputVendor).Path
  if (!$resolvedVendor.StartsWith($outputRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove vendor folder outside output root: $resolvedVendor"
  }
  Remove-Item -LiteralPath $outputVendor -Recurse -Force
}

if (Test-Path -LiteralPath $bundleZip) {
  Remove-Item -LiteralPath $bundleZip -Force
}

Copy-Item -LiteralPath $sourceHtml -Destination $outputHtml -Force
Copy-Item -LiteralPath $sourceVendor -Destination $outputVendor -Recurse -Force

& node $singleBuilder
if ($LASTEXITCODE -ne 0) {
  throw "Single-file HTML builder failed."
}

$bundlePaths = @($outputHtml, $outputVendor)
Compress-Archive -Path $bundlePaths -DestinationPath $bundleZip -Force

Write-Host "HTML copy written to $outputHtml"
Write-Host "HTML vendor assets written to $outputVendor"
Write-Host "Single-file HTML written to $singleHtml"
Write-Host "HTML bundle zip written to $bundleZip"
