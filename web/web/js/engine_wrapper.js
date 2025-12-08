/**
 * Slowverb Web - Engine Wrapper
 * 
 * JavaScript bridge for Dart ↔ Web Worker communication.
 * Exposes functions that Dart can call via JS interop.
 */

let worker = null;
let messageHandlers = new Map();
let logHandler = null;

/**
 * Initialize the audio worker
 */
function initWorker() {
    if (worker) {
        console.warn('Worker already initialized');
        return;
    }

    worker = new Worker('js/audio_worker.js');

    worker.onmessage = (event) => {
        const { type, requestId, payload } = event.data;

        // Handle logs separately
        if (type === 'log') {
            if (logHandler) {
                logHandler(payload?.message || '');
            }
            console.log(payload?.message || '');
            return;
        }

        // Find handler for this request
        const handler = messageHandlers.get(requestId);
        if (handler) {
            handler({ type, payload });

            // Cleanup one-shot handlers (not progress updates)
            if (!type.includes('progress')) {
                messageHandlers.delete(requestId);
            }
        }
    };

    worker.onerror = (error) => {
        console.error('Worker error:', error.message || error);
        console.error('Worker error details:', error.filename, 'line:', error.lineno);
    };

    console.log('Audio worker initialized');
}

/**
 * Post message to worker and register response handler
 */
function postMessage(type, payload, callback) {
    if (!worker) {
        throw new Error('Worker not initialized');
    }

    const requestId = generateId();

    messageHandlers.set(requestId, callback);

    worker.postMessage({
        type,
        id: requestId,
        payload,
    });

    return requestId;
}

/**
 * Set log message handler
 */
function setLogHandler(callback) {
    logHandler = callback;
}

/**
 * Terminate worker
 */
function terminateWorker() {
    if (worker) {
        worker.terminate();
        worker = null;
        messageHandlers.clear();
    }
}

/**
 * Generate unique request ID
 */
function generateId() {
    return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

// Expose to global scope for Dart interop
window.SlowverbEngine = {
    initWorker,
    postMessage,
    setLogHandler,
    terminateWorker,
};

console.log('Engine wrapper loaded');
