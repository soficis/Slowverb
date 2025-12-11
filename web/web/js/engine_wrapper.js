/**
 * Slowverb Web - Engine Wrapper (Main Thread)
 * 
 * Implements command-specific functions that accept direct parameters,
 * bypassing Dart-to-JS object serialization issues.
 */

// Global state
let ffmpeg = null;
let logHandler = null;
let isReady = false;
let isFFmpegBusy = false; // Kept as fall-back or for status checks if needed
let commandQueue = Promise.resolve(); // Queue for serializing FFmpeg operations
let ffmpegOperationCount = 0; // Track operations to work around v0.11.x 2-operation limit
let loadedFiles = new Map(); // Cache loaded files to restore after FFmpeg reload

/**
 * Initialize the audio engine
 */
async function initWorker() {
    console.log('[SlowverbEngine] Initializing in Main Thread (v0.11.x)...');
    isReady = false;

    // FFmpeg v0.11.x API check
    const { createFFmpeg, fetchFile } = FFmpeg;

    if (!createFFmpeg) {
        const error = 'FFmpeg v0.11 symbols not found';
        console.error('[SlowverbEngine]', error);
        if (logHandler) logHandler(`Error: ${error}`);
        return;
    }

    try {
        // Correct single-threaded core path for v0.11.6
        // We use corePath to point to the CDN version of ffmpeg-core.js
        ffmpeg = createFFmpeg({
            log: true,
            corePath: 'https://unpkg.com/@ffmpeg/core-st@0.11.1/dist/ffmpeg-core.js',
            mainName: 'main'
        });

        // Redirect local log to handler
        ffmpeg.setLogger(({ message }) => {
            console.log(`[FFmpeg-Core] ${message}`);
            if (logHandler) logHandler(`FFmpeg: ${message}`);
        });

        console.log('[SlowverbEngine] Loading FFmpeg core...');
        if (logHandler) logHandler('Loading FFmpeg core...');

        await ffmpeg.load();

        isReady = true;
        console.log('[SlowverbEngine] Ready!');
        if (logHandler) logHandler('Audio Engine Ready');

    } catch (e) {
        console.error('[SlowverbEngine] Init failed:', e);
        if (logHandler) logHandler(`Init Error: ${e.message}`);
    }
}

/**
 * Reload FFmpeg instance to clear internal state
 * Workaround for v0.11.x 2-operation limit
 */
async function reloadFFmpeg() {
    console.log('[SlowverbEngine] Reloading FFmpeg instance...');
    try {
        // Save current loaded files before clearing
        const filesToRestore = new Map(loadedFiles);
        console.log(`[SlowverbEngine] Will restore ${filesToRestore.size} files after reload`);

        // Clear existing instance
        ffmpeg = null;
        isReady = false;

        // Reinitialize
        await initWorker();

        // Restore all previously loaded files
        if (filesToRestore.size > 0) {
            console.log('[SlowverbEngine] Restoring loaded files...');
            for (const [fileId, fileData] of filesToRestore.entries()) {
                try {
                    ffmpeg.FS('writeFile', fileId, fileData);
                    console.log(`[SlowverbEngine] Restored file: ${fileId}`);
                } catch (restoreErr) {
                    console.error(`[SlowverbEngine] Failed to restore ${fileId}:`, restoreErr);
                }
            }
        }

        console.log('[SlowverbEngine] FFmpeg instance reloaded successfully');
    } catch (e) {
        console.error('[SlowverbEngine] Reload failed:', e);
        throw e;
    }
}

/**
 * Load source - accepts individual params
 */
