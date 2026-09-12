# Weavo — Phase 1 MVP (Supabase + plain HTML)

Stack: **Supabase** (Postgres + Auth + Realtime, backend server लागत नाही) + **plain HTML/JS** (build step नाही) + **GitHub** (code hosting).

`index.html` आता याच फोल्डरच्या root मध्ये आहे (आधीच्या version मध्ये `frontend/` सबफोल्डर मध्ये होता — त्यामुळे काही static hosts वर index.html ऐवजी हा README दिसत होता. आता ठीक आहे).

## 🧹 SQL Files स्वच्छ केले (नवीन)

आधी `schema.sql` मध्ये २० टप्प्यांचा (rounds) इतिहास साठत गेला होता (मोठा, वाचायला अवघड). आता तो **पूर्णपणे नीटनेटका आणि फक्त अंतिम स्थिती दाखवणारा** केला आहे — प्रत्येक table/policy एकाच ठिकाणी, वरून खाली सुसंगत क्रमाने. `fix-all.sql` आता `schema.sql` सारखाच आहे (वेगळा ठेवलाय फक्त सवयीसाठी — दोन्हीपैकी कुठलाही चालेल). जुनी `fix-recursion.sql` काढून टाकली — तिच्यातलं सगळं आता schema.sql मध्येच आहे.

