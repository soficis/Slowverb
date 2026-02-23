param(
  [string]$SourceRoot = (Join-Path $PSScriptRoot "src_original"),
  [string]$OutputExe = (Join-Path $PSScriptRoot "converter_win32.exe"),
  [string]$OutputCacheText = (Join-Path $PSScriptRoot "sound_quality2_cache.txt"),
  [string]$ClPath = "cl.exe",
  [switch]$AutoFetchSource = $true,
  [switch]$ForceFetchSource = $false
)

$ErrorActionPreference = "Stop"

function Ensure-SourceRoot {
  param(
    [string]$PathValue,
    [switch]$AutoFetch,
    [switch]$ForceFetch
  )

  $fetchScript = Join-Path $PSScriptRoot "fetch_sources.ps1"
  if ($AutoFetch) {
    if (-not (Test-Path $fetchScript)) {
      throw "Auto-fetch requested but missing script: $fetchScript"
    }

    Write-Host "Validating pinned PhaseLimiter sources..."
    $fetchArgs = @("-SourceRoot", $PathValue)
    if ($ForceFetch) {
      $fetchArgs += "-Force"
    }
    & $fetchScript @fetchArgs
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to fetch pinned PhaseLimiter sources."
    }
  }

  if (-not (Test-Path $PathValue)) {
    throw "Source root not found: $PathValue"
  }
}

function Resolve-BoostLib {
  param(
    [string]$BoostRoot,
    [string]$Pattern
  )

  $candidate = Get-ChildItem -Path (Join-Path $BoostRoot "lib32-msvc-14.3") -Filter $Pattern -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $candidate) {
    throw "Missing Boost library matching pattern '$Pattern' under $BoostRoot\lib32-msvc-14.3"
  }
  return $candidate.FullName
}

Ensure-SourceRoot -PathValue $SourceRoot -AutoFetch:$AutoFetchSource -ForceFetch:$ForceFetchSource

$boostRoot = Join-Path $SourceRoot "boost_1_89_0"
if (-not (Test-Path $boostRoot)) {
  throw "Missing Boost sources at: $boostRoot"
}

$boostInclude = $boostRoot
$boostLibSerialization = Resolve-BoostLib -BoostRoot $boostRoot -Pattern "libboost_serialization-*.lib"
$boostLibFilesystem = Resolve-BoostLib -BoostRoot $boostRoot -Pattern "libboost_filesystem-*.lib"

$src = Join-Path $PSScriptRoot "converter.cpp"
if (-not (Test-Path $src)) {
  throw "Missing converter source: $src"
}

$includePaths = @(
  "/I $PSScriptRoot",
  "/I $(Join-Path $PSScriptRoot 'stubs')",
  "/I $SourceRoot",
  "/I $(Join-Path $SourceRoot 'src')",
  "/I $(Join-Path $SourceRoot 'deps\bakuage\include')",
  "/I $(Join-Path $SourceRoot 'deps\bakuage\include\bakuage')",
  "/I $boostInclude",
  "/I $(Join-Path $SourceRoot 'deps\eigen')",
  "/I $(Join-Path $SourceRoot 'deps\hnsw')",
  "/I $(Join-Path $SourceRoot 'prebuilt\win64\optim\header_only_version')"
)

$libs = @(
  $boostLibSerialization,
  $boostLibFilesystem
)

Write-Host "Compiling native Win32 converter..."
& $ClPath /nologo /O2 /MT /std:c++17 $includePaths $src /Fe:$OutputExe /DBOOST_ALL_NO_LIB /DARMA_DONT_USE_WRAPPER $libs /link /MACHINE:X86

if ($LASTEXITCODE -ne 0) {
  throw "Build failed for converter executable."
}

Write-Host "Build complete: $OutputExe"

$cacheInput = Join-Path $SourceRoot "resource\sound_quality2_cache"
if (-not (Test-Path $cacheInput)) {
  throw "Missing cache input file: $cacheInput"
}

Write-Host "Running conversion..."
& $OutputExe $cacheInput $OutputCacheText

if ($LASTEXITCODE -ne 0) {
  throw "Conversion failed."
}

Write-Host "Conversion finished: $OutputCacheText"