function loadSource(fileId, filename, bytes, callback) {
    if (!isReady) {
        console.error('[SlowverbEngine] NOT READY called loadSource');
        callback({ type: 'error', payload: { error: 'Engine not ready (still loading?)' } });
        return;
    }

    console.log('[SlowverbEngine] loadSource called');
    console.log('[SlowverbEngine] arguments.length:', arguments.length);
    console.log('[SlowverbEngine] fileId:', fileId === undefined ? 'UNDEFINED' : (fileId === null ? 'NULL' : fileId));
    console.log('[SlowverbEngine] bytes:', bytes === undefined ? 'UNDEFINED' : (bytes === null ? 'NULL' : (bytes instanceof Uint8Array ? 'Uint8Array' : typeof bytes)));

    // Force aggressive error reporting
    if (fileId === undefined || fileId === null) {
        throw new Error('[SlowverbEngine] CRITICAL: fileId is undefined/null! Arguments: ' + JSON.stringify(arguments));
    }
    if (bytes === undefined || bytes === null) {
        throw new Error('[SlowverbEngine] CRITICAL: bytes is undefined/null!');
    }

    // Add to command queue to ensure serialization
    commandQueue = commandQueue.then(async () => {
        console.log(`[SlowverbEngine] loadSource executing for ${fileId}`);
        try {
            if (!ffmpeg) {
                throw new Error('Engine not initialized');
            }

            console.log('[SlowverbEngine] Writing file:', fileId);

            let fileData;
            try {
                if (bytes instanceof Uint8Array) {
                    fileData = bytes;
                } else {
                    console.log('[SlowverbEngine] Converting bytes to Uint8Array...');
                    fileData = new Uint8Array(bytes);
                }
                console.log('[SlowverbEngine] File data prepared, length:', fileData.length);
            } catch (err) {
                throw new Error('[SlowverbEngine] Failed to prepare file data: ' + err.message);
            }

            try {
                // v0.11 API uses FS explicitly
                ffmpeg.FS('writeFile', fileId, fileData);
                console.log('[SlowverbEngine] File written successfully');

                // Cache the file data for potential FFmpeg reloads
                loadedFiles.set(fileId, fileData);
                console.log(`[SlowverbEngine] Cached file ${fileId} for reload`);

                callback({ type: 'load-ok', payload: { fileId } });
            } catch (fsErr) {
                throw new Error('[SlowverbEngine] ffmpeg.FS writeFile failed: ' + fsErr.message);
            }
        } catch (e) {
            console.error('[SlowverbEngine] loadSource error:', e);
            callback({ type: 'error', payload: { error: e.message } });
        }
    }).catch(err => console.error('[SlowverbEngine] loadSource queue error:', err));

    return "req-load-source";
}

/**
 * Probe - accepts fileId
 */
function probe(fileId, callback) {
    console.log('[SlowverbEngine] probe called - fileId:', fileId);

    // TODO: Implement proper FFmpeg probing without concurrency issues
    // For now, return null duration to process entire file
    callback({
        type: 'probe-ok',
        payload: {
            fileId: fileId,
            duration: null,  // null = process entire file
            sampleRate: 44100,
            channels: 2,
            format: 'mp3'
        }
    });

    return "req-probe";
}

/**
 * Render full - accepts individual params
 */