**प्रामाणिक टीप:** मी हा file प्रत्यक्ष Postgres वर चालवून टेस्ट करू शकत नाही (माझ्याकडे प्रवेश नाही) — प्रत्येक तुकडा आधीच वेगळा, तुझ्याकडून टेस्ट होऊन काम करणारा होता, मी फक्त एकत्र नीट रचला आहे. तरीही: **हा file run केल्यावर एकदा पूर्ण app टेस्ट कर** (login, chat, group, channel सगळं) याची खात्री करायला.

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
- **Voice/Video Calling (WebRTC)** — Direct आणि Group चॅटमध्ये 📞/🎥 बटणाने कॉल करता येतो (multi-person mesh — प्रत्येकजण प्रत्येकाशी थेट जोडला जातो); media थेट peer-to-peer जातो (सर्व्हरवर कॉल रेकॉर्ड/साठवला जात नाही), फक्त सिग्नलिंग Supabase Realtime वरून होतं
- **Message Edit** — स्वतःच्या टेक्स्ट मेसेजवर ✏️ ने बदल करता येतो, "(edited)" टॅग दिसतो
- **Read Receipts** — Direct चॅटमध्ये ✓✓ टिक निळी होते; Group/Channel मध्ये "Read by N" दाखवतो — सगळीकडे live अपडेट
- **Reactions** — कोणत्याही मेसेजवर 😊 दाबून 👍❤️😂😮😢🙏 यापैकी react करता येतं — Group/Channel सगळीकडे, Channel मध्ये subscribers (जे पोस्ट करू शकत नाहीत) त्यांनाही react करता येतं
- **Channel Comments** — Channel मध्ये subscribers स्वतः नवीन पोस्ट करू शकत नाहीत, पण एखाद्या पोस्टवरच्या ↩ बटणाने comment (reply) करू शकतात
- **Account Types + Business Directory** — ⚙ Settings मध्ये Personal/Creator/Business निवडता येतं; Creator साठी Bio, Business साठी नाव/category/location/phone/website/तास/वर्णन भरता येतं; "🏢 Discover Businesses" मधून सगळे businesses शोधून थेट owner शी chat सुरू करता येतो
- **Mobile-responsive UI** — फोनवर WhatsApp-स्टाईल list ↔ chat toggle (← Back बटण), टच-फ्रेंडली
- **Voice Messages** — 🎤 दाबून रेकॉर्ड, timer सकट, पाठवल्यावर player म्हणून ऐकता येतं
- **Sidebar polish** — प्रत्येक चॅटसाठी avatar (फोटो किंवा रंगीत आद्याक्षर), unread indicator dot
- **Mute** — प्रत्येक चॅटमध्ये 🔔/🔕 बटणाने mute/unmute (मेसेज येत राहतील, फक्त unread dot दिसणार नाही)
- **Block + Report** — Direct चॅटमध्ये ⋮ मेनूतून व्यक्तीला block करता येतो (त्यांचे मेसेज दिसेनासे होतात, नवीन मेसेज पाठवता येत नाही) किंवा report करता येतो
- **Pin / Archive** — 📌 ने चॅट वर पिन करता येतो (यादीत सगळ्यात वर दिसतो), 🗄 ने archive (यादीतून लपतो, खालच्या "Archived" विभागातून परत मिळतो)
- **In-chat Search** — 🔍 ने सध्याच्या चॅटमध्ये (अलीकडचे २०० मेसेज) मजकूर शोधता येतो
- **Forward** — कोणत्याही मेसेजवर ↪ दाबून दुसऱ्या चॅटमध्ये तोच मेसेज पाठवता येतो; ज्या channel मध्ये पोस्ट करण्याचा अधिकार नाही (फक्त subscriber असाल) ती यादीत दिसणारच नाहीत, आणि अपयश आलं तर आता स्पष्ट error दिसतो (आधी silently "forward झालं" असं चुकीचं दाखवायचं — हा bug सापडून लगेच ठीक केला)
- **Push Notifications** (ऐच्छिक सेटअप — खाली सूचना) — app बंद असतानाही नवीन मेसेजचं notification
- **Light/Dark Theme** — ⚙ मधून बदलता येतं, प्रत्येक डिव्हाइसवर स्वतंत्र लक्षात राहतं
- **Read Receipts privacy** — last-seen पेक्षा वेगळी सेटिंग, ✓✓ स्वतंत्रपणे लपवता येतं (mutual, WhatsApp सारखं)
- **खरा Reply-quote preview** — Reply केलेला मेसेज आता प्रत्यक्ष कोणत्या मजकुरावर/फोटोवर उत्तर आहे ते दाखवतो
- **Starred Messages** — कोणत्याही मेसेजवर ⭐, सगळे starred मेसेज एका ठिकाणी ("⭐ Starred Messages")
- **Delete for me / Delete for everyone** — दोन्ही पर्याय; "for me" फक्त तुमच्या डिव्हाइसवर लपतो (sync होत नाही), "for everyone" सगळ्यांसाठी कायमचं जातं
- **Group/Channel Avatar** — owner group-info मधून फोटो अपलोड करू शकतो
- **Business Profile Photo** — Settings मधून फोटो अपलोड, Discover Businesses मध्ये दिसतो
- **Location Inline Preview** — आता फक्त लिंक नाही, चॅटमध्येच छोटा नकाशा दिसतो (OpenStreetMap embed, मोफत)
- **Global Search** — सगळ्या चॅट्स, लोक, आणि मेसेज मजकूर — एकाच वेळी शोध (sidebar वरती)
- **Emoji Picker** — मेसेज टाइप करतानाच emoji निवडता येतात (😊 बटण)
- **Location Sharing** — 📍 ने सध्याचं location पाठवता येतं (नकाशाची लिंक — OpenStreetMap, कोणताही API key लागत नाही)
- **Contact Sharing** — 👤 ने दुसऱ्या Weavo user चं contact card पाठवता येतं
- **Polls** — 📊 ने प्रश्न + पर्याय टाकून poll तयार करता येतो, सगळ्यांना live results दिसतात
- **"App Install करा" बटण** — sidebar मध्ये आपोआप दिसतं (browser support असेल तर), custom install prompt
- Row Level Security (RLS) — database-level सुरक्षा, या राऊंडमध्ये आणखी घट्ट केलेली (खाली बघा)

## महत्त्वाची मर्यादा — Advertising/Monetization

मूळ spec मध्ये advertising campaigns, payments, creator monetization याचा उल्लेख आहे — **हे मुद्दाम बांधलेलं नाही.** कारणं:
- खरा payment processing (Stripe वगैरे) लागतो — हा आर्थिक/कायदेशीर निर्णयाचा भाग आहे, कोडने ठरवण्याचा नाही
- Ad campaign targeting, analytics, billing यासाठी वेगळी, गंभीर backend infrastructure लागते
- Business Directory इथे बांधलाय तो **मोफत listing** आहे — पैसे भरून जाहिरात करण्याची सोय नाही

