$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\\..")
$outDir = Join-Path $repoRoot "web\\web\\js"

if (-not (Get-Command emcc -ErrorAction SilentlyContinue)) {
  throw "Missing emcc. Install/activate Emscripten SDK (emsdk) first."
}

New-Item -ItemType Directory -Path $outDir -Force | Out-Null

Push-Location $scriptDir
try {
  emcc adapter.cpp `
    -O3 -flto `
    "-sALLOW_MEMORY_GROWTH=1" `
    "-sMAXIMUM_MEMORY=1GB" `
    "-sMODULARIZE=1" `
    "-sEXPORT_NAME=createPhaseLimiterModule" `
    "-sENVIRONMENT=web,worker" `
    "-sFILESYSTEM=0" `
    "-sEXPORTED_FUNCTIONS=[_run_phase_limiter,_malloc,_free]" `
    "-sEXPORTED_RUNTIME_METHODS=[ccall]" `
    -o (Join-Path $outDir "phaselimiter.js")
} finally {
  Pop-Location
}

Write-Host "Build complete: web/web/js/phaselimiter.{js,wasm}"
