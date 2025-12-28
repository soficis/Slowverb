// Separate cache names for better versioning control
const STATIC_CACHE_NAME = "slowverb-static-v10";
const WASM_CACHE_NAME = "slowverb-wasm-v2";

// WASM files get separate cache for easier maintenance
const WASM_FILES = [
  "/js/ffmpeg-core.js",
  "/js/ffmpeg-core.wasm",
  "/js/phaselimiter.js",
  "/js/phaselimiter.wasm",
  "/js/phaselimiter_pro.js",
  "/js/phaselimiter_pro.wasm",
  "/js/phaselimiter_pro.data",
];

// Static assets (app code, UI assets)
const STATIC_ASSETS = [
  "/",
  "/index.html",
  "/main.dart.js",
  "/flutter.js",
  "/flutter_bootstrap.js",
  "/manifest.json",
  "/favicon.png",
  "/js/slowverb_bridge.js",
  "/js/ts/core.js",
  "/js/ts/worker.js",
  "/js/phase_limiter_worker.js",
  "/icons/Icon-192.png",
  "/icons/Icon-512.png",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    Promise.all([
      caches.open(STATIC_CACHE_NAME).then((cache) => cache.addAll(STATIC_ASSETS)),
      caches.open(WASM_CACHE_NAME).then((cache) => cache.addAll(WASM_FILES)),
    ]).then(() => {
      // Log cache sizes for debugging
      return Promise.all([
        caches.open(STATIC_CACHE_NAME).then(cache => cache.keys()),
        caches.open(WASM_CACHE_NAME).then(cache => cache.keys()),
      ]).then(([staticKeys, wasmKeys]) => {
        console.log(`[SW] Cached ${staticKeys.length} static assets, ${wasmKeys.length} WASM files`);
      });
    })
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== STATIC_CACHE_NAME && key !== WASM_CACHE_NAME)
          .map((key) => {
            console.log(`[SW] Deleting old cache: ${key}`);
            return caches.delete(key);
          })
      )
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  // Skip non-http/https requests
  if (!event.request.url.startsWith('http')) return;

  // Stale-while-revalidate for WASM files (important for initial load)
  if (WASM_FILES.some(path => event.request.url.includes(path))) {
    event.respondWith(
      caches.open(WASM_CACHE_NAME).then(async (cache) => {
        const cached = await cache.match(event.request);
        const fetchPromise = fetch(event.request).then((response) => {
          if (response && response.status === 200) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
        // Return cached version immediately if available, otherwise wait for network
        return cached || fetchPromise;
      })
    );
    return;
  }

  // Cache-first for static assets
  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;

      return fetch(event.request).then((response) => {
        // Cache only valid responses
        if (
          !response ||
          response.status !== 200 ||
          response.type !== "basic" ||
          event.request.method !== "GET" ||
          event.request.url.includes("/api/") ||
          event.request.url.includes("google-analytics") ||
          event.request.url.includes("vercel") // Avoid caching analytics
        ) {
          return response;
        }

        const clone = response.clone();
        caches.open(STATIC_CACHE_NAME).then((cache) => cache.put(event.request, clone));
        return response;
      });
    }).catch(() => {
      // Fallback to network on match error
      return fetch(event.request);
    })
  );
});
