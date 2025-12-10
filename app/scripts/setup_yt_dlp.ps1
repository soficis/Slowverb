<#
    setup_yt_dlp.ps1
    Downloads yt-dlp.exe into a tools directory if not already present.

    Usage (default tools dir next to this script):
      powershell -ExecutionPolicy Bypass -File setup_yt_dlp.ps1

    Usage (custom tools dir):
      powershell -ExecutionPolicy Bypass -File setup_yt_dlp.ps1 -TargetDir "C:\path\to\tools"
#>

param(
    [string]$TargetDir = "$(Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) 'tools')"
)

$ErrorActionPreference = "Stop"

Write-Host "Target tools directory: $TargetDir"

# Create directory if needed
if (-not (Test-Path $TargetDir)) {
    Write-Host "Creating tools directory..."
    New-Item -ItemType Directory -Path $TargetDir | Out-Null
}

$ytDlpPath = Join-Path $TargetDir "yt-dlp.exe"

# Check if already installed
if (Test-Path $ytDlpPath) {
    Write-Host "yt-dlp already present at:"
    Write-Host "  $ytDlpPath"
    exit 0
}

# Official latest download URL
$ytDlpUrl = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe"

Write-Host "Downloading yt-dlp from:"
Write-Host "  $ytDlpUrl"
Write-Host ""

try {
    Invoke-WebRequest -Uri $ytDlpUrl -OutFile $ytDlpPath
    Write-Host "yt-dlp downloaded to:"
    Write-Host "  $ytDlpPath"
}
catch {
    Write-Error "Failed to download yt-dlp: $_"
    if (Test-Path $ytDlpPath) {
        Remove-Item $ytDlpPath -ErrorAction SilentlyContinue
    }
    exit 1
}

# Verify installation
Write-Host ""
Write-Host "Verifying yt-dlp..."
& $ytDlpPath --version | Select-Object -First 1

Write-Host "Done."
exit 0
