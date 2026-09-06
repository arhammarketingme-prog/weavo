# Global Communication Platform — Architecture Document (Phase 1 / MVP)

> स्कोप: संपूर्ण ४५-सेक्शन spec मधून Phase 1 (core communication engine) साठी ठोस, अंमलात आणण्यायोग्य आर्किटेक्चर. पुढचे टप्पे (Creator economy, Ads, Mini Apps, इ.) याच पायावर मॉड्युलर पद्धतीने जोडता येतील.

---

## 1. Tech Stack (Zero/Low-cost, Open-source-first)

| Layer | निवड | कारण |
|---|---|---|
| Frontend | React + TypeScript + Vite | जलद बिल्ड, PWA सहज |
| Styling | Tailwind CSS | हलकं, जलद, कस्टम डिझाईन सोपं |
| Backend | Node.js + Fastify (किंवा NestJS) | हलकं, TypeScript-friendly |
| Realtime | WebSocket (ws / Socket.IO) | चॅट + presence |
| Calls | WebRTC (P2P), coturn (self-host TURN) | सर्व्हर कॉस्ट कमी |
| Database | PostgreSQL | Open-source, relational, JSON support |
| Cache/Presence | Redis | online status, rate limiting, pub/sub |
| Object storage | S3-compatible (Cloudflare R2 / MinIO self-host) | Media, फक्त आवश्यक तितकंच |
| Auth | JWT + refresh tokens, Argon2 password hashing | Open-source, standard |
| PWA | Workbox (service worker) | Offline shell, installable |
| Hosting (MVP) | Free tier (Render/Fly.io/Cloudflare Pages) | $0 सुरुवात, नंतर scale |

---

## 2. High-level System Diagram (मजकूर स्वरूपात)

```
[Client - PWA/React]
   |  WebSocket (chat/presence)      |  HTTPS REST (auth, profile, media meta)
   v                                 v
[API Gateway / Fastify Server]  <--> [Redis: presence, rate-limit, pub/sub]
   |
   v
[PostgreSQL: users, messages-metadata, groups, communities]
   |
   v
[Object Storage: media blobs - encrypted where applicable]

[Client A] <--WebRTC (P2P)--> [Client B]      (calls, direct)
        \--> [TURN relay: coturn] --/          (जेव्हा P2P शक्य नाही तेव्हाच)
```

**महत्त्वाचं तत्व:** मेसेज मजकूर शक्यतो client-side encrypt/decrypt होतो; सर्व्हर फक्त routing + अल्पकालीन storage करतो, कायमस्वरूपी नाही (delivered झाल्यावर media/queue साफ).

---

## 3. Database Schema (Core तक्ते)

```sql
-- Users
users (
  id UUID PK,
  username VARCHAR UNIQUE NOT NULL,
  display_name VARCHAR,
  phone_hash VARCHAR NULL,      -- फोन नंबर हॅश करून ठेवणे, plaintext नाही
  email_hash VARCHAR NULL,
  password_hash VARCHAR,
  public_key TEXT,              -- E2EE साठी device public key
  avatar_url TEXT NULL,
  created_at TIMESTAMPTZ,
  account_type VARCHAR DEFAULT 'personal' -- personal/creator/business/developer
)

-- Devices / Sessions
devices (
  id UUID PK, user_id FK, device_name, last_active,
  public_key TEXT, created_at
)

-- Conversations (1:1 आणि group दोन्हीसाठी सामाईक)
conversations (
  id UUID PK, type VARCHAR, -- 'direct' | 'group' | 'channel'
  created_at TIMESTAMPTZ
)

conversation_members (
  conversation_id FK, user_id FK, role VARCHAR, -- member/admin/owner
  joined_at, muted BOOLEAN, last_read_message_id
)

-- Messages: metadata सर्व्हरवर, content शक्यतो encrypted blob
messages (
  id UUID PK, conversation_id FK, sender_id FK,
  ciphertext TEXT,              -- E2EE असल्यास encrypted content
  media_ref TEXT NULL,          -- object storage key, plaintext नाही स्टोअर
  reply_to UUID NULL,
  created_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NULL,  -- disappearing messages
  edited BOOLEAN, deleted BOOLEAN
)

-- Communities / Channels / Groups metadata
communities (
  id UUID PK, type VARCHAR, -- 'group'|'channel'|'space'|'topic'
  name, description, visibility, owner_id FK, created_at
)

-- Reports / Moderation
reports (
  id UUID PK, reporter_id FK, target_type, target_id,
  category VARCHAR, status VARCHAR, created_at
)
```

> टीप: फोन नंबर/ईमेल plaintext ऐवजी hash स्वरूपात ठेवणे — privacy-first तत्वानुसार. Message content शक्यतो सर्व्हरवर decrypt होत नाही.

---

## 4. API आराखडा (मुख्य endpoints — REST + WS)

```
POST   /auth/register
POST   /auth/login
POST   /auth/refresh
GET    /users/:username
PATCH  /users/me

POST   /conversations
GET    /conversations
GET    /conversations/:id/messages
POST   /conversations/:id/messages       (metadata; content WS द्वारे किंवा encrypted)

WS     /realtime                          -- chat, typing, presence, calls-signaling

POST   /communities
GET    /communities/:id
POST   /communities/:id/join

POST   /reports
```

Calls साठी signaling हे याच WebSocket channel वरून (offer/answer/ICE candidates), प्रत्यक्ष audio/video P2P किंवा TURN द्वारे — सर्व्हरवरून कधीच पास होत नाही.

---

## 5. Security बेसलाईन (Phase 1 पासूनच)

- HTTPS सक्तीचं, secure + httpOnly cookies किंवा short-lived JWT
- Rate limiting (Redis-based) — नवीन खात्यांवर कडक मर्यादा
- Input validation (zod/joi) प्रत्येक endpoint वर
- Row-level access checks (conversation membership तपासल्याशिवाय मेसेज दिसणार नाही)
- Secrets फक्त backend env मध्ये, frontend मध्ये कधीच नाही
- Audit log — admin actions साठी

---

## 6. Phase 1 Build Order (प्रत्यक्ष अंमलबजावणी क्रम)

1. Auth (register/login/JWT) + user profile
2. 1:1 messaging (WebSocket + DB persistence + delivery status)
3. Group messaging (conversation_members वापरून)
4. Communities/Channels (मूलभूत CRUD + membership)
5. Voice/video calling (WebRTC signaling)
6. Privacy settings (last seen, read receipts, disappearing messages)
7. Block/Report/Admin basics
8. PWA shell + installability
9. Landing page + branding

प्रत्येक टप्पा स्वतंत्रपणे deploy करण्यायोग्य ठेवायचा (feature flags वापरून), जेणेकरून एक भाग तुटला तरी बाकी काम चालू राहील.

---

## पुढचा प्रश्न

हा foundation ठरला की पुढे मी थेट **कोड स्कॅफोल्ड** (repo structure + auth + 1:1 chat, प्रत्यक्ष चालणारा) बनवायला सुरुवात करू शकतो — तेच सर्वात जास्त मूल्य देणारं पुढचं पाऊल आहे.
