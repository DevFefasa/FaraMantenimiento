/* Fara Mantenimiento PWA — cache solo assets estáticos; nunca HTML autenticado ni POST. */
const CACHE = 'fara-static-v1';
const STATIC_EXT = /\.(?:css|js|woff2?|ttf|otf|eot|png|jpe?g|gif|svg|webp|ico|webmanifest)$/i;

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(caches.open(CACHE));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  const path = url.pathname;
  const isStatic =
    path.startsWith('/assets/') ||
    path.startsWith('/css/') ||
    path.startsWith('/js/') ||
    path.startsWith('/icons/') ||
    path.startsWith('/lib/') ||
    STATIC_EXT.test(path);

  if (!isStatic) return;

  event.respondWith(
    caches.open(CACHE).then(async (cache) => {
      const cached = await cache.match(req);
      if (cached) return cached;
      try {
        const res = await fetch(req);
        if (res && res.ok && res.type === 'basic') {
          cache.put(req, res.clone());
        }
        return res;
      } catch (err) {
        return cached || Promise.reject(err);
      }
    })
  );
});
