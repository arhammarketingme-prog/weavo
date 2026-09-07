# Weavo — Phase 1 MVP (Supabase + plain HTML)

Stack: **Supabase** (Postgres + Auth + Realtime, backend server लागत नाही) + **plain HTML/JS** (build step नाही) + **GitHub** (code hosting).

`index.html` आता याच फोल्डरच्या root मध्ये आहे (आधीच्या version मध्ये `frontend/` सबफोल्डर मध्ये होता — त्यामुळे काही static hosts वर index.html ऐवजी हा README दिसत होता. आता ठीक आहे).

## Setup (3 स्टेप)

### 1. Supabase प्रोजेक्ट तयार करा
- [supabase.com](https://supabase.com) वर मोफत अकाउंट/प्रोजेक्ट तयार करा
- Dashboard मध्ये **SQL Editor** उघडा, `supabase/schema.sql` मधलं संपूर्ण content पेस्ट करून **Run** करा
- **Project Settings → API** मध्ये जाऊन `Project URL` आणि `anon public key` कॉपी करा

### 2. Frontend कॉन्फिगर करा
`config.js` उघडून तिथे तुमचा URL आणि anon key टाका:
```js
const SUPABASE_URL = "https://xxxx.supabase.co";
const SUPABASE_ANON_KEY = "eyJ...";
```

### 3. Deploy / चालवा
- **Static hosting वर (Netlify/Vercel/GitHub Pages इ.):** या फोल्डरच्या सगळ्या फाईल्स (`index.html`, `config.js`) upload करा — कोणतंही build command लागत नाही, root directory म्हणजेच हा फोल्डर सेट करा.
- **Local टेस्टसाठी:** `index.html` browser मध्ये उघडा, किंवा `python3 -m http.server` वापरा.

Supabase Auth ईमेल confirmation मागू शकतं — Dashboard → Authentication → Settings मध्ये "Confirm email" बंद करता येतं टेस्टिंगसाठी.

## सध्या काय आहे

- Auth (Supabase signup/login — email+password, username profile)
- 1:1 direct conversation + Group messaging
- Real-time messaging (Supabase Realtime)
- Photo/File sharing (Supabase Storage, 10MB पर्यंत)
- Reply to message, Delete own message
- Group admin: owner सभासद जोडू/काढू शकतो
- PWA installable (manifest + service worker + icons)
- **Profile photo/avatar अपलोड** (टॉप-लेफ्ट avatar वर क्लिक करून बदलता येतो)
- **Typing indicator** ("टाइप करत आहे..." दुसऱ्याला दिसतं)
- **Online/Last-seen** (direct चॅटमध्ये हेडरखाली दिसतं — दोघांनीही privacy मध्ये लपवलं नसेल तरच, ⚙ सेटिंग्जमधून लपवता येतं)
- Row Level Security (RLS) — database-level सुरक्षा
- Report table (safety basics)

## पुढचे टप्पे

1. Communities/Channels CRUD
2. WebRTC voice/video calling
3. Message edit (सध्या फक्त delete आहे)
4. Read receipts (✓✓)
5. Disappearing messages

## GitHub वर टाकायचं कसं

```bash
git init
git add .
git commit -m "Phase 1: Supabase auth + realtime 1:1 chat"
git branch -M main
git remote add origin https://github.com/<तुमचं-username>/<repo-name>.git
git push -u origin main
```

पूर्ण architecture तपशील `architecture.md` मध्ये आहे.
