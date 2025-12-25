console.info("[PhaseLimiterWorker] v1.1.2-debug starting...");
let modulePromise = null;

function getHEAPF32(Module) {
  // Check if buffer is detached (byteLength becomes 0 in most modern browsers)
  if (!Module.HEAPF32 || Module.HEAPF32.buffer.byteLength === 0) {
    if (Module.HEAPF32) console.log("[PhaseLimiterWorker] HEAPF32 detached or invalid, refreshing view...");
    const buffer = Module.wasmMemory?.buffer || Module.memory?.buffer;
    if (!buffer) {
      // Search for any typed array to find the buffer
      for (const key in Module) {
        if (Module[key] && Module[key].buffer instanceof ArrayBuffer && Module[key].buffer.byteLength > 0) {
          Module.HEAPF32 = new Float32Array(Module[key].buffer);
          return Module.HEAPF32;
        }
      }
      throw new Error("WASM memory buffer not found or detached");
    }
    Module.HEAPF32 = new Float32Array(buffer);
  }
  return Module.HEAPF32;
}

async function ensureModule() {
  if (modulePromise) return modulePromise;

  const timeoutPromise = new Promise((_, reject) => {
    setTimeout(() => reject(new Error("PhaseLimiter initialization timed out (30s)")), 30000);
  });

  const loadPromise = (async () => {
    console.log("[PhaseLimiterWorker] Loading phaselimiter.js...");
    // Use cache buster for the imported script too
    const scriptBuster = Date.now();
    importScripts(`/js/phaselimiter.js?v=${scriptBuster}`);

    if (typeof createPhaseLimiterModule !== "function") {
      throw new Error("PhaseLimiter loader missing: createPhaseLimiterModule is not defined");
    }

    console.log("[PhaseLimiterWorker] Initializing module...");
    const Module = await createPhaseLimiterModule();
    console.log("[PhaseLimiterWorker] Module ready, keys:", Object.keys(Module).filter(k => !k.startsWith('_')));

    if (!Module.calledRun) {
      console.log("[PhaseLimiterWorker] Waiting for onRuntimeInitialized...");
      await new Promise((resolve) => {
        Module.onRuntimeInitialized = () => {
          console.log("[PhaseLimiterWorker] onRuntimeInitialized fired");
          resolve();
        };
      });
    }

    // Initialize/Verify HEAPF32
    getHEAPF32(Module);
    console.log("[PhaseLimiterWorker] Module ready, HEAP size:", Module.HEAPF32.length);
    return Module;
  })();

  modulePromise = Promise.race([loadPromise, timeoutPromise]).catch(err => {
    modulePromise = null; // Allow retry
    throw err;
  });

  return modulePromise;
}

function asFloat32Array(value) {
  if (value instanceof Float32Array) return value;
  if (value instanceof ArrayBuffer) return new Float32Array(value);
  if (ArrayBuffer.isView(value) && value.buffer instanceof ArrayBuffer) {
    return new Float32Array(value.buffer, value.byteOffset, Math.floor(value.byteLength / 4));
  }
  throw new Error("Expected Float32Array or ArrayBuffer");
}