हे टप्प्याटप्प्याने पुढे बांधता येईल, पण त्याआधी व्यवसाय मॉडेल, payment provider, आणि कायदेशीर सल्ला निश्चित करणं आवश्यक आहे.

## Calling बद्दल महत्त्वाची टीप

- **STUN + TURN दोन्ही** आता जोडलेले आहेत (TURN: मोफत Open Relay Project). बहुतांश नेटवर्कवर, तसंच काही strict/corporate नेटवर्कवरही कॉल जोडला जाईल. हे सार्वजनिक demo TURN credentials आहेत — मोठ्या प्रमाणावर (शेकडो/हजारो users) वापरासाठी विश्वासार्ह नाही, तेव्हा स्वतःचा coturn किंवा paid service (Twilio/Metered) घ्यावा.
- कॉल सुरू असताना दुसरा चॅट उघडता येणार नाही (आधी कॉल संपवावा लागेल).
- Group calls मध्ये प्रत्येक सभासद इतर प्रत्येकाशी थेट जोडला जातो (mesh) — मोठ्या ग्रुप्ससाठी (8-10+ लोक) हे जड होऊ शकतं; खऱ्या मोठ्या ग्रुप कॉल्ससाठी SFU (media server) लागतो, जो अजून नाही.
- Channel calls अजून नाहीत — फक्त direct आणि group.
- **Lag/विलंब जाणवत असेल तर:** व्हिडिओ आता कमी resolution (640x480) आणि bitrate-capped (400kbps) पाठवला जातो, त्यामुळे कमकुवत नेटवर्कवर आधीपेक्षा smooth असायला हवं. तरीही lag जाणवत असेल — विशेषतः दोघे वेगवेगळ्या शहरात/नेटवर्कवर असाल तर — हे बहुतेक कारण मोफत TURN relay मुळे आहे (traffic थेट न जाता एका दूरच्या सर्व्हरमार्गे जातो). **दोन डिव्हाइस एकाच WiFi वर टेस्ट करून बघा** — तेव्हा थेट (P2P) जोडणी होते आणि विलंब जवळपास शून्य असायला हवा. रोजच्या (production) वापरासाठी विश्वासार्ह, कमी-विलंब कॉलिंगला paid TURN service (उदा. Twilio, Metered.ca चा paid plan) किंवा जवळच्या region मध्ये स्वतःचा coturn सर्व्हर लागेल — मोफत public TURN फक्त टेस्टिंगसाठी योग्य आहे.

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

1. Channel calls (सध्या फक्त direct + group)
2. मोठ्या group calls साठी SFU/media server (सध्याचा mesh ८-१० लोकांपर्यंत ठीक आहे, त्यापेक्षा मोठ्यासाठी जड होईल)
3. Comments ला स्वतःचं threaded view (सध्या comments messages listमध्येच "↩ उत्तर" टॅगसह दिसतात, वेगळा thread view नाही)
4. Column-level privacy (last_seen_at/hide_last_seen सध्या row-level RLS ने संरक्षित आहे — म्हणजे लॉगिन केलेला कोणीही profiles वाचू शकतो, पण त्यातला exact last-seen timestamp थेट query करून बघता येऊ शकतो; app स्वतः तो दाखवताना privacy पाळते, पण database-level column-lock अजून नाही — अजून घट्ट करता येईल)
5. Poll: "एकापेक्षा जास्त पर्याय निवडता येणं" (multi-select poll) आणि "results लपवून ठेवणं" यासारखे advanced पर्याय
6. Advertising/Payments (वर स्पष्ट केल्याप्रमाणे — व्यवसाय मॉडेल + payment provider ठरल्याशिवाय सुरू करणार नाही)

## Block बद्दल एक प्रामाणिक मर्यादा

Block केल्यावर त्या व्यक्तीचे मेसेज **तुमच्या स्क्रीनवर दिसणं बंद होतं आणि नवीन मेसेज पाठवता येत नाहीत** (app-level तपासणी). पण हे database-level हार्ड सुरक्षा-भिंत नाही — technically हुशार वापरकर्ता browser मधून थेट काहीतरी छेडछाड करून पाठवू शकतो, कारण दोन विशिष्ट व्यक्तींमधलं "कोणी कोणाला block केलं" हे नातं conversations tableवर उपलब्ध नसल्यामुळे RLS मध्ये पूर्णपणे अडवणं शक्य नव्हतं. रोजच्या वापरासाठी हे पुरेसं आहे, पण गंभीर गैरवापर रोखण्यासाठी अजून मजबूत करता येईल.

