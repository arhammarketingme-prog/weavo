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
- Online/Last-seen (direct चॅटमध्ये हेडरखाली दिसतं — दोघांनीही privacy मध्ये लपवलं नसेल तरच, ⚙ सेटिंग्जमधून लपवता येतं)
- **Disappearing Messages** — प्रत्येक चॅटमध्ये ⏱ बटणाने "बंद / 24 तास / 7 दिवस" निवडता येतं; वेळ संपल्यावर मेसेज (आणि त्यातला फोटो/फाईल) कायमचा डिलीट होतो — "zero/near-zero storage" तत्वानुसार
- **Communities/Channels** — broadcast-style: फक्त owner/admin पोस्ट करू शकतात, बाकीचे फक्त वाचतात; Public channels "🔍 Discover Channels" मधून कोणालाही शोधून join करता येतात
- **Voice/Video Calling (WebRTC)** — Direct चॅटमध्ये 📞/🎥 बटणाने कॉल करता येतो; media थेट peer-to-peer जातो (सर्व्हरवर कॉल रेकॉर्ड/साठवला जात नाही), फक्त सिग्नलिंग (कोण कोणाला कॉल करतंय) Supabase Realtime वरून होतं
- **Message Edit** — स्वतःच्या टेक्स्ट मेसेजवर ✏️ ने बदल करता येतो, "(edited)" टॅग दिसतो
- **Read Receipts (✓✓)** — Direct चॅटमध्ये समोरच्याने वाचल्यावर टिक निळी होते, live अपडेट होते
- **Reactions** — कोणत्याही मेसेजवर 😊 दाबून 👍❤️😂😮😢🙏 यापैकी react करता येतं — Group/Channel सगळीकडे, Channel मध्ये subscribers (जे पोस्ट करू शकत नाहीत) त्यांनाही react करता येतं
- Row Level Security (RLS) — database-level सुरक्षा
- Report table (safety basics)

## Calling बद्दल महत्त्वाची टीप

- सध्या फक्त **STUN server** (मोफत, Google चा) वापरलाय, **TURN server नाही**. बहुतांश नेटवर्कवर (home wifi, mobile data) कॉल चालेल, पण काही strict/corporate नेटवर्कवर जोडला जाणार नाही — त्यासाठी स्वतःचा TURN सर्व्हर (coturn) लागतो, जो पुढच्या टप्प्यात जोडता येईल.
- कॉल सुरू असताना दुसरा चॅट उघडता येणार नाही (आधी कॉल संपवावा लागेल) — सध्याच्या सिंगल-सिग्नलिंग-चॅनल आर्किटेक्चरची मर्यादा.
- Group/Channel कॉल्स अजून नाहीत — फक्त 1:1.

## Storage आर्किटेक्चर बद्दल प्रामाणिक टीप

पूर्णपणे "zero storage" शक्य नाही — मेसेज दुसऱ्या व्यक्तीपर्यंत पोचवायला, ऑफलाइन डिलिव्हरीसाठी, इतिहास दाखवायला Supabase च्या Postgres/Storage मध्ये काहीतरी ठेवावंच लागतं (WhatsApp/Signal सुद्धा तात्पुरतं तरी साठवतातच). आपण जे केलंय ते "जवळपास-शून्य, वेळेनुसार आपोआप नष्ट होणारं" storage:
- Disappearing messages चालू असतील तर मेसेज+मीडिया ठराविक वेळेनंतर कायमचे डिलीट होतात
- Calling चा media मुळात सर्व्हरवर येतच नाही (peer-to-peer) — फक्त सिग्नलिंग संदेश जातात, तेही साठवले जात नाहीत (real-time broadcast, कायमस्वरूपी DB मध्ये नाही)
- हे दर तासाला आपोआप चालतं (Supabase च्या pg_cron extension द्वारे)

**जर आपोआप cleanup चालू झालं नाही तर** (schema.sql/fix-all.sql run केल्यावर "pg_cron सेटअप करता आलं नाही" असा notice SQL Editor मध्ये दिसला तर):
1. Supabase Dashboard → Database → Extensions → "pg_cron" शोधून Enable कर
2. मग SQL Editor मध्ये फक्त हे एकदा चालव:
   ```sql
   select cron.schedule('cleanup-expired-messages', '0 * * * *', 'select cleanup_expired_messages();');
   ```

## पुढचे टप्पे

1. TURN server जोडणं (call reliability सुधारण्यासाठी)
2. Group/Channel calls
3. Channel मध्ये threaded comments (सध्या फक्त reactions आहेत, comments नाहीत)
4. Read receipts group/channel साठी (सध्या फक्त direct चॅटमध्ये)
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
