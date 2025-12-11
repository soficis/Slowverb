// Minimal test worker
console.log('[test_worker] Worker loaded successfully!');

self.addEventListener('message', (event) => {
    console.log('[test_worker] Received message:', event.data);
    self.postMessage({ type: 'test-ok', message: 'Worker is operational' });
});

self.addEventListener('error', (event) => {
    console.error('[test_worker] Error:', event);
    self.postMessage({ type: 'error', message: event.message });
});

console.log('[test_worker] Worker initialized');