function renderFull(fileId, filterChain, format, bitrateKbps, callback) {
    console.log('[SlowverbEngine] renderFull called');

    if (!ffmpeg) {
        callback({ type: 'error', payload: { error: 'Engine not initialized' } });
        return "error-not-init";
    }

    // CRITICAL: Assign to commandQueue SYNCHRONOUSLY to avoid race conditions
    commandQueue = commandQueue.then(async () => {
        console.log('[SlowverbEngine] Starting renderFull in queue');

        // Use unique filename to avoid conflicts
        const outputFile = `output_${Date.now()}.${format}`;
        const args = ['-i', fileId];

        if (filterChain && filterChain !== 'anull') {
            args.push('-af', filterChain);
        }

        if (format === 'mp3') {
            args.push('-c:a', 'libmp3lame', '-b:a', `${bitrateKbps}k`);
        } else if (format === 'wav') {
            args.push('-c:a', 'pcm_s16le');
        }

        args.push('-y', outputFile); // -y to overwrite if exists

        console.log('[SlowverbEngine] Executing FFmpeg (Full):', args.join(' '));

        try {
            // Use ffmpeg.run for v0.11
            await ffmpeg.run(...args);

            // If we get here without exception (unlikely in v0.11.x), read output
            const data = ffmpeg.FS('readFile', outputFile);

            callback({
                type: 'render-full-ok',
                payload: {
                    outputBuffer: data.buffer,
                    format
                }
            });

            try { ffmpeg.FS('unlink', outputFile); } catch (e) { }

        } catch (e) {
            // FFmpeg.wasm v0.11.x throws ExitStatus(0) on successful completion
            if (e?.name === 'ExitStatus' && e?.status === 0) {
                console.log('[SlowverbEngine] renderFull completed successfully (exit 0)');
                // Small delay to ensure FFmpeg has fully flushed the output file
                await new Promise(resolve => setTimeout(resolve, 100));
                try {
                    // List files to debug
                    try {
                        const files = ffmpeg.FS('readdir', '/');
                        console.log('[SlowverbEngine] Files in root:', files.join(', '));
                    } catch (listErr) {
                        console.warn('[SlowverbEngine] Could not list files:', listErr);
                    }

                    const data = ffmpeg.FS('readFile', outputFile);
                    console.log('[SlowverbEngine] Read output file, size:', data.length);
                    callback({
                        type: 'render-full-ok',
                        payload: {
                            outputBuffer: data.buffer,
                            format
                        }
                    });
                    try { ffmpeg.FS('unlink', outputFile); } catch (cleanupErr) { }
                } catch (readErr) {
                    console.error('[SlowverbEngine] Exit 0 but failed to read output:', readErr);
                    console.error('[SlowverbEngine] Expected output file:', outputFile);
                    // Try to list files for debugging
                    try {
                        const files = ffmpeg.FS('readdir', '/');
                        console.error('[SlowverbEngine] Available files:', files.join(', '));
                    } catch (listErr) {
                        console.error('[SlowverbEngine] Could not list files');
                    }
                    callback({ type: 'error', payload: { error: 'FFmpeg succeeded but output file missing' } });
                }
            } else {
                // Real error
                console.error('[SlowverbEngine] renderFull CAUGHT ERROR');
                console.error('[SlowverbEngine] Error type:', typeof e);
                console.error('[SlowverbEngine] Error message:', e?.message || 'undefined');
                console.error('[SlowverbEngine] Error string:', e?.toString() || 'undefined');

                // Clean up output file if it exists
                try {
                    ffmpeg.FS('unlink', outputFile);
                } catch (cleanupErr) { }

                callback({ type: 'error', payload: { error: e?.message || e?.toString() || 'FFmpeg processing failed' } });
            }
        } finally {
            // Increment operation counter
            ffmpegOperationCount++;
            console.log(`[SlowverbEngine] Operation count: ${ffmpegOperationCount}`);

            // FFmpeg.wasm 0.11.x can only handle 2 operations before internal state breaks
            // Reload instance after every 2 operations as workaround
            if (ffmpegOperationCount >= 2) {
                console.log('[SlowverbEngine] Reached operation limit - reloading FFmpeg instance');
                try {
                    // Minimal delay for current operation to fully complete
                    await new Promise(resolve => setTimeout(resolve, 100));
                    await reloadFFmpeg();
                    ffmpegOperationCount = 0;
                } catch (reloadErr) {
                    console.error('[SlowverbEngine] FFmpeg reload failed:', reloadErr);
                }
            } else {
                console.log('[SlowverbEngine] Waiting 200ms before next operation');
                await new Promise(resolve => setTimeout(resolve, 200));
            }

            console.log('[SlowverbEngine] FFmpeg unlocked, renderFull finished');
        }
    }).catch(err => {
        console.error('[SlowverbEngine] renderFull queue error:', err);
        callback({ type: 'error', payload: { error: 'Queue error: ' + (err.message || err) } });
    });

    return "req-render-full";
}

/**
 * Render preview (snippet)
 * config: { filterChain, startSec, durationSec }
 */
/**
 * Render preview (snippet)
 * config: { filterChain, startSec, durationSec }
 */
