param(
  [string]$EmsdkRoot = $env:EMSDK,
  [string]$SourceRoot = (Join-Path $PSScriptRoot "src_original"),
  [string]$OutDir = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path "web\web\js"),
  [string]$OptimInclude = "",
  [string]$LibsimdppInclude = "",
  [switch]$AutoFetchSource = $true,
  [switch]$ForceFetchSource = $false
)

$ErrorActionPreference = "Stop"

function Resolve-Emcc {
  param([string]$SdkRoot)

  $emccFromPath = Get-Command emcc -ErrorAction SilentlyContinue
  if ($emccFromPath) {
    return $emccFromPath.Source
  }

  if (-not $SdkRoot) {
    throw "emcc not found in PATH and EMSDK was not provided."
  }

  $candidates = @(
    (Join-Path $SdkRoot "upstream\emscripten\emcc.bat"),
    (Join-Path $SdkRoot "upstream_manual\emscripten\emcc.bat")
  )

  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      return $candidate
    }
  }

  throw "Could not locate emcc.bat under EMSDK root: $SdkRoot"
}

function Add-PathIfExists {
  param([string]$PathValue)
  if (-not $PathValue) { return }
  if (Test-Path $PathValue) {
    $script:IncludePaths += "-I$PathValue"
  }
}

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

