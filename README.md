# Weavo — One World. One Communication Layer.

Stack: **Supabase** (Postgres + Auth + Realtime + Storage, backend server लागत नाही) + **plain HTML/JS** (build step नाही, फक्त एक `index.html`) + **GitHub Pages** (hosting).

## 🎨 UI (Premium Rebuild)
- Teal Weavo brand identity, Inter typography, glass/glow accents
- Landing/marketing page आता login च्याही आधी दिसते (नवीन — खाली बघा)
- Refined chat bubbles, composer, conversation list
- Responsive mobile/desktop, safe-area support
- Light/dark visual system, subtle motion
- सगळी जुनी फीचर्स तशीच पोचण्यायोग्य आहेत — फक्त दिसणं बदललंय, काम करण्याची पद्धत नाही

## 🏠 नवीन: Landing Page
आता website उघडल्यावर थेट login screen ऐवजी एक marketing/hero page दिसते — headline, features grid, आणि "Get Started"/"Login" बटणं. आधीच login असलेला वापरकर्ता आपोआप थेट app मध्ये जातो (landing दिसत नाही); logout केल्यावर परत थेट login form दिसतो (landing नाही, कारण त्यांना आधीच माहिती आहे).

## Setup (नवीन प्रोजेक्टसाठी, पहिल्यांदाच)

### 1. Supabase प्रोजेक्ट तयार करा
- [supabase.com](https://supabase.com) वर मोफत अकाउंट/प्रोजेक्ट तयार करा
- Dashboard मध्ये **SQL Editor** उघडा, `supabase/schema.sql` मधलं संपूर्ण content पेस्ट करून **Run** करा (हे कितीही वेळा सुरक्षितपणे चालवता येतं)
- **Project Settings → API** मध्ये जाऊन `Project URL` आणि `anon public key` कॉपी करा

### 2. Frontend कॉन्फिगर करा
`config.js` मध्ये तुमचा URL आणि anon key टाका.

### 3. GitHub Pages वर टाका
या फोल्डरच्या सगळ्या फाईल्स repo च्या **root** मध्ये टाका (झिप स्वतः root म्हणून टाकू नका — आतल्या फाईल्स extract करून टाका).

## 🔐 Real WebAuthn / Passkey

हे build Supabase Auth च्या experimental Passkey API चा वापर करतं (`@supabase/supabase-js@2.105.0`). खरे `signInWithPasskey()` आणि `registerPasskey()` methods वापरले आहेत — demo/fake नाही.

Passkey टेस्ट करण्याआधी, Supabase Dashboard → **Authentication → Passkeys** मध्ये:
- Relying Party Display Name: `Weavo`
- Relying Party ID: तुमचं GitHub Pages domain (उदा. `yourname.github.io`)
- Relying Party Origins: `https://yourname.github.io`

Passkey फक्त आधीच लॉगिन असलेल्या (non-anonymous) user साठी register करता येतो. Mobile-number tab सध्या फक्त UI आहे — SMS OTP जोडलेलं नाही (त्यासाठी paid SMS provider लागतो, जो या zero-cost build मध्ये मुद्दाम टाळलाय).

## 🛡 Admin Panel — पहिला Admin कसा बनवायचा

कोणीही स्वतःला admin बनवू शकत नाही. पहिला admin manually बनवा — `supabase/make-me-admin.sql` उघडून तुमचा email टाकून Supabase SQL Editor मध्ये run करा. मग sidebar मध्ये "🛡 Admin Panel" दिसेल (Stats, User ban/unban, Reports).

## काय काय आहे (थोडक्यात)

Auth (email/password + Passkey), 1:1 + Group + Channel messaging, Voice/Video calling (mesh WebRTC), फोटो/व्हॉइस/लोकेशन/contact/poll मेसेज, Disappearing messages, Reply/Edit/Delete/Star/Forward, Read receipts, Reactions, Mute/Pin/Archive/Block (DB-level), Business Directory + direct UPI payment info, Stories (24hr), Short Videos (Reels), unified Discover hub, QR profile, Push notifications (ऐच्छिक सेटअप), Admin Panel, PWA installable.

## जाणीवपूर्वक न बांधलेलं
- **Advertising/Payments processing** — direct company-to-customer UPI info आहे, पण खरं payment gateway (Stripe/Razorpay) मुद्दाम जोडलेलं नाही
- **Mini-Apps sandbox / Developer Platform** — बाहेरचे developers हवे असतील तरच गरज; आत्ता नाही
- SMS OTP (paid SMS provider लागतो)

## महत्त्वाच्या मर्यादा
- Group calls mesh पद्धतीने आहेत — ८-१० लोकांपर्यंत ठीक, त्यापेक्षा मोठ्यासाठी media server (SFU) लागेल
- last_seen privacy row-level आहे, column-level lock नाही
- Block direct चॅटमध्ये DB-hard आहे; group/channel मध्ये app-level
