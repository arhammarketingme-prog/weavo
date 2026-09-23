# Weavo — Architecture (सद्यस्थिती)

> टीप: सुरुवातीला Node.js/React/स्वतंत्र PostgreSQL सर्व्हर असा प्लॅन विचारात घेतला होता, पण
> प्रत्यक्ष अंमलबजावणीसाठी **Supabase + plain HTML/JS** हा मार्ग निवडला — कारण तो खर्च, वेळ आणि
> देखभाल या तिन्ही बाबतीत जास्त व्यवहार्य ठरला. खालचं वर्णन प्रत्यक्ष वापरात असलेल्या आर्किटेक्चरचं आहे.

## Tech Stack (प्रत्यक्षात वापरलेलं)

| भाग | निवड | कारण |
|---|---|---|
| Frontend | एकच `index.html` (plain HTML/CSS/JS) | कोणताही build step नाही, GitHub Pages वर थेट होस्ट |
| Backend | Supabase (managed Postgres + Auth + Realtime + Storage + Edge Functions) | स्वतःचा सर्व्हर सांभाळायची गरज नाही, मोफत tier पुरेसा |
| Realtime | Supabase Realtime (Postgres logical replication वर आधारित) | चॅट, typing, calls-signaling, live updates |
| Calls | WebRTC मेश (peer-to-peer) + मोफत STUN/TURN (Open Relay Project) | सर्व्हरवर मीडिया कधीच साठत नाही |
| Auth | Supabase Auth — email/password + Passkey (WebAuthn) | पासवर्डशिवायही लॉगिन शक्य |
| Storage | Supabase Storage (एकच `chat-media` bucket) | फोटो/व्हॉइस/व्हिडिओ/अवतार सगळं इथेच |
| Hosting | GitHub Pages | मोफत, कोणताही सर्व्हर सांभाळायचा नाही |

## डेटाबेस — मुख्य tables
`profiles`, `conversations`, `conversation_members`, `messages`, `message_reactions`,
`starred_messages`, `poll_votes`, `business_profiles`, `blocked_users`, `push_subscriptions`,
`platform_admins`, `banned_users`, `stories`, `story_views`, `short_videos`, `video_likes`,
`video_comments`, `reports`. संपूर्ण, अद्ययावत व्याख्या `supabase/schema.sql` मध्ये आहे — तोच
या प्रोजेक्टचा खरा "स्रोत-सत्य" (source of truth) आहे, हा दस्तऐवज नाही.

## सुरक्षा तत्वं
- Row Level Security (RLS) प्रत्येक table वर — कोण काय वाचू/लिहू शकतं हे database-level वर ठरतं
- Recursion टाळण्यासाठी SECURITY DEFINER helper functions (`is_conversation_member`, इ.)
- Database-level rate-limiting आणि content-length मर्यादा (trigger्स द्वारे)
- Ban/Block database-level trigger्स द्वारे लागू (फक्त UI-tयर नाही)

## फीचर्सची पूर्ण, अद्ययावत यादी
`README.md` मध्ये आहे — तिथेच प्रत्येक फीचरची मर्यादा आणि जाणीवपूर्वक न बांधलेल्या गोष्टींची यादीही आहे.