function Resolve-ExistingPath {
  param([string[]]$Candidates)
  foreach ($candidate in $Candidates) {
    if ($candidate -and (Test-Path $candidate)) {
      return $candidate
    }
  }
  return $null
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$emcc = Resolve-Emcc -SdkRoot $EmsdkRoot

if ($EmsdkRoot) {
  $nodePath = Join-Path $EmsdkRoot "node\22.16.0_64bit\bin"
  $pythonPath = Join-Path $EmsdkRoot "python\3.13.3_64bit"

  if (Test-Path $nodePath) {
    $env:PATH = "$nodePath;$env:PATH"
    $env:EMSDK_NODE = Join-Path $nodePath "node.exe"
  }

  if (Test-Path $pythonPath) {
    $env:PATH = "$pythonPath;$env:PATH"
    $env:EMSDK_PYTHON = Join-Path $pythonPath "python.exe"
  }
}

Ensure-SourceRoot -PathValue $SourceRoot -AutoFetch:$AutoFetchSource -ForceFetch:$ForceFetchSource

if (-not $OptimInclude) {
  $OptimInclude = Join-Path $SourceRoot "prebuilt\win64\optim\header_only_version"
}

if (-not $LibsimdppInclude) {
  $LibsimdppInclude = Resolve-ExistingPath @(
    (Join-Path $SourceRoot "deps\libsimdpp"),
    (Join-Path $SourceRoot "deps\libsimdpp\simdpp")
  )
}

$hnswInclude = Resolve-ExistingPath @(
  (Join-Path $SourceRoot "hnswlib-0.8.0"),
  (Join-Path $SourceRoot "deps\hnsw")
)

$eigenInclude = Resolve-ExistingPath @(
  (Join-Path $SourceRoot "eigen-master"),
  (Join-Path $SourceRoot "deps\eigen")
)

$boostRoot = Join-Path $SourceRoot "boost_1_89_0"
if (-not (Test-Path $boostRoot)) {
  throw "Missing Boost sources at: $boostRoot. Run fetch_sources.ps1 to bootstrap dependencies."
}

$phaseLimiterSrc = Join-Path $SourceRoot "src\phase_limiter\auto_mastering5.cpp"
if (-not (Test-Path $phaseLimiterSrc)) {
  throw "PhaseLimiter source layout invalid. Missing file: $phaseLimiterSrc"
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

Push-Location $PSScriptRoot
try {
  $srcFiles = @(
    (Join-Path $PSScriptRoot "adapter_pro.cpp"),
    (Join-Path $PSScriptRoot "globals.cpp"),
    (Join-Path $SourceRoot "src\phase_limiter\auto_mastering.cpp"),
    (Join-Path $SourceRoot "src\phase_limiter\auto_mastering2.cpp"),
    (Join-Path $SourceRoot "src\phase_limiter\auto_mastering3.cpp"),
    (Join-Path $SourceRoot "src\phase_limiter\auto_mastering5.cpp"),
    (Join-Path $SourceRoot "src\phase_limiter\enhancement.cpp"),
    (Join-Path $SourceRoot "src\phase_limiter\equalization.cpp"),
    (Join-Path $SourceRoot "src\phase_limiter\freq_expander.cpp"),
    (Join-Path $SourceRoot "src\phase_limiter\pre_compression.cpp"),
    (Join-Path $SourceRoot "src\phase_limiter\resampling.cpp")
  )

  $bakuageSrc = Get-ChildItem (Join-Path $SourceRoot "deps\bakuage\src") -Filter "*.cpp" | ForEach-Object { $_.FullName }
  $boostSerializationSrc = Get-ChildItem (Join-Path $boostRoot "libs\serialization\src") -Filter "*.cpp" | ForEach-Object { $_.FullName }
  $boostFilesystemSrc = Get-ChildItem (Join-Path $boostRoot "libs\filesystem\src") -Filter "*.cpp" | ForEach-Object { $_.FullName }
  $boostIostreamMappedFile = Join-Path $boostRoot "libs\iostreams\src\mapped_file.cpp"

  $srcFiles += $bakuageSrc
  $srcFiles += $boostSerializationSrc
  $srcFiles += $boostFilesystemSrc
  if (Test-Path $boostIostreamMappedFile) {
    $srcFiles += $boostIostreamMappedFile
  }

  $script:IncludePaths = @(
    "-I$PSScriptRoot",
    "-I$(Join-Path $PSScriptRoot "stubs")",
    "-I$SourceRoot",
    "-I$(Join-Path $SourceRoot "src")",
    "-I$(Join-Path $SourceRoot "deps\bakuage\include")",
    "-I$(Join-Path $SourceRoot "deps\bakuage\include\bakuage")"
  )

  Add-PathIfExists -PathValue $OptimInclude
  Add-PathIfExists -PathValue $LibsimdppInclude
  Add-PathIfExists -PathValue (Join-Path $SourceRoot "prebuilt\win64\libsndfile-1.2.2-win64\include")
  Add-PathIfExists -PathValue (Join-Path $SourceRoot "armadillo-15.2.3\include")
  Add-PathIfExists -PathValue $hnswInclude
  Add-PathIfExists -PathValue $boostRoot
  Add-PathIfExists -PathValue $eigenInclude

  Write-Host "Compiling PhaseLimiter Pro..."

  $compileArgs = @()
  $compileArgs += $srcFiles
  $compileArgs += $IncludePaths
  $compileArgs += "-O3"
  $compileArgs += "-flto"
  $compileArgs += "-msse"
  $compileArgs += "-msse2"
  $compileArgs += "-msimd128"
  $compileArgs += "-DPHASELIMITER_ENABLE_FFTW"
  $compileArgs += "-DOPTIM_USE_TBB"
  $compileArgs += "-DNO_MANUAL_VECTORIZATION"
  $compileArgs += "-DARMA_DONT_USE_WRAPPER"
  $compileArgs += "-DBOOST_ALL_NO_LIB"
  $compileArgs += "-DBOOST_FILESYSTEM_SINGLE_THREADED"
  $compileArgs += "-sDISABLE_EXCEPTION_CATCHING=0"
  $compileArgs += "-sALLOW_MEMORY_GROWTH=1"
  $compileArgs += "-sINITIAL_MEMORY=1073741824"
  $compileArgs += "-sSTACK_SIZE=16777216"
  $compileArgs += "-sMAXIMUM_MEMORY=4294967296"
  $compileArgs += "-sMODULARIZE=1"
  $compileArgs += "-sEXPORT_NAME=createPhaseLimiterProModule"
  $compileArgs += "-sENVIRONMENT=web,worker"
  $compileArgs += "-sFILESYSTEM=1"
  $compileArgs += "-sEXPORTED_FUNCTIONS=['_phaselimiter_pro_process','_malloc','_free']"
  $compileArgs += "-sEXPORTED_RUNTIME_METHODS=['ccall']"

  $cacheFile = Join-Path $SourceRoot "phaselimiter-win\phaselimiter\resource\sound_quality2_cache"
  if (-not (Test-Path $cacheFile)) {
    throw "Required cache file not found: $cacheFile"
  }

  $compileArgs += "--preload-file"
  $compileArgs += "$cacheFile@/sound_quality2_cache"
  $compileArgs += "-o"
  $compileArgs += (Join-Path $OutDir "phaselimiter_pro.js")

  & $emcc $compileArgs

  if ($LASTEXITCODE -ne 0) {
    throw "emcc failed with exit code $LASTEXITCODE"
  }

  Write-Host "Build complete: $(Join-Path $OutDir "phaselimiter_pro.js")"
}
finally {
  Pop-Location
}
