/**
 * PhaseLimiter Worker - Simple (Level 1)
 * 
 * Web Worker for running PhaseLimiter WASM module for audio mastering.
 * This is the lightweight version for simple peak limiting.
 * 
 * @version 1.2.0
 */

console.info("[PhaseLimiterWorker] v1.2.0 starting...");

// ============================================================================
// Constants
// ============================================================================

const INIT_TIMEOUT_MS = 30000;
const LOG_PREFIX = "[PhaseLimiterWorker]";
const DEFAULT_TARGET_LUFS = -14.0;
const DEFAULT_BASS_PRESERVATION = 0.5;

// ============================================================================
// Module State
// ============================================================================

let modulePromise = null;

// ============================================================================
// Memory Management
// ============================================================================

/**
 * Get or refresh the HEAPF32 view of WASM memory.
 * 
 * @param {Object} Module - Emscripten module instance
 * @returns {Float32Array} The HEAPF32 typed array view
 */
function getHEAPF32(Module) {
  if (!Module.HEAPF32 || Module.HEAPF32.buffer.byteLength === 0) {
    if (Module.HEAPF32) {
      console.log(`${LOG_PREFIX} HEAPF32 detached or invalid, refreshing view...`);
    }
    const buffer = Module.wasmMemory?.buffer || Module.memory?.buffer;
    if (!buffer) {
      return findBufferFromModuleArrays(Module);
    }
    Module.HEAPF32 = new Float32Array(buffer);
  }
  return Module.HEAPF32;
}

/**
 * Fallback buffer search when primary buffer is unavailable.
 */
function findBufferFromModuleArrays(Module) {
  for (const key in Module) {
    if (Module[key]?.buffer instanceof ArrayBuffer && Module[key].buffer.byteLength > 0) {
      Module.HEAPF32 = new Float32Array(Module[key].buffer);
      return Module.HEAPF32;
    }
  }
  throw new Error("WASM memory buffer not found or detached");
}

/**
 * Allocate WASM memory for stereo audio.
 * 
 * @param {Object} Module - Emscripten module instance  
 * @param {number} sampleCount - Number of samples per channel
 * @returns {{leftPtr: number, rightPtr: number}} Pointers to allocated memory
 */
function allocateWasmMemory(Module, sampleCount) {
  const bytesPerChannel = sampleCount * 4;
  console.log(`${LOG_PREFIX} Allocating WASM memory:`, bytesPerChannel, "bytes x 2");

  const leftPtr = Module._malloc(bytesPerChannel);
  const rightPtr = Module._malloc(bytesPerChannel);

  if (!leftPtr || !rightPtr) {
    if (leftPtr) Module._free(leftPtr);
    if (rightPtr) Module._free(rightPtr);
    throw new Error("WASM malloc failed (out of memory?)");
  }

  return { leftPtr, rightPtr };
}

/**
 * Free allocated WASM memory.
 */
function freeWasmMemory(Module, leftPtr, rightPtr) {
  Module._free(leftPtr);
  Module._free(rightPtr);
}

// ============================================================================
// Data Transfer
// ============================================================================

/**
 * Copy audio data from JavaScript to WASM memory.
 */
function copyInputToWasm(Module, leftChannel, rightChannel, leftPtr, rightPtr) {
  console.log(`${LOG_PREFIX} Copying input data to WASM...`);
  const heap = getHEAPF32(Module);
  heap.set(leftChannel, leftPtr >> 2);
  heap.set(rightChannel, rightPtr >> 2);
}

/**
 * Extract processed audio data from WASM memory.
 * 
 * @returns {{processedLeft: Float32Array, processedRight: Float32Array}}
 */
function extractResults(Module, leftPtr, rightPtr, sampleCount) {
  console.log(`${LOG_PREFIX} Extracting results...`);
  const freshHeap = getHEAPF32(Module);
  const processedLeft = new Float32Array(freshHeap.buffer, leftPtr, sampleCount).slice();
  const processedRight = new Float32Array(freshHeap.buffer, rightPtr, sampleCount).slice();
  return { processedLeft, processedRight };
}

/**
 * Convert input value to Float32Array.
 */
function asFloat32Array(value) {
  if (value instanceof Float32Array) return value;
  if (value instanceof ArrayBuffer) return new Float32Array(value);
  if (ArrayBuffer.isView(value) && value.buffer instanceof ArrayBuffer) {
    return new Float32Array(value.buffer, value.byteOffset, Math.floor(value.byteLength / 4));
  }
  throw new Error("Expected Float32Array or ArrayBuffer");
}

// ============================================================================
// Module Loading
// ============================================================================

/**
 * Initialize the PhaseLimiter WASM module with timeout.
 */
async function ensureModule() {
  if (modulePromise) return modulePromise;

  const timeoutPromise = new Promise((_, reject) => {
    setTimeout(() => reject(new Error(`PhaseLimiter initialization timed out (${INIT_TIMEOUT_MS / 1000}s)`)), INIT_TIMEOUT_MS);
  });

  const loadPromise = loadPhaseLimiterModule();

  modulePromise = Promise.race([loadPromise, timeoutPromise]).catch(err => {
    modulePromise = null; // Allow retry
    throw err;
  });

  return modulePromise;
}

