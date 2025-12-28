$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$emsdkRoot = "v:\Slowverb\build\emsdk"
$upstreamManual = Join-Path $emsdkRoot "upstream_manual"
$emcc = Join-Path $upstreamManual "emscripten\emcc.bat"
$nodePath = Join-Path $emsdkRoot "node\22.16.0_64bit\bin"
$pythonPath = Join-Path $emsdkRoot "python\3.13.3_64bit"

$env:PATH = "$nodePath;$pythonPath;$env:PATH"
$env:EMSDK_NODE = Join-Path $nodePath "node.exe"
$env:EMSDK_PYTHON = Join-Path $pythonPath "python.exe"

$boostPathRel = "src_original/boost_1_89_0"

$srcFiles = @(
    "converter.cpp",
    "$boostPathRel/libs/serialization/src/archive_exception.cpp",
    "$boostPathRel/libs/serialization/src/basic_archive.cpp",
    "$boostPathRel/libs/serialization/src/basic_iarchive.cpp",
    "$boostPathRel/libs/serialization/src/basic_iserializer.cpp",
    "$boostPathRel/libs/serialization/src/basic_oarchive.cpp",
    "$boostPathRel/libs/serialization/src/basic_oserializer.cpp",
    "$boostPathRel/libs/serialization/src/basic_pointer_iserializer.cpp",
    "$boostPathRel/libs/serialization/src/basic_pointer_oserializer.cpp",
    "$boostPathRel/libs/serialization/src/basic_serializer_map.cpp",
    "$boostPathRel/libs/serialization/src/basic_text_iprimitive.cpp",
    "$boostPathRel/libs/serialization/src/basic_text_oprimitive.cpp",
    "$boostPathRel/libs/serialization/src/binary_iarchive.cpp",
    "$boostPathRel/libs/serialization/src/binary_oarchive.cpp",
    "$boostPathRel/libs/serialization/src/extended_type_info.cpp",
    "$boostPathRel/libs/serialization/src/extended_type_info_typeid.cpp",
    "$boostPathRel/libs/serialization/src/polymorphic_iarchive.cpp",
    "$boostPathRel/libs/serialization/src/polymorphic_oarchive.cpp",
    "$boostPathRel/libs/serialization/src/text_iarchive.cpp",
    "$boostPathRel/libs/serialization/src/text_oarchive.cpp",
    "$boostPathRel/libs/serialization/src/void_cast.cpp"
)

$includePaths = @(
    "-I.",
    "-Istubs",
    "-Isrc_original",
    "-Isrc_original/src",
    "-Isrc_original/deps/bakuage/include",
    "-Isrc_original/deps/bakuage/include/bakuage",
    "-I$boostPathRel",
    "-Isrc_original/armadillo-15.2.3/include",
    "-Isrc_original/eigen-master",
    "-Isrc_original/prebuilt/win64/optim/header_only_version"
)

$argsFile = "conv_args.txt"
$params = @()
foreach ($f in $srcFiles) { $params += $f }
foreach ($i in $includePaths) { $params += $i }
$params += "-O3"
$params += "-sMEMORY64=1"
$params += "-sNODERAWFS=1"
$params += "-sDISABLE_EXCEPTION_CATCHING=0"
$params += "-DBOOST_ALL_NO_LIB"
$params += "-DARMA_DONT_USE_WRAPPER"
$params += "-o"
$params += "converter.js"

$params | Out-File -FilePath $argsFile -Encoding ascii

Write-Host "Compiling Converter (WASM64)..."
# Use call operator with the bat file
& cmd /c "$emcc @$argsFile"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build complete. Running conversion..."
    & (Join-Path $nodePath "node.exe") --experimental-wasm-memory64 converter.js `
        "src_original/phaselimiter-win/phaselimiter/resource/sound_quality2_cache" `
        "v:\Slowverb\wasm\phaselimiter\sound_quality2_cache.txt"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Conversion finished: sound_quality2_cache.txt"
    }
    else {
        Write-Host "Conversion FAILED"
    }
}
else {
    Write-Host "Build FAILED"
}
