// Weavo — साधा service worker: app shell (HTML/CSS/JS) कॅश करतो, फक्त ऑफलाइन असतानाच वापरण्यासाठी.
// चॅट डेटा (मेसेजेस) नेहमी live Supabase वरून येतो — तो इथे कॅश केलेला नाही (ताजाच हवा).
//
// महत्त्वाचं: "network-first" रणनीती — नेट असेल तेव्हा नेहमी ताजी फाईल आणतो आणि cache अपडेट करतो;
// नेट नसेल तेव्हाच जुनी (cached) आवृत्ती वापरतो. यामुळे मोबाईलवर/installed app मध्ये जुना कोड
// अडकून राहत नाही — नवीन बदल पुढच्या वेळी app उघडल्यावर लगेच दिसतात.

const CACHE_NAME = 'weavo-shell-v2'; // बदल केल्यावर version वाढवा — जुनी cache आपोआप साफ होते
const SHELL_FILES = ['./index.html', './config.js', './manifest.json'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(SHELL_FILES))
  );
  self.skipWaiting(); // नवीन service worker लगेच सक्रिय करतो, जुना संपेपर्यंत थांबत नाही
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((names) =>
      Promise.all(names.filter((n) => n !== CACHE_NAME).map((n) => caches.delete(n)))
    )
  );
  self.clients.claim(); // आधीच उघडलेल्या tabs/app लाही लगेच नवीन service worker लागू होतो
});

self.addEventListener('fetch', (event) => {
  // फक्त same-origin app-shell फाईल्ससाठी; Supabase API calls नेहमी network वरून (इथे हात लावत नाही)
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  event.respondWith(
    fetch(event.request)
      .then((freshResponse) => {
        // नेट चालू आहे — ताजी फाईल मिळाली, cache अपडेट करून तीच परत देतो
        const clone = freshResponse.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        return freshResponse;
      })
      .catch(() => caches.match(event.request)) // नेट नाही — फक्त तेव्हाच जुनी cached आवृत्ती
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