function renderPreview(fileId, config, callback) {
    console.log('[SlowverbEngine] renderPreview called');

    if (!ffmpeg) {
        callback({ type: 'error', payload: { error: 'Engine not initialized' } });
        return "error-not-init";
    }

    // CRITICAL: Assign to commandQueue SYNCHRONOUSLY to avoid race conditions
    commandQueue = commandQueue.then(async () => {
        console.log('[SlowverbEngine] Starting renderPreview in queue');

        const { filterChain, startSec, durationSec } = config || {};
        // Use unique filename to avoid conflicts
        const outputFile = `preview_${Date.now()}.mp3`;

        try {
            // Build FFmpeg args
            const args = ['-ss', `${startSec || 0}`];
            if (durationSec != null && durationSec > 0) {
                args.push('-t', `${durationSec}`);
            }
            args.push('-i', fileId);

            if (filterChain && filterChain !== 'anull') {
                args.push('-af', filterChain);
            }

            args.push('-c:a', 'libmp3lame', '-b:a', '128k', outputFile);

            console.log('[SlowverbEngine] Executing Preview FFmpeg:', args.join(' '));

            await ffmpeg.run(...args);

            // Read output
            const data = ffmpeg.FS('readFile', outputFile);

            callback({
                type: 'render-preview-ok',
                payload: {
                    buffer: data.buffer
                }
            });

            try { ffmpeg.FS('unlink', outputFile); } catch (e) { }

        } catch (e) {
            // FFmpeg.wasm v0.11.x throws ExitStatus(0) on successful completion
            // Check if this is a successful exit before treating as error
            if (e?.name === 'ExitStatus' && e?.status === 0) {
                console.log('[SlowverbEngine] FFmpeg completed successfully (exit 0)');
                // Small delay to ensure FFmpeg has fully flushed the output file
                await new Promise(resolve => setTimeout(resolve, 50));
                try {
                    // Read output file - it should exist if FFmpeg succeeded
                    const data = ffmpeg.FS('readFile', outputFile);
                    callback({
                        type: 'render-preview-ok',
                        payload: {
                            buffer: data.buffer
                        }
                    });
                    // Clean up
                    try { ffmpeg.FS('unlink', outputFile); } catch (cleanupErr) { }
                } catch (readErr) {
                    console.error('[SlowverbEngine] Exit 0 but failed to read output:', readErr);
                    callback({ type: 'error', payload: { error: 'FFmpeg succeeded but output file missing' } });
                }
            } else {
                // Real error - log details and return error
                console.error('[SlowverbEngine] renderPreview CAUGHT ERROR');
                console.error('[SlowverbEngine] Error type: ' + typeof e);
                try {
                    const jsonObj = JSON.stringify(e, Object.getOwnPropertyNames(e));
                    console.error('[SlowverbEngine] Error object JSON: ' + jsonObj);
                } catch (jsonErr) {
                    console.error('[SlowverbEngine] Could not stringify error object');
                }
                console.error('[SlowverbEngine] Error message: ' + (e?.message || 'undefined'));
                console.error('[SlowverbEngine] Error string: ' + (e?.toString() || 'undefined'));
                console.error('[SlowverbEngine] Error stack: ' + (e?.stack || 'undefined'));

                // Clean up output file if it exists
                try {
                    ffmpeg.FS('unlink', outputFile);
                    console.log('[SlowverbEngine] Cleaned up output file: ' + outputFile);
                } catch (cleanupErr) {
                    console.warn('[SlowverbEngine] Cleanup error: ' + (cleanupErr.message || cleanupErr));
                }

                // Return detailed error information
                let errorMsg = 'FFmpeg processing failed';
                if (e) {
                    if (typeof e === 'string') {
                        errorMsg = e;
                    } else if (e.message) {
                        errorMsg = e.message;
                    } else if (e.toString && e.toString() !== '[object Object]') {
                        errorMsg = e.toString();
                    }
                }
                console.error('[SlowverbEngine] Final error message: ' + errorMsg);
                callback({ type: 'error', payload: { error: errorMsg } });
            }
        } finally {
            // Increment operation counter
            ffmpegOperationCount++;
            console.log(`[SlowverbEngine] Operation count: ${ffmpegOperationCount}`);

            // FFmpeg.wasm 0.11.x can only handle 2 operations before internal state breaks
            // Reload instance after every 2 operations as workaround
            if (ffmpegOperationCount >= 2) {
                console.log('[SlowverbEngine] Reached operation limit - reloading FFmpeg instance');
                try {
                    // Minimal delay for current operation to fully complete
                    await new Promise(resolve => setTimeout(resolve, 100));
                    await reloadFFmpeg();
                    ffmpegOperationCount = 0;
                } catch (reloadErr) {
                    console.error('[SlowverbEngine] FFmpeg reload failed:', reloadErr);
                }
            } else {
                console.log('[SlowverbEngine] Waiting 200ms before next operation');
                await new Promise(resolve => setTimeout(resolve, 200));
            }

            console.log('[SlowverbEngine] FFmpeg unlocked, task finished');
        }
    }).catch(err => {
        console.error('[SlowverbEngine] Command queue error:', err);
        callback({ type: 'error', payload: { error: 'Queue error: ' + (err.message || err) } });
    });

    return "req-render-preview";
}

