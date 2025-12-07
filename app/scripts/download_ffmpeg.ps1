# PowerShell script to download and install FFmpeg for Slowverb on Windows
# Run this script with: .\download_ffmpeg.ps1

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Slowverb FFmpeg Setup Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$ffmpegUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
$scriptDir = $PSScriptRoot
$downloadPath = Join-Path $scriptDir "ffmpeg_download.zip"
$extractPath = Join-Path $scriptDir "ffmpeg_extract"

# Determine target directory
$debugPath = Join-Path $scriptDir "..\build\windows\x64\runner\Debug"
$releasePath = Join-Path $scriptDir "..\build\windows\x64\runner\Release"

Write-Host "Step 1: Downloading FFmpeg..." -ForegroundColor Yellow
Write-Host "  Source: $ffmpegUrl"
Write-Host ""

try {
    # Use TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # Download FFmpeg
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($ffmpegUrl, $downloadPath)
    
    Write-Host "  ✓ Downloaded successfully" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Download failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Alternative: Install FFmpeg using winget:"
    Write-Host "  winget install FFmpeg"
    exit 1
}

Write-Host ""
Write-Host "Step 2: Extracting FFmpeg..." -ForegroundColor Yellow

try {
    # Remove existing extract directory
    if (Test-Path $extractPath) {
        Remove-Item $extractPath -Recurse -Force
    }
    
    # Extract the zip
    Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
    
    Write-Host "  ✓ Extracted successfully" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Extraction failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 3: Installing FFmpeg..." -ForegroundColor Yellow

# Find ffmpeg.exe in extracted folder
$ffmpegExe = Get-ChildItem -Path $extractPath -Filter "ffmpeg.exe" -Recurse | Select-Object -First 1

if (-not $ffmpegExe) {
    Write-Host "  ✗ Could not find ffmpeg.exe in extracted files" -ForegroundColor Red
    exit 1
}

# Create target directories if they don't exist
$installed = $false

if (Test-Path (Split-Path $debugPath)) {
    if (-not (Test-Path $debugPath)) {
        New-Item -ItemType Directory -Path $debugPath -Force | Out-Null
    }
    Copy-Item $ffmpegExe.FullName -Destination (Join-Path $debugPath "ffmpeg.exe") -Force
    Write-Host "  ✓ Installed to Debug build" -ForegroundColor Green
    $installed = $true
}

if (Test-Path (Split-Path $releasePath)) {
    if (-not (Test-Path $releasePath)) {
        New-Item -ItemType Directory -Path $releasePath -Force | Out-Null
    }
    Copy-Item $ffmpegExe.FullName -Destination (Join-Path $releasePath "ffmpeg.exe") -Force
    Write-Host "  ✓ Installed to Release build" -ForegroundColor Green
    $installed = $true
}

# Also copy to scripts folder as backup
$scriptsFFmpeg = Join-Path $scriptDir "ffmpeg.exe"
Copy-Item $ffmpegExe.FullName -Destination $scriptsFFmpeg -Force
Write-Host "  ✓ Saved backup copy to scripts folder" -ForegroundColor Green

Write-Host ""
Write-Host "Step 4: Cleaning up..." -ForegroundColor Yellow

Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "  ✓ Cleanup complete" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FFmpeg Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "You can now run Slowverb and export audio with effects." -ForegroundColor White
Write-Host ""

# Verify
$ffmpegTest = Join-Path $scriptDir "ffmpeg.exe"
if (Test-Path $ffmpegTest) {
    $version = & $ffmpegTest -version 2>&1 | Select-Object -First 1
    Write-Host "Installed version: $version" -ForegroundColor Gray
}
