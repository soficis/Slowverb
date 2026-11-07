// Separate cache names for better versioning control
const STATIC_CACHE_NAME = "slowverb-static-v12";
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
  "/vendor/jszip.min.js",
  "/js/slowverb_bridge.js",
  "/js/ts/core.js",
  "/js/ts/worker.js",
  "/js/phase_limiter_worker.js",
  "/icons/Icon-192.png",
  "/icons/Icon-512.png",
];

// Served cache-first (see the fetch handler for why app code is not).
const CACHE_FIRST_PATHS = [
  /\/assets\/assets\/google_fonts\//,
  /\/irs\//,
  /\/vendor\//,
  /\/icons\//,
  /\/assets\/shaders\//,
];

function isCacheable(request, response) {
  return (
    response &&
    response.status === 200 &&
    response.type === "basic" &&
    !request.url.includes("/api/") &&
    !request.url.includes("vercel")
  );
}

async function fromCacheFirst(request) {
  const cached = await caches.match(request);
  if (cached) return cached;
  try {
    const response = await fetch(request);
    if (isCacheable(request, response)) {
      const clone = response.clone();
      caches.open(STATIC_CACHE_NAME).then((cache) => cache.put(request, clone));
    }
    return response;
  } catch {
    return new Response("", { status: 504 });
  }
}

async function fromNetworkFirst(request) {
  try {
    const response = await fetch(request);
    if (isCacheable(request, response)) {
      const clone = response.clone();
      caches.open(STATIC_CACHE_NAME).then((cache) => cache.put(request, clone));
    }
    return response;
  } catch {
    const cached = await caches.match(request);
    return cached || new Response("", { status: 504 });
  }
}

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
  const requestUrl = event.request.url;

  // Never intercept analytics/insights scripts. Ad blockers often block them.
  if (
    requestUrl.includes("cdn.vercel-analytics.com") ||
    requestUrl.includes("/_vercel/insights/")
  ) {
    event.respondWith(
      fetch(event.request).catch(() => new Response("", { status: 204 }))
    );
    return;
  }

  // Stale-while-revalidate for WASM files (important for initial load)
  if (WASM_FILES.some(path => requestUrl.includes(path))) {
    event.respondWith(
      caches.open(WASM_CACHE_NAME).then(async (cache) => {
        const cached = await cache.match(event.request);
        const fetchPromise = fetch(event.request)
          .then((response) => {
            if (response && response.status === 200) {
              cache.put(event.request, response.clone());
            }
            return response;
          })
          .catch(() => null);
        // Return cached version immediately if available, otherwise wait for network
        return cached || fetchPromise || new Response("", { status: 504 });
      })
    );
    return;
  }

  if (event.request.method !== "GET") return;

  // App code (HTML, main.dart.js, bridge/worker JS, manifests) is network-first so a deploy
  // is picked up on the next load without a manual cache-version bump, and old and new files
  // never mix. The cache is only an offline fallback. Large files that change only with their
  // name or rarely (fonts, IRs, vendored libs, icons) stay cache-first.
  const path = new URL(requestUrl).pathname;
  const cacheFirst = CACHE_FIRST_PATHS.some((re) => re.test(path));
  event.respondWith(cacheFirst ? fromCacheFirst(event.request) : fromNetworkFirst(event.request));
});