self.onmessage = async (event) => {
  const data = event.data ?? {};
  console.log("[PhaseLimiterWorker] Processing request", {
    sampleRate: data.sampleRate,
    sampleCount: data.leftChannel?.length || data.leftChannel?.byteLength / 4
  });

  try {
    const Module = await ensureModule();

    const leftChannel = asFloat32Array(data.leftChannel);
    const rightChannel = asFloat32Array(data.rightChannel);
    const sampleRate = Number(data.sampleRate);
    const config = data.config ?? {};
    const targetLufs = Number(config.targetLufs ?? -14.0);
    const bassPreservation = Number(config.bassPreservation ?? 0.5);

    const sampleCount = leftChannel.length;
    if (rightChannel.length !== sampleCount) {
      throw new Error(`Channel length mismatch: L=${leftChannel.length}, R=${rightChannel.length}`);
    }

    console.log("[PhaseLimiterWorker] Allocating WASM memory:", sampleCount * 4, "bytes x 2");
    const leftPtr = Module._malloc(sampleCount * 4);
    const rightPtr = Module._malloc(sampleCount * 4);
    if (!leftPtr || !rightPtr) {
      throw new Error("WASM malloc failed (out of memory?)");
    }

    try {
      console.log("[PhaseLimiterWorker] Copying input data to WASM...");
      // Ensure HEAPF32 is fresh (it might have grown during malloc)
      const heap = getHEAPF32(Module);
      heap.set(leftChannel, leftPtr >> 2);
      heap.set(rightChannel, rightPtr >> 2);

      let progressCallback = 0;
      if (typeof Module.addFunction === "function") {
        try {
          progressCallback = Module.addFunction((percent) => {
            self.postMessage({ type: "progress", percent });
          }, "vf");
        } catch (e) {
          console.warn("[PhaseLimiterWorker] addFunction failed:", e);
        }
      }

      const midIndex = Math.floor(sampleCount / 2);
      console.info("[PhaseLimiterWorker] Input check (mid): L=" + leftChannel[midIndex] + " R=" + rightChannel[midIndex]);

      const heapBefore = getHEAPF32(Module);
      console.log("  leftPtr:", leftPtr, "rightPtr:", rightPtr);
      console.log("  sampleCount:", sampleCount, "sampleRate:", sampleRate);
      console.log("  targetLufs:", targetLufs, "bassPreservation:", bassPreservation);
      console.log("  samples (L) [0-4]:", Array.from(heapBefore.subarray(leftPtr >> 2, (leftPtr >> 2) + 5)));
      console.log("  samples (L) [mid-mid+4]:", Array.from(heapBefore.subarray((leftPtr >> 2) + midIndex, (leftPtr >> 2) + midIndex + 5)));
      console.log("  samples (R) [mid-mid+4]:", Array.from(heapBefore.subarray((rightPtr >> 2) + midIndex, (rightPtr >> 2) + midIndex + 5)));

      console.log("[PhaseLimiterWorker] Calling run_phase_limiter directly...");
      console.log("  Function type:", typeof Module._run_phase_limiter);
      const errorCode = Module._run_phase_limiter(
        leftPtr,
        rightPtr,
        sampleCount,
        sampleRate,
        targetLufs,
        bassPreservation,
        progressCallback
      );

      if (progressCallback !== 0 && typeof Module.removeFunction === "function") {
        Module.removeFunction(progressCallback);
      }

      console.log("[PhaseLimiterWorker] Call complete, errorCode:", errorCode);

      if (errorCode !== 0) {
        throw new Error(`Processing failed with code ${errorCode}`);
      }

      console.log("[PhaseLimiterWorker] Extracting results...");
      // Refresh heap again in case processing triggered growth
      const freshHeap = getHEAPF32(Module);
      console.log("  samples (L) [mid-mid+4] after:", Array.from(freshHeap.subarray((leftPtr >> 2) + midIndex, (leftPtr >> 2) + midIndex + 5)));
      console.log("  samples (R) [mid-mid+4] after:", Array.from(freshHeap.subarray((rightPtr >> 2) + midIndex, (rightPtr >> 2) + midIndex + 5)));
      console.info("[PhaseLimiterWorker] Output check (mid): L=" + freshHeap[(leftPtr >> 2) + midIndex] + " R=" + freshHeap[(rightPtr >> 2) + midIndex]);
      const processedLeft = new Float32Array(freshHeap.buffer, leftPtr, sampleCount).slice();
      const processedRight = new Float32Array(freshHeap.buffer, rightPtr, sampleCount).slice();

      self.postMessage(
        { type: "complete", leftChannel: processedLeft, rightChannel: processedRight },
        [processedLeft.buffer, processedRight.buffer]
      );
      console.log("[PhaseLimiterWorker] Process complete");
    } finally {
      Module._free(leftPtr);
      Module._free(rightPtr);
    }
  } catch (error) {
    console.error("[PhaseLimiterWorker] Error in onmessage:", error);
    self.postMessage({
      type: "error",
      error: error instanceof Error ? error.message : String(error),
    });
  }
};
