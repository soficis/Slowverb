/**
 * Slowverb Web - Audio Worker
 * 
 * Web Worker that handles all FFmpeg WASM audio processing.
 * Runs in a separate thread to keep the UI responsive during renders.
 */

let FFmpegWASM = null;
let FFmpegUtil = null;
let ffmpeg = null;
let currentJobId = null;
let initError = null;

// Polyfill document for UMD scripts that expect it
if (typeof document === 'undefined') {
    self.document = {
        createElement: () => ({}),
        addEventListener: () => { },
        baseURI: self.location.href,
        getElementsByTagName: () => [],
        currentScript: { src: self.location.href },
    };
}
if (typeof window === 'undefined') {
    self.window = self;
}

// Try to load FFmpeg scripts
// ffmpeg.js resolves its internal worker chunk (814.ffmpeg.js) relative to this worker
// when loaded via importScripts, so keep 814.ffmpeg.js alongside this file.
try {
    importScripts('vendor/ffmpeg.js');
    importScripts('vendor/ffmpeg-util.js');
    FFmpegWASM = self.FFmpegWASM;
    FFmpegUtil = self.FFmpegUtil;
    console.log('[audio_worker] FFmpegWASM loaded:', !!FFmpegWASM, 'keys:', FFmpegWASM ? Object.keys(FFmpegWASM) : 'null');
    console.log('[audio_worker] FFmpegUtil loaded:', !!FFmpegUtil, 'keys:', FFmpegUtil ? Object.keys(FFmpegUtil) : 'null');
} catch (e) {
    initError = `Failed to load FFmpeg scripts: ${e.message}. Ensure files exist in web/js/vendor/.`;
    console.error(initError);
}

// Message handlers
self.onmessage = async (event) => {
    const { type, id, payload } = event.data;

    try {
        switch (type) {
            case 'init':
                await handleInit(id);
                break;

            case 'load-source':
                await handleLoadSource(id, payload);
                break;

            case 'probe':
                await handleProbe(id, payload);
                break;

            case 'waveform':
                await handleWaveform(id, payload);
                break;

            case 'render-preview':
                await handleRenderPreview(id, payload);
                break;

            case 'render-full':
                await handleRenderFull(id, payload);
                break;

            case 'cancel':
                handleCancel(id, payload);
                break;

            case 'cleanup':
                await handleCleanup(id, payload);
                break;

            default:
                sendError(id, `Unknown message type: ${type}`);
        }
    } catch (error) {
        sendError(id, error.message);
    }
};

// Initialize FFmpeg WASM
async function handleInit(requestId) {
    try {
        // Check if scripts loaded successfully
        if (initError) {
            sendError(requestId, initError);
            return;
        }

        if (!FFmpegWASM || !FFmpegUtil) {
            sendError(requestId, 'FFmpeg scripts not loaded. Please check network connectivity or local vendor files.');
            return;
        }

        postMessage({ type: 'log', message: 'Initializing FFmpeg WASM...' });

        const { FFmpeg } = FFmpegWASM;
        const { toBlobURL } = FFmpegUtil;

        ffmpeg = new FFmpeg();

        // Set up logging
        ffmpeg.on('log', ({ message }) => {
            postMessage({ type: 'log', message: `FFmpeg: ${message}` });
        });

        // Set up progress tracking
        ffmpeg.on('progress', ({ progress, time }) => {
            if (currentJobId) {
                postMessage({
                    type: 'render-progress',
                    requestId: currentJobId,
                    payload: {
                        jobId: currentJobId,
                        progress: Math.max(0, Math.min(1, progress)),
                        stage: determineStage(progress),
                    },
                });
            }
        });

        // Load FFmpeg core - using single-threaded version to avoid SharedArrayBuffer requirement
        // files are served locally from js/vendor/
        await ffmpeg.load({
            coreURL: await toBlobURL('vendor/ffmpeg-core.js', 'text/javascript'),
            wasmURL: await toBlobURL('vendor/ffmpeg-core.wasm', 'application/wasm'),
        });

        postMessage({
            type: 'init-ok',
            requestId,
            payload: { ready: true },
        });
    } catch (error) {
        sendError(requestId, `FFmpeg initialization failed: ${error.message}`);
    }
}

// Load audio source into WASM FS
async function handleLoadSource(requestId, payload) {
    const { fileId, filename, bytes } = payload;

    try {
        // Write file to WASM filesystem
        const uint8Array = new Uint8Array(bytes);
        await ffmpeg.writeFile(fileId, uint8Array);

        postMessage({
            type: 'load-ok',
            requestId,
            payload: { fileId },
        });
    } catch (error) {
        sendError(requestId, `Failed to load source: ${error.message}`);
    }
}

// Probe audio file for metadata
async function handleProbe(requestId, payload) {
    const { fileId } = payload;

    try {
        // Use ffprobe to get metadata
        const output = await ffmpeg.exec([
            '-i', fileId,
            '-hide_banner',
            '-loglevel', 'info',
        ]);

        // Parse duration, sample rate, channels from ffmpeg log output
        // Note: This is a simplified version. In production, use ffprobe JSON output.
        const metadata = {
            fileId,
            duration: 180000, // Placeholder: 3 minutes in ms
            sampleRate: 44100,
            channels: 2,
            format: fileId.split('.').pop(),
        };

        postMessage({
            type: 'probe-ok',
            requestId,
            payload: metadata,
        });
    } catch (error) {
        sendError(requestId, `Failed to probe file: ${error.message}`);
    }
}

