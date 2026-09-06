param(
    [string]$Configuration = "release"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

if (-not $env:SWIFTPM_SCRATCH_PATH) {
    $env:SWIFTPM_SCRATCH_PATH = if ($IsWindows) { Join-Path $env:TEMP "aiusage-scratch" } else { "/tmp/aiusage-scratch" }
}

$packageRoot = Join-Path $repoRoot "QuotaBackend"
$distDir = Join-Path $repoRoot "dist"
$stagingDir = Join-Path $distDir "AIUsage-windows"
New-Item -ItemType Directory -Path $distDir -Force | Out-Null

Write-Host "Building AIUsageWindowsCLI ($Configuration)"
& swift build --package-path $packageRoot -c $Configuration --product AIUsageWindowsCLI
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$searchRoot = Join-Path $packageRoot ".build"
$binary = Get-ChildItem -Path $searchRoot -Recurse -Filter "AIUsageWindowsCLI*.exe" |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1

if (-not $binary) {
    $binary = Get-ChildItem -Path $searchRoot -Recurse -Filter "AIUsageWindowsCLI" |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
}

if (-not $binary) {
    throw "AIUsageWindowsCLI executable was not produced; check the Swift build output."
}

$stagedBinary = Join-Path $stagingDir "AIUsage.exe"
$zipPath = Join-Path $distDir "AIUsage-win64.zip"
if (Test-Path $stagingDir) { Remove-Item $stagingDir -Recurse -Force }
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
Copy-Item -Path $binary.FullName -Destination $stagedBinary -Force

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path $stagedBinary -DestinationPath $zipPath -Force
Remove-Item $stagingDir -Recurse -Force

Write-Host "Windows package created: $zipPath"