## 🔐 Security Hardening (या राऊंडमध्ये सापडलेल्या आणि बंद केलेल्या त्रुटी)

`fix-all.sql` मध्ये या 4 गोष्टी नव्याने आहेत — जुन्या version मध्ये या त्रुटी होत्या:

1. **सभासद जोडणं आता निर्बंधित** — आधी कोणीही, कोणालाही, कोणत्याही group/chat मध्ये जोडू शकत होता. आता फक्त group/channel चा owner किंवा admin दुसऱ्याला जोडू शकतो; स्वतःला फक्त public channel मध्येच किंवा स्वतः निर्माता असेल तरच जोडता येतं.
2. **Profiles फक्त लॉगिन केलेल्यांना दिसतील** — आधी अनोळखी व्यक्ती (लॉगिन न करताही, फक्त anon key वापरून) सगळ्यांची profiles वाचू शकत होती.
3. **Message rate-limiting** — 10 सेकंदात 15 पेक्षा जास्त मेसेज पाठवता येणार नाहीत, database-level वर (बायपास करता येत नाही, आधीचा rate-limiter फक्त पहिल्या Node.js version मध्ये होता, Supabase version मध्ये तो हरवला होता).
4. **मेसेज लांबीची मर्यादा** — एका मेसेजमध्ये जास्तीत जास्त 5000 अक्षरं.

**हे लगेच लागू कर:** `fix-all.sql` परत Supabase SQL Editor मध्ये run कर + नवीन `index.html` upload कर (group-info panel मध्ये "add member" आता फक्त owner/admin ला दिसेल).

## 🔔 Push Notifications Setup (ऐच्छिक — इतर fixes पेक्षा जास्त तांत्रिक)

हे फीचर वापरायचं नसेल तर काहीही करायची गरज नाही — बाकी सगळं app न बदलता तसंच चालेल. वापरायचं असेल तर या पायऱ्या:

### 1. VAPID keys तयार करा
```bash
npx web-push generate-vapid-keys
```
यातून दोन keys मिळतील — Public Key आणि Private Key.

### 2. Supabase CLI इंस्टॉल करून प्रोजेक्ट जोडा
```bash
npm install -g supabase
supabase login
supabase link --project-ref <तुमचा-project-ref>   # URL मधून मिळेल: xxxx.supabase.co चा xxxx भाग
```

### 3. Secrets सेट करा (Private key कधीही frontend मध्ये टाकायची नाही)
```bash
supabase secrets set VAPID_PUBLIC_KEY=<तुमची public key>
supabase secrets set VAPID_PRIVATE_KEY=<तुमची private key>
```
(`SUPABASE_URL` आणि `SUPABASE_SERVICE_ROLE_KEY` Supabase आपोआप उपलब्ध करून देतं, वेगळं सेट करायची गरज नाही.)

### 4. Edge Function डिप्लॉय करा
```bash
supabase functions deploy send-push --no-verify-jwt
```

### 5. Database Webhook तयार करा
Supabase Dashboard → **Database → Webhooks → Create a new webhook**:
- Table: `messages`
- Events: `Insert`
- Type: `Supabase Edge Function`
- Function: `send-push`

### 6. Public key frontend मध्ये टाका
`config.js` मध्ये:
```js
const VAPID_PUBLIC_KEY = "तुमची-public-key-इथे";
```
आणि झिप परत GitHub वर upload कर.

### 7. वापरकर्त्यांनी काय करायचं
प्रत्येकाने Settings (⚙) उघडून **"🔔 Push Notifications चालू करा"** दाबून browser permission द्यायची. मग app बंद असतानाही नवीन मेसेजचं notification येईल.

**मर्यादा:** iPhone/iPad वर हे फक्त तेव्हाच चालतं जेव्हा site "Add to Home Screen" केलेली असते (iOS 16.4+); नुसत्या Safari टॅबमध्ये चालत नाही — हे Apple ची मर्यादा आहे, आपल्या कोडची नाही.

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