// Generate waveform data
async function handleWaveform(requestId, payload) {
    const { fileId, targetSamples } = payload;

    try {
        // Extract audio samples using FFmpeg
        await ffmpeg.exec([
            '-i', fileId,
            '-ac', '1', // Mono
            '-ar', '8000', // Downsample for waveform
            '-f', 's16le', // 16-bit PCM
            '-acodec', 'pcm_s16le',
            'waveform.raw',
        ]);

        // Read raw PCM data
        const data = await ffmpeg.readFile('waveform.raw');
        const samples = new Int16Array(data.buffer);

        // Downsample to target count
        const step = Math.floor(samples.length / targetSamples);
        const downsampled = new Float32Array(targetSamples);

        for (let i = 0; i < targetSamples; i++) {
            const idx = i * step;
            downsampled[i] = samples[idx] / 32768.0; // Normalize to -1..1
        }

        // Cleanup
        await ffmpeg.deleteFile('waveform.raw');

        postMessage({
            type: 'waveform-ok',
            requestId,
            payload: downsampled,
        });
    } catch (error) {
        sendError(requestId, `Failed to generate waveform: ${error.message}`);
    }
}

// Render preview (30-second segment)
async function handleRenderPreview(requestId, payload) {
    const { fileId, filterChain, startAt } = payload;

    try {
        currentJobId = requestId;

        const args = [
            '-i', fileId,
            '-ss', `${startAt || 0}`, // Start time
        ];

        if (filterChain && filterChain !== 'anull') {
            args.push('-af', filterChain);
        }

        args.push('-c:a', 'libmp3lame', '-b:a', '192k', 'preview.mp3');

        await ffmpeg.exec(args);

        // Read output
        const output = await ffmpeg.readFile('preview.mp3'); // Uint8Array

        // Send ArrayBuffer so Dart can view it without double copies
        postMessage({
            type: 'render-preview-ok',
            requestId,
            payload: { outputBuffer: output.buffer },
        }, [output.buffer]); // Transfer buffer

        // Cleanup
        await ffmpeg.deleteFile('preview.mp3');
        currentJobId = null;
    } catch (error) {
        currentJobId = null;
        sendError(requestId, `Preview render failed: ${error.message}`);
    }
}

// Render full export
async function handleRenderFull(requestId, payload) {
    const { fileId, filterChain, format, bitrateKbps, compressionLevel } = payload;

    try {
        currentJobId = requestId;

        const outputFile = `output.${format}`;
        const args = ['-i', fileId];

        if (filterChain && filterChain !== 'anull') {
            args.push('-af', filterChain);
        }

        // Add codec args based on format
        switch (format) {
            case 'mp3':
                args.push('-c:a', 'libmp3lame', '-b:a', `${bitrateKbps || 320}k`);
                break;
            case 'wav':
                args.push('-c:a', 'pcm_s16le');
                break;
            case 'flac':
                args.push('-c:a', 'flac', '-compression_level', `${compressionLevel || 8}`);
                break;
            default:
                throw new Error(`Unsupported format: ${format}`);
        }

        args.push(outputFile);

        await ffmpeg.exec(args);

        // Read output
        const output = await ffmpeg.readFile(outputFile); // Uint8Array

        postMessage({
            type: 'render-full-ok',
            requestId,
            payload: { outputBuffer: output.buffer, format },
        }, [output.buffer]); // Transfer buffer

        // Cleanup
        await ffmpeg.deleteFile(outputFile);
        currentJobId = null;
    } catch (error) {
        currentJobId = null;
        sendError(requestId, `Full render failed: ${error.message}`);
    }
}

// Cancel current operation
function handleCancel(requestId, payload) {
    const { jobId } = payload;

    if (currentJobId === jobId) {
        // Note: ffmpeg.wasm doesn't support true cancellation.
        // We'll just stop tracking progress.
        currentJobId = null;
        postMessage({
            type: 'cancel-ok',
            requestId,
            payload: { jobId },
        });
    }
}

// Cleanup files from WASM FS
async function handleCleanup(requestId, payload) {
    const { fileId } = payload;

    try {
        if (fileId) {
            await ffmpeg.deleteFile(fileId);
        }

        postMessage({
            type: 'cleanup-ok',
            requestId,
            payload: {},
        });
    } catch (error) {
        // Ignore errors on cleanup
        postMessage({
            type: 'cleanup-ok',
            requestId,
            payload: {},
        });
    }
}

// Helper: Send error response
function sendError(requestId, message) {
    postMessage({
        type: 'error',
        requestId,
        payload: { error: message },
    });
}

// Helper: Determine render stage from progress
function determineStage(progress) {
    if (progress < 0.1) return 'decoding';
    if (progress < 0.9) return 'filtering';
    return 'encoding';
}

// Log ready state
postMessage({ type: 'log', message: 'Audio worker ready' });
