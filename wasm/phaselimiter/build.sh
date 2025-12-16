#!/usr/bin/env bash
set -euo pipefail

if ! command -v emcc >/dev/null 2>&1; then
  echo "Missing emcc. Install/activate Emscripten SDK (emsdk) first." >&2
  exit 1
fi

mkdir -p ../../web/web/js

emcc adapter.cpp \
  -O3 -flto \
  -sALLOW_MEMORY_GROWTH=1 \
  -sMAXIMUM_MEMORY=1GB \
  -sMODULARIZE=1 \
  -sEXPORT_NAME=createPhaseLimiterModule \
  -sENVIRONMENT=web,worker \
  -sFILESYSTEM=0 \
  -sEXPORTED_FUNCTIONS="[_run_phase_limiter,_malloc,_free]" \
  -sEXPORTED_RUNTIME_METHODS="[ccall]" \
  -o ../../web/web/js/phaselimiter.js

echo "Build complete: web/web/js/phaselimiter.{js,wasm}"
