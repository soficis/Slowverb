$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\\..")
$outDir = Join-Path $repoRoot "web\\web\\js"

# Fixed emsdk path for Windows
$emsdkRoot = "v:\Slowverb\build\emsdk"
$upstreamManual = Join-Path $emsdkRoot "upstream_manual"
$emcc = Join-Path $upstreamManual "emscripten\emcc.bat"
$nodePath = Join-Path $emsdkRoot "node\22.16.0_64bit\bin"
$pythonPath = Join-Path $emsdkRoot "python\3.13.3_64bit"

if (-not (Test-Path $emcc)) {
  throw "Required emcc not found at $emcc"
}

# Set environment variables for the session
$env:PATH = "$nodePath;$pythonPath;$env:PATH"
$env:EMSDK_NODE = Join-Path $nodePath "node.exe"
$env:EMSDK_PYTHON = Join-Path $pythonPath "python.exe"

New-Item -ItemType Directory -Path $outDir -Force | Out-Null

Push-Location $scriptDir

$srcFiles = @(
  (Join-Path $scriptDir "adapter_pro.cpp"),
  (Join-Path $scriptDir "globals.cpp"),
  (Join-Path $scriptDir "src_original/src/phase_limiter/auto_mastering.cpp"),
  (Join-Path $scriptDir "src_original/src/phase_limiter/auto_mastering2.cpp"),
  (Join-Path $scriptDir "src_original/src/phase_limiter/auto_mastering3.cpp"),
  (Join-Path $scriptDir "src_original/src/phase_limiter/auto_mastering5.cpp"),
  (Join-Path $scriptDir "src_original/src/phase_limiter/enhancement.cpp"),
  (Join-Path $scriptDir "src_original/src/phase_limiter/equalization.cpp"),
  (Join-Path $scriptDir "src_original/src/phase_limiter/freq_expander.cpp"),
  (Join-Path $scriptDir "src_original/src/phase_limiter/pre_compression.cpp"),
  (Join-Path $scriptDir "src_original/src/phase_limiter/resampling.cpp"),
  (Join-Path $scriptDir "src_original/deps/bakuage/src/bessel.cpp"),
  (Join-Path $scriptDir "src_original/deps/bakuage/src/biquad_iir_filter.cpp"),
  (Join-Path $scriptDir "src_original/deps/bakuage/src/convolution.cpp"),
  (Join-Path $scriptDir "src_original/deps/bakuage/src/dbesi0.cpp"),
  (Join-Path $scriptDir "src_original/deps/bakuage/src/dft.cpp"),
  (Join-Path $scriptDir "src_original/deps/bakuage/src/dissonance.cpp"),
  (Join-Path $scriptDir "src_original/deps/bakuage/src/file_utils.cpp"),
  (Join-Path $scriptDir "src_original/deps/bakuage/src/fir_filter4.cpp"),
  (Join-Path $scriptDir "src_original/deps/bakuage/src/get_peak_rss.cpp"),
  (Join-Path $scriptDir "src_original/deps/bakuage/src/loudness_contours.cpp"),
  (Join-Path $scriptDir "src_original/deps/bakuage/src/loudness_ebu_r128.cpp"),
  (Join-Path $scriptDir "src_original/deps/bakuage/src/loudness_filter.cpp"),
  (Join-Path $scriptDir "src_original/deps/bakuage/src/memory.cpp"),
  (Join-Path $scriptDir "src_original/deps/bakuage/src/rnnoise.cpp"),
  (Join-Path $scriptDir "src_original/deps/bakuage/src/sndfile_wrapper.cpp"),
  (Join-Path $scriptDir "src_original/deps/bakuage/src/stacktrace.cpp"),
  (Join-Path $scriptDir "src_original/deps/bakuage/src/utils.cpp"),
  (Join-Path $scriptDir "src_original/deps/bakuage/src/vector_math.cpp"),
  (Join-Path $scriptDir "src_original/deps/bakuage/src/window_func.cpp")
)

# Base include paths
$includePaths = @(
  "-I$scriptDir",
  "-I$(Join-Path $scriptDir "stubs")",
  "-I$(Join-Path $scriptDir "src_original")",
  "-I$(Join-Path $scriptDir "src_original/src")",
  "-I$(Join-Path $scriptDir "src_original/deps/bakuage/include")",
  "-I$(Join-Path $scriptDir "src_original/deps/bakuage/include/bakuage")"
)

# External dependency paths
$optimPath = "v:\Slowverb\wasm\phaselimiter\src_original\prebuilt\win64\optim\header_only_version"
$libsimdppPath = "v:\Slowverb\docs\slowverb-mastering-toggle-plan-v3\phaselimiter-master\deps\libsimdpp"

$libsndfilePath = "$(Join-Path $scriptDir "src_original/prebuilt/win64/libsndfile-1.2.2-win64/include")"
$armaPath = "$(Join-Path $scriptDir "src_original/armadillo-15.2.3/include")"
$hnswPath = "$(Join-Path $scriptDir "src_original/hnswlib-0.8.0")"
$boostPath = "$(Join-Path $scriptDir "src_original/boost_1_89_0")"
$eigenPath = "$(Join-Path $scriptDir "src_original/eigen-master")"

