/**
 * Slowverb Web - Audio Worker (ES Module Version)
 * 
 * Web Worker that handles all FFmpeg WASM audio processing.
 * Runs in a separate thread to keep the UI responsive during renders.
 */

// Import FFmpeg from CDN (ES Module)
import { FFmpeg } from 'https://unpkg.com/@ffmpeg/ffmpeg@0.12.10/dist/esm/index.js';
import { toBlobURL } from 'https://unpkg.com/@ffmpeg/util@0.12.1/dist/esm/index.js';

console.log('[audio_worker] ======== MODULE WORKER STARTED ========');
console.log('[audio_worker] FFmpeg imported successfully');

let ffmpeg = null;
let currentJobId = null;

// Message handlers
self.onmessage = async (event) => {
    const { type, id, payload } = event.data;
    console.log(`[audio_worker] Received message: ${type}`);

    try {
        switch (type) {
            case 'init':
                await handleInit(id);
                break;
            case 'cleanup':
                postMessage({ type: 'cleanup-ok', requestId: id, payload: {} });
                break;
            default:
                // Placeholder for full implementation
                if (type === 'load-source' || type === 'render-full') {
                    // We can restore full logic later, first verify init works
                    sendError(id, 'Feature pending full module migration');
                } else {
                    sendError(id, `Unknown message type: ${type}`);
                }
        }
    } catch (error) {
        sendError(id, error.message);
    }
};

// Initialize FFmpeg WASM
async function handleInit(requestId) {
    console.log('[audio_worker] handleInit called');
    try {
        postMessage({ type: 'log', payload: { message: 'Initializing FFmpeg WASM (Module)...' } });

        ffmpeg = new FFmpeg();

        ffmpeg.on('log', ({ message }) => {
            console.log(`[FFmpeg-Core] ${message}`);
            postMessage({ type: 'log', payload: { message: `FFmpeg: ${message}` } });
        });

        // Load FFmpeg core from CDN
        console.log('[audio_worker] Loading FFmpeg core...');

        await ffmpeg.load({
            coreURL: await toBlobURL('https://unpkg.com/@ffmpeg/core@0.12.6/dist/esm/ffmpeg-core.js', 'text/javascript'),
            wasmURL: await toBlobURL('https://unpkg.com/@ffmpeg/core@0.12.6/dist/esm/ffmpeg-core.wasm', 'application/wasm'),
        });

        console.log('[audio_worker] FFmpeg core loaded!');
        postMessage({ type: 'log', payload: { message: 'FFmpeg initialized successfully!' } });

        postMessage({
            type: 'init-ok',
            requestId,
            payload: { ready: true },
        });
    } catch (error) {
        console.error('[audio_worker] Init failed:', error);
        sendError(requestId, `FFmpeg initialization failed: ${error.message}`);
    }
}

function sendError(requestId, message) {
    postMessage({
        type: 'error',
        requestId,
        payload: { error: message },
    });
}

console.log('[audio_worker] Worker ready');
postMessage({ type: 'log', payload: { message: 'Audio worker ready (Module)' } });
