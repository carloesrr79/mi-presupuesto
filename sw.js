const CACHE = 'presupuesto-v3';
const SHELL = ['./', './index.html', './manifest.json', './icon-192.png', './icon-512.png',
  'https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js'];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  // App propia: red primero (para recibir actualizaciones), caché si no hay conexión
  if (url.origin === location.origin) {
    e.respondWith(fetch(e.request).then(r => { const cp = r.clone(); caches.open(CACHE).then(c => c.put(e.request, cp)); return r; })
      .catch(() => caches.match(e.request).then(r => r || caches.match('./index.html'))));
    return;
  }
  // Librerías del CDN: caché primero
  if (url.hostname === 'cdn.jsdelivr.net') {
    e.respondWith(caches.match(e.request).then(r => r || fetch(e.request).then(res => {
      const cp = res.clone(); caches.open(CACHE).then(c => c.put(e.request, cp)); return res; })));
  }
});