async function loadPhaseLimiterModule() {
  console.log(`${LOG_PREFIX} Loading phaselimiter.js...`);
  const scriptBuster = Date.now();
  importScripts(`/js/phaselimiter.js?v=${scriptBuster}`);

  if (typeof createPhaseLimiterModule !== "function") {
    throw new Error("PhaseLimiter loader missing: createPhaseLimiterModule is not defined");
  }

  console.log(`${LOG_PREFIX} Initializing module...`);
  const Module = await createPhaseLimiterModule();
  console.log(`${LOG_PREFIX} Module ready, keys:`, Object.keys(Module).filter(k => !k.startsWith('_')));

  await waitForRuntimeInit(Module);

  getHEAPF32(Module);
  console.log(`${LOG_PREFIX} Module ready, HEAP size:`, Module.HEAPF32.length);
  return Module;
}

async function waitForRuntimeInit(Module) {
  if (!Module.calledRun) {
    console.log(`${LOG_PREFIX} Waiting for onRuntimeInitialized...`);
    await new Promise((resolve) => {
      Module.onRuntimeInitialized = () => {
        console.log(`${LOG_PREFIX} onRuntimeInitialized fired`);
        resolve();
      };
    });
  }
}

// ============================================================================
// Processing
// ============================================================================

/**
 * Create progress callback for WASM module.
 * @returns {number} - Callback function pointer (0 if not supported)
 */
function createProgressCallback(Module) {
  if (typeof Module.addFunction !== "function") return 0;

  try {
    return Module.addFunction((percent) => {
      self.postMessage({ type: "progress", percent });
    }, "vf");
  } catch (e) {
    console.warn(`${LOG_PREFIX} addFunction failed:`, e);
    return 0;
  }
}

/**
 * Clean up progress callback.
 */
function cleanupProgressCallback(Module, callback) {
  if (callback !== 0 && typeof Module.removeFunction === "function") {
    Module.removeFunction(callback);
  }
}

/**
 * Run the PhaseLimiter processing.
 */
function runPhaseLimiter(Module, leftPtr, rightPtr, sampleCount, sampleRate, config, progressCallback) {
  const targetLufs = Number(config.targetLufs ?? DEFAULT_TARGET_LUFS);
  const bassPreservation = Number(config.bassPreservation ?? DEFAULT_BASS_PRESERVATION);

  console.log(`${LOG_PREFIX} Calling run_phase_limiter...`);
  console.log(`  sampleCount: ${sampleCount}, sampleRate: ${sampleRate}`);
  console.log(`  targetLufs: ${targetLufs}, bassPreservation: ${bassPreservation}`);

  const errorCode = Module._run_phase_limiter(
    leftPtr,
    rightPtr,
    sampleCount,
    sampleRate,
    targetLufs,
    bassPreservation,
    progressCallback
  );

  console.log(`${LOG_PREFIX} Call complete, errorCode:`, errorCode);

  if (errorCode !== 0) {
    throw new Error(`Processing failed with code ${errorCode}`);
  }
}

/**
 * Parse and validate message data from main thread.
 */
function parseMessage(data) {
  const leftChannel = asFloat32Array(data.leftChannel);
  const rightChannel = asFloat32Array(data.rightChannel);
  const sampleRate = Number(data.sampleRate);
  const config = data.config ?? {};

  if (rightChannel.length !== leftChannel.length) {
    throw new Error(`Channel length mismatch: L=${leftChannel.length}, R=${rightChannel.length}`);
  }

  return { leftChannel, rightChannel, sampleRate, config, sampleCount: leftChannel.length };
}

// ============================================================================
// Message Handler
// ============================================================================

self.onmessage = async (event) => {
  const data = event.data ?? {};
  console.log(`${LOG_PREFIX} Processing request`, {
    sampleRate: data.sampleRate,
    sampleCount: data.leftChannel?.length || data.leftChannel?.byteLength / 4
  });

  try {
    const Module = await ensureModule();
    const { leftChannel, rightChannel, sampleRate, config, sampleCount } = parseMessage(data);

    const { leftPtr, rightPtr } = allocateWasmMemory(Module, sampleCount);

    try {
      copyInputToWasm(Module, leftChannel, rightChannel, leftPtr, rightPtr);

      const progressCallback = createProgressCallback(Module);
      try {
        runPhaseLimiter(Module, leftPtr, rightPtr, sampleCount, sampleRate, config, progressCallback);
      } finally {
        cleanupProgressCallback(Module, progressCallback);
      }

      const { processedLeft, processedRight } = extractResults(Module, leftPtr, rightPtr, sampleCount);

      self.postMessage(
        { type: "complete", leftChannel: processedLeft, rightChannel: processedRight },
        [processedLeft.buffer, processedRight.buffer]
      );
      console.log(`${LOG_PREFIX} Process complete`);
    } finally {
      freeWasmMemory(Module, leftPtr, rightPtr);
    }
  } catch (error) {
    console.error(`${LOG_PREFIX} Error in onmessage:`, error);
    self.postMessage({
      type: "error",
      error: error instanceof Error ? error.message : String(error),
    });
  }
};
