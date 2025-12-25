let modulePromise = null;

async function ensureModule() {
    if (modulePromise) return modulePromise;

    modulePromise = (async () => {
        const cacheBust = Date.now();
        importScripts("/js/phaselimiter_pro.js?v=" + cacheBust);
        if (typeof createPhaseLimiterProModule !== "function") {
            throw new Error("PhaseLimiter Pro loader missing: createPhaseLimiterProModule is not defined");
        }
        return await createPhaseLimiterProModule({
            locateFile: (path) => {
                if (path.endsWith(".wasm") || path.endsWith(".data")) {
                    return "/js/" + path + "?v=" + cacheBust;
                }
                return path;
            }
        });
    })();

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
    try {
        const Module = await ensureModule();

        const leftChannel = asFloat32Array(data.leftChannel);
        const rightChannel = asFloat32Array(data.rightChannel);
        const sampleRate = Number(data.sampleRate);
        const config = data.config ?? {};
        // Pro mode selection (default to 3). 
        // 2=AutoMastering2, 3=AutoMastering3 (Pro), 5=AutoMastering5
        const mode = Number(config.mode ?? 3);

        const sampleCount = leftChannel.length;
        if (rightChannel.length !== sampleCount) {
            throw new Error("Channel length mismatch");
        }

        // In WASM32, malloc returns Number. In MEMORY64, it returns BigInt.
        // BigInt pointers are safe to pass to ccall as "number" types in MEMORY64 mode,
        // but in WASM32 mode, ccall expects regular Numbers for the "number" argument type.
        const leftPtrRaw = Module._malloc(sampleCount * 4);
        const rightPtrRaw = Module._malloc(sampleCount * 4);
        console.log(`[PhaseLimiterWorker] leftPtrRaw: ${leftPtrRaw} (type: ${typeof leftPtrRaw})`);
        console.log(`[PhaseLimiterWorker] rightPtrRaw: ${rightPtrRaw} (type: ${typeof rightPtrRaw})`);

        if (!leftPtrRaw || !rightPtrRaw) {
            throw new Error("WASM malloc failed");
        }

        // Convert to Number for heap indexing (always safe for 32-bit offset)
        const leftPtr = Number(leftPtrRaw);
        const rightPtr = Number(rightPtrRaw);

        Module.HEAPF32.set(leftChannel, leftPtr >> 2);
        Module.HEAPF32.set(rightChannel, rightPtr >> 2);

        // int phaselimiter_pro_process(float *left_ptr, float *right_ptr, int length, int sample_rate, int mode)
        const errorCode = Module.ccall(
            "phaselimiter_pro_process",
            "number",
            ["number", "number", "number", "number", "number"],
            [leftPtrRaw, rightPtrRaw, sampleCount, sampleRate, mode]
        );

        console.log(`[PhaseLimiterWorker] errorCode: ${errorCode} (type: ${typeof errorCode})`);

        if (errorCode !== 0 && errorCode !== 1) {
            Module._free(leftPtrRaw);
            Module._free(rightPtrRaw);
            throw new Error(`Processing failed with code ${errorCode}`);
        }

        const warning = errorCode === 1 ? "Level 5 failed, using Level 3 fallback" : null;

        const processedLeft = Module.HEAPF32.slice(leftPtr >> 2, (leftPtr >> 2) + sampleCount);
        const processedRight = Module.HEAPF32.slice(rightPtr >> 2, (rightPtr >> 2) + sampleCount);

        Module._free(leftPtrRaw);
        Module._free(rightPtrRaw);

        self.postMessage(
            {
                type: "complete",
                leftChannel: processedLeft,
                rightChannel: processedRight,
                warning
            },
            [processedLeft.buffer, processedRight.buffer]
        );
    } catch (error) {
        self.postMessage({
            type: "error",
            error: error instanceof Error ? error.message : String(error),
        });
    }
};
