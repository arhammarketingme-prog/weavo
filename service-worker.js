// Weavo — Service Worker (Version 3)
// बदल केल्यावर version वाढवले आहे (v3) — जुनी cache आपोआप साफ होईल आणि नवीन Google लॉगिन लगेच दिसेल.

const CACHE_NAME = 'weavo-shell-v3'; 
const SHELL_FILES = ['./index.html', './config.js', './manifest.json'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(SHELL_FILES))
  );
  self.skipWaiting(); // नवीन service worker लगेच सक्रिय करतो
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((names) =>
      Promise.all(names.filter((n) => n !== CACHE_NAME).map((n) => caches.delete(n)))
    )
  );
  self.clients.claim(); // चालू पानांवर नवीन बदल तात्काळ लागू करतो
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  event.respondWith(
    fetch(event.request)
      .then((freshResponse) => {
        // ताजी फाईल मिळताच cache अपडेट करणे
        const clone = freshResponse.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        return freshResponse;
      })
      .catch(() => caches.match(event.request)) // नेट नसेल तरच cached फाईल
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
