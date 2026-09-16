# Weavo — Premium UI Rebuild

This package is a visual/UX rebuild of Weavo v30. Existing HTML IDs, JavaScript hooks, Supabase schema/functions, PWA manifest and service worker are preserved so the existing application logic can continue to operate.

## UI direction
- Premium mobile-first messaging experience
- Clean teal Weavo identity
- Refined chat bubbles and composer
- Better conversation list hierarchy
- Responsive desktop/mobile layouts
- Safe-area support for modern phones
- Light/dark visual system
- Subtle motion, depth and micro-interactions
- Existing features remain reachable through the existing controls

## GitHub Pages
Upload the contents of this folder to the repository root. Do not upload the ZIP as the site root.

## Real WebAuthn / Passkey

This build uses Supabase Auth's experimental Passkey API (`@supabase/supabase-js@2.105.0`).
The client opts into `auth.experimental.passkey` and the UI now calls the real
`signInWithPasskey()` and `registerPasskey()` methods rather than a fake/demo flow.

Before testing on GitHub Pages, in Supabase Dashboard → Authentication → Passkeys use:
- Relying Party Display Name: `Weavo`
- Relying Party ID: `arhammarketingme-prog.github.io`
- Relying Party Origins: `https://arhammarketingme-prog.github.io`

A passkey can only be registered for an authenticated, non-anonymous user. The
login button performs the real WebAuthn ceremony and creates a Supabase session.

Mobile-number password login remains separate from passkey login. SMS OTP is not
implemented in this zero-cost build; enabling Supabase phone confirmation/OTP would
require an SMS provider.