/**
 * Get waveform (extracts simplified amplitude data). 
 * For now, returning mock data to unblock UI if proper extraction is hard.
 * Real implementation would use showwavespic or a custom filter.
 */
function getWaveform(fileId, callback) {
    console.log('[SlowverbEngine] getWaveform called');

    // For now, return a dummy success to unblock the UI.
    // Real waveform generation in FFmpeg requires complex parsing of pcm data.
    callback({
        type: 'waveform-ok',
        payload: {
            // Empty or mock data
            samples: new Float32Array(100).fill(0.5)
        }
    });
    return "req-waveform";
}

/**
 * Legacy postMessage for compatibility
 */
function postMessage(type, payload, callback) {
    if (typeof type !== 'string') {
        console.warn('[SlowverbEngine] Ignoring non-string command type:', type);
        return "ignored";
    }

    console.log(`[SlowverbEngine] postMessage - type: ${type}`);

    (async () => {
        try {
            switch (type) {
                case 'init':
                    if (ffmpeg) {
                        callback({ type: 'init-ok', payload: { ready: true } });
                    } else {
                        await initWorker();
                        if (ffmpeg) {
                            callback({ type: 'init-ok', payload: { ready: true } });
                        } else {
                            callback({ type: 'error', payload: { error: 'Failed to initialize engine' } });
                        }
                    }
                    break;

                case 'cleanup':
                    commandQueue = commandQueue.then(async () => {
                        console.log('[SlowverbEngine] Queued cleanup');
                        const fileId = payload?.fileId;
                        if (fileId && ffmpeg) {
                            try {
                                // Only clean up if not busy with something else? 
                                // Since we are in queue, we know we are exclusive.
                                await ffmpeg.FS('unlink', fileId);
                            } catch (e) { }
                        }
                        callback({ type: 'cleanup-ok', payload: {} });
                    }).catch(err => console.error('[SlowverbEngine] Cleanup error:', err));
                    break;

                default:
                    console.warn(`[SlowverbEngine] Unknown command: ${type}`);
                    callback({ type: 'error', payload: { message: `Unknown command ${type}` } });
            }
        } catch (e) {
            console.error(`[SlowverbEngine] Error processing ${type}:`, e);
            callback({ type: 'error', payload: { error: e.message } });
        }
    })();

    return "req-id-main-thread";
}

function setLogHandler(callback) {
    logHandler = callback;
}

function terminateWorker() {
    console.log('[SlowverbEngine] Terminated');
    ffmpeg = null;
}

// Expose to global scope
window.SlowverbEngine = {
    initWorker,
    postMessage,
    setLogHandler,
    terminateWorker,
    loadSource,
    probe,
    renderFull,
    renderPreview,
    getWaveform,
};

console.log('[SlowverbEngine] Wrapper loaded (param-based w/ debug)');
