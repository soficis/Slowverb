const CACHE_NAME = "slowverb-v1";
const WASM_FILES = ["/js/ffmpeg-core.js", "/js/ffmpeg-core.wasm"];
const ASSETS_TO_CACHE = [
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
  "/icons/Icon-192.png",
  "/icons/Icon-512.png",
  ...WASM_FILES,
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(async (cache) => {
      await cache.addAll(ASSETS_TO_CACHE);
    })
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;

      return fetch(event.request).then((response) => {
        if (
          event.request.method === "GET" &&
          !event.request.url.includes("/api/")
        ) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        }
        return response;
      });
    })
  );
});
