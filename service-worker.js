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

// ---------- PUSH NOTIFICATIONS ----------
self.addEventListener('push', (event) => {
  let data = { title: 'Weavo', body: 'नवीन मेसेज' };
  try { data = event.data.json(); } catch (e) { /* ignore */ }
  event.waitUntil(
    self.registration.showNotification(data.title || 'Weavo', {
      body: data.body || 'नवीन मेसेज',
      icon: 'icon-192.png',
      badge: 'icon-192.png',
      data: { conversationId: data.conversationId },
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window' }).then((clientsArr) => {
      if (clientsArr.length) return clientsArr[0].focus();
      return self.clients.openWindow('./index.html');
    })
  );
});