if (Test-Path $optimPath) { $includePaths += "-I$optimPath" }
if (Test-Path $libsimdppPath) { $includePaths += "-I$libsimdppPath" }
if (Test-Path $libsndfilePath) { $includePaths += "-I$libsndfilePath" }
if (Test-Path $armaPath) { $includePaths += "-I$armaPath" }
if (Test-Path $hnswPath) { $includePaths += "-I$hnswPath" }
if (Test-Path $boostPath) { $includePaths += "-I$boostPath" }
if (Test-Path $eigenPath) { $includePaths += "-I$eigenPath" }

try {
  if (Test-Path v:\Slowverb\wasm\phaselimiter\build_log.txt) {
    Remove-Item v:\Slowverb\wasm\phaselimiter\build_log.txt -Force
  }
  Write-Host "Compiling PhaseLimiter Pro..."
  
  $compileArgs = @()
  $compileArgs += $srcFiles
  
  # Add Boost source files for necessary libraries
  $boostSrcFiles = @(
    # Serialization
    (Join-Path $boostPath "libs/serialization/src/archive_exception.cpp"),
    (Join-Path $boostPath "libs/serialization/src/basic_archive.cpp"),
    (Join-Path $boostPath "libs/serialization/src/basic_iarchive.cpp"),
    (Join-Path $boostPath "libs/serialization/src/basic_iserializer.cpp"),
    (Join-Path $boostPath "libs/serialization/src/basic_oarchive.cpp"),
    (Join-Path $boostPath "libs/serialization/src/basic_oserializer.cpp"),
    (Join-Path $boostPath "libs/serialization/src/basic_pointer_iserializer.cpp"),
    (Join-Path $boostPath "libs/serialization/src/basic_pointer_oserializer.cpp"),
    (Join-Path $boostPath "libs/serialization/src/basic_serializer_map.cpp"),
    (Join-Path $boostPath "libs/serialization/src/basic_text_iprimitive.cpp"),
    (Join-Path $boostPath "libs/serialization/src/basic_text_oprimitive.cpp"),
    (Join-Path $boostPath "libs/serialization/src/binary_iarchive.cpp"),
    (Join-Path $boostPath "libs/serialization/src/binary_oarchive.cpp"),
    (Join-Path $boostPath "libs/serialization/src/extended_type_info.cpp"),
    (Join-Path $boostPath "libs/serialization/src/extended_type_info_typeid.cpp"),
    (Join-Path $boostPath "libs/serialization/src/polymorphic_iarchive.cpp"),
    (Join-Path $boostPath "libs/serialization/src/polymorphic_oarchive.cpp"),
    (Join-Path $boostPath "libs/serialization/src/text_iarchive.cpp"),
    (Join-Path $boostPath "libs/serialization/src/text_oarchive.cpp"),
    (Join-Path $boostPath "libs/serialization/src/void_cast.cpp"),
    # Iostreams
    (Join-Path $boostPath "libs/iostreams/src/mapped_file.cpp"),
    # Filesystem
    (Join-Path $boostPath "libs/filesystem/src/path.cpp"),
    (Join-Path $boostPath "libs/filesystem/src/operations.cpp"),
    (Join-Path $boostPath "libs/filesystem/src/directory.cpp"),
    (Join-Path $boostPath "libs/filesystem/src/unique_path.cpp"),
    (Join-Path $boostPath "libs/filesystem/src/portability.cpp"),
    (Join-Path $boostPath "libs/filesystem/src/codecvt_error_category.cpp"),
    (Join-Path $boostPath "libs/filesystem/src/exception.cpp"),
    (Join-Path $boostPath "libs/filesystem/src/path_traits.cpp"),
    (Join-Path $boostPath "libs/filesystem/src/utf8_codecvt_facet.cpp"),
    # More Serialization just in case
    (Join-Path $boostPath "libs/serialization/src/basic_xml_archive.cpp")
  )
  $compileArgs += $boostSrcFiles

  $compileArgs += $includePaths
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
  $compileArgs += "-sMAXIMUM_MEMORY=4294967296"  # Allow up to 4GB with ALLOW_MEMORY_GROWTH
  # Note: MEMORY64 disabled - causes type aliasing issues with Windows LLP64 cache
  # $compileArgs += "-sMEMORY64=1"
  # $compileArgs += "-sWASM_BIGINT=1"
  $compileArgs += "-sMODULARIZE=1"
  $compileArgs += "-sEXPORT_NAME=createPhaseLimiterProModule"
  $compileArgs += "-sENVIRONMENT=web,worker"
  $compileArgs += "-sFILESYSTEM=1"
  $compileArgs += "-sEXPORTED_FUNCTIONS=['_phaselimiter_pro_process','_malloc','_free']"
  $compileArgs += "-sEXPORTED_RUNTIME_METHODS=['ccall']"
  
  # Add sound_quality2_cache asset
  $cacheFile = "src_original/phaselimiter-win/phaselimiter/resource/sound_quality2_cache"
  $compileArgs += "--preload-file"
  $compileArgs += "${cacheFile}@/sound_quality2_cache"

  $compileArgs += "-o"
  $compileArgs += (Join-Path $outDir "phaselimiter_pro.js")

  & $emcc $compileArgs

  if ($LASTEXITCODE -eq 0) {
    Write-Host "Build complete: $outDir/phaselimiter_pro.{j,wasm}"
  }
  else {
    throw "emcc failed with exit code $LASTEXITCODE"
  }
}
finally {
  Pop-Location
}
