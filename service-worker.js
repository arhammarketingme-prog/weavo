// Weavo — साधा service worker: फक्त app shell (HTML/CSS/JS) कॅश करतो, ऑफलाइन उघडण्यासाठी.
// चॅट डेटा (मेसेजेस) नेहमी live Supabase वरून येतो — तो इथे कॅश केलेला नाही (ताजाच हवा).

const CACHE_NAME = 'weavo-shell-v1';
const SHELL_FILES = ['./index.html', './config.js', './manifest.json'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(SHELL_FILES))
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((names) =>
      Promise.all(names.filter((n) => n !== CACHE_NAME).map((n) => caches.delete(n)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  // फक्त same-origin app-shell फाईल्ससाठी cache-first; Supabase API calls नेहमी network वरून
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  event.respondWith(
    caches.match(event.request).then((cached) => cached || fetch(event.request))
  );
});
