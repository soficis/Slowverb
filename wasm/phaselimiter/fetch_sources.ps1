param(
  [string]$SourceRoot = (Join-Path $PSScriptRoot "src_original"),
  [string]$RepositoryUrl = "https://github.com/ai-mastering/phaselimiter.git",
  [string]$PinnedCommit = "3c951f40ea7e95e08c23c7b5654430f333939698",
  [string]$PinnedTree = "ae5bf02a1380ac1edbff9ada0fee6d9bc32c78ea",
  [string]$BoostArchiveUrl = "https://archives.boost.io/release/1.89.0/source/boost_1_89_0.tar.gz",
  [string]$BoostArchiveSha256 = "9de758db755e8330a01d995b0a24d09798048400ac25c03fc5ea9be364b13c93",
  [switch]$Force
)

$ErrorActionPreference = "Stop"

function Require-Command {
  param([string]$CommandName)
  if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $CommandName"
  }
}

function Invoke-Git {
  param(
    [string]$WorkingDirectory,
    [string[]]$Arguments
  )

  & git -C $WorkingDirectory @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "git command failed in $WorkingDirectory: git $($Arguments -join ' ')"
  }
}

function Get-Sha256 {
  param([string]$FilePath)
  return (Get-FileHash -Algorithm SHA256 -Path $FilePath).Hash.ToLowerInvariant()
}

function Test-AlreadyPinned {
  param(
    [string]$PathValue,
    [string]$CommitValue,
    [string]$TreeValue,
    [string]$BoostHashValue
  )

  if (-not (Test-Path $PathValue)) {
    return $false
  }

  $manifestPath = Join-Path $PathValue ".slowverb_source_pin.json"
  if (-not (Test-Path $manifestPath)) {
    return $false
  }

  try {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  } catch {
    return $false
  }

  if ($manifest.pinnedCommit -ne $CommitValue) { return $false }
  if ($manifest.pinnedTree -ne $TreeValue) { return $false }
  if ($manifest.boostArchiveSha256 -ne $BoostHashValue) { return $false }
  if (-not (Test-Path (Join-Path $PathValue "boost_1_89_0"))) { return $false }
  if (-not (Test-Path (Join-Path $PathValue "src\phase_limiter\auto_mastering5.cpp"))) { return $false }
  return $true
}

Require-Command -CommandName "git"
Require-Command -CommandName "tar"

$expectedBoostHash = $BoostArchiveSha256.ToLowerInvariant()

if ((-not $Force) -and (Test-AlreadyPinned -PathValue $SourceRoot -CommitValue $PinnedCommit -TreeValue $PinnedTree -BoostHashValue $expectedBoostHash)) {
  Write-Host "PhaseLimiter source tree already pinned and verified: $SourceRoot"
  exit 0
}

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("slowverb-phaselimiter-" + [Guid]::NewGuid().ToString("N"))
$checkoutDir = Join-Path $tempDir "checkout"
$boostArchive = Join-Path $tempDir "boost_1_89_0.tar.gz"
$sourceParent = Split-Path -Parent $SourceRoot

New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
New-Item -ItemType Directory -Path $checkoutDir -Force | Out-Null
if ($sourceParent) {
  New-Item -ItemType Directory -Path $sourceParent -Force | Out-Null
}

try {
  Write-Host "Fetching PhaseLimiter commit $PinnedCommit from $RepositoryUrl..."
  & git init -q $checkoutDir
  Invoke-Git -WorkingDirectory $checkoutDir -Arguments @("remote", "add", "origin", $RepositoryUrl)
  Invoke-Git -WorkingDirectory $checkoutDir -Arguments @("fetch", "--depth", "1", "origin", $PinnedCommit)
  Invoke-Git -WorkingDirectory $checkoutDir -Arguments @("checkout", "--detach", "FETCH_HEAD")

  $actualCommit = (& git -C $checkoutDir rev-parse HEAD).Trim()
  if ($actualCommit -ne $PinnedCommit) {
    throw "Pinned commit mismatch. Expected $PinnedCommit, got $actualCommit."
  }

  $actualTree = (& git -C $checkoutDir rev-parse "HEAD^{tree}").Trim()
  if ($actualTree -ne $PinnedTree) {
    throw "Pinned tree checksum mismatch. Expected $PinnedTree, got $actualTree."
  }

  Write-Host "Updating PhaseLimiter submodules recursively..."
  Invoke-Git -WorkingDirectory $checkoutDir -Arguments @("submodule", "update", "--init", "--recursive", "--depth", "1")

  Write-Host "Downloading Boost archive with checksum verification..."
  Invoke-WebRequest -Uri $BoostArchiveUrl -OutFile $boostArchive
  $actualBoostHash = Get-Sha256 -FilePath $boostArchive
  if ($actualBoostHash -ne $expectedBoostHash) {
    throw "Boost checksum mismatch. Expected $expectedBoostHash, got $actualBoostHash."
  }

  & tar -xzf $boostArchive -C $checkoutDir
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to extract Boost archive."
  }

  if (-not (Test-Path (Join-Path $checkoutDir "boost_1_89_0"))) {
    throw "Extracted Boost tree missing: boost_1_89_0"
  }
  if (-not (Test-Path (Join-Path $checkoutDir "src\phase_limiter\auto_mastering5.cpp"))) {
    throw "Fetched source missing expected file: src/phase_limiter/auto_mastering5.cpp"
  }

  if (Test-Path $SourceRoot) {
    Remove-Item -LiteralPath $SourceRoot -Recurse -Force
  }
  New-Item -ItemType Directory -Path $SourceRoot -Force | Out-Null

  Get-ChildItem -LiteralPath $checkoutDir -Force |
    Where-Object { $_.Name -ne ".git" } |
    ForEach-Object {
      Copy-Item -LiteralPath $_.FullName -Destination $SourceRoot -Recurse -Force
    }

  $manifest = [ordered]@{
    repository = $RepositoryUrl
    pinnedCommit = $PinnedCommit
    pinnedTree = $PinnedTree
    boostArchiveUrl = $BoostArchiveUrl
    boostArchiveSha256 = $expectedBoostHash
    fetchedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
  } | ConvertTo-Json -Depth 5

  Set-Content -LiteralPath (Join-Path $SourceRoot ".slowverb_source_pin.json") -Value $manifest -Encoding UTF8
  Write-Host "PhaseLimiter source bootstrap completed: $SourceRoot"
}
finally {
  if (Test-Path $tempDir) {
    Remove-Item -LiteralPath $tempDir -Recurse -Force
  }
}
