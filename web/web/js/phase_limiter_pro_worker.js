let modulePromise = null;

async function ensureModule() {
    if (modulePromise) return modulePromise;

    modulePromise = (async () => {
        importScripts("/js/phaselimiter_pro.js");
        if (typeof createPhaseLimiterProModule !== "function") {
            throw new Error("PhaseLimiter Pro loader missing: createPhaseLimiterProModule is not defined");
        }
        return await createPhaseLimiterProModule();
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

        const leftPtr = Module._malloc(sampleCount * 4);
        const rightPtr = Module._malloc(sampleCount * 4);
        if (!leftPtr || !rightPtr) {
            throw new Error("WASM malloc failed");
        }

        Module.HEAPF32.set(leftChannel, leftPtr >> 2);
        Module.HEAPF32.set(rightChannel, rightPtr >> 2);

        // int phaselimiter_pro_process(float *left_ptr, float *right_ptr, int length, int sample_rate, int mode)
        const errorCode = Module.ccall(
            "phaselimiter_pro_process",
            "number",
            ["number", "number", "number", "number", "number"],
            [leftPtr, rightPtr, sampleCount, sampleRate, mode]
        );

        if (errorCode !== 0) {
            Module._free(leftPtr);
            Module._free(rightPtr);
            throw new Error(`Processing failed with code ${errorCode}`);
        }

        const processedLeft = new Float32Array(Module.HEAPF32.buffer, leftPtr, sampleCount).slice();
        const processedRight = new Float32Array(Module.HEAPF32.buffer, rightPtr, sampleCount).slice();

        Module._free(leftPtr);
        Module._free(rightPtr);

        self.postMessage(
            { type: "complete", leftChannel: processedLeft, rightChannel: processedRight },
            [processedLeft.buffer, processedRight.buffer]
        );
    } catch (error) {
        self.postMessage({
            type: "error",
            error: error instanceof Error ? error.message : String(error),
        });
    }
};
