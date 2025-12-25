$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$boostDir = "v:\Slowverb\wasm\phaselimiter\src_original\boost_1_90_0-bin-msvc-all-32-64\boost_1_90_0"
$boostInclude = $boostDir
$boostLib = "$boostDir\lib32-msvc-14.3"

# We'll use the environment's cl.exe if available, otherwise we'll try to find it.
# Assuming typical VS 2022 Community install if not in path.
$cl = "cl.exe"

$src = "v:\Slowverb\wasm\phaselimiter\converter.cpp"
$out = "v:\Slowverb\wasm\phaselimiter\converter_win32.exe"

$includePaths = @(
    "/I v:\Slowverb\wasm\phaselimiter",
    "/I v:\Slowverb\wasm\phaselimiter\stubs",
    "/I v:\Slowverb\wasm\phaselimiter\src_original",
    "/I v:\Slowverb\wasm\phaselimiter\src_original\src",
    "/I v:\Slowverb\wasm\phaselimiter\src_original\deps\bakuage\include",
    "/I v:\Slowverb\wasm\phaselimiter\src_original\deps\bakuage\include\bakuage",
    "/I $boostInclude",
    "/I v:\Slowverb\wasm\phaselimiter\src_original\armadillo-15.2.3\include",
    "/I v:\Slowverb\wasm\phaselimiter\src_original\eigen-master",
    "/I v:\Slowverb\wasm\phaselimiter\src_original\prebuilt\win64\optim\header_only_version"
)

$libs = @(
    "$boostLib\libboost_serialization-vc143-mt-s-x32-1_90.lib",
    "$boostLib\libboost_filesystem-vc143-mt-s-x32-1_90.lib"
)

Write-Host "Compiling Native Win32 Converter..."
# Using /MT for static runtime, /O2 for optimization, /std:c++17
# /DBOOST_ALL_NO_LIB and /DARMA_DONT_USE_WRAPPER
& $cl /nologo /O2 /MT /std:c++17 $includePaths $src /Fe:$out /DBOOST_ALL_NO_LIB /DARMA_DONT_USE_WRAPPER $libs /link /MACHINE:X86

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build complete: $out"
    Write-Host "Running conversion..."
    & $out "v:\Slowverb\wasm\phaselimiter\src_original\phaselimiter-win\phaselimiter\resource\sound_quality2_cache" "v:\Slowverb\wasm\phaselimiter\sound_quality2_cache.txt"
}
else {
    Write-Host "Build FAILED"
}
