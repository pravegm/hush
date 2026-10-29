# Hush 1.0: App Store Connect requirements check

*Launch lead, Wed 28 Oct 2026 (iOS 27.1, iPhone Duo on sale since 23 Oct). Read live from Apple's pages today; each
rule names its source. The founder asked: "make sure we have all screenshots and the header and all as per
requirement". This file says what Apple requires or accepts for an **iPhone-only** app, where our file is, and its
status. Screenshot plan and re-shoot: `docs/appstore/screenshots.md`.*

## 1. What Apple requires (sources)

### Screenshots ([Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications))
- "You must include at least one screenshot and can upload up to 10 screenshots per device size", `.jpeg`, `.jpg` or
  `.png`. "Images can't include alpha channels or transparencies."
- **Required:** at least one screenshot for **iPhone with Dynamic Island (medium display)**: 1179 × 2556 or
  **1206 × 2622** portrait (2556 × 1179 / 2622 × 1206 landscape).
- **Conditionally required:** iPhone with Face ID (large display) 1284 × 2778 / 1242 × 2688, *only* if Dynamic Island
  (large) screenshots aren't provided. We provide Dynamic Island (large), so it is not needed.
- **Dynamic Island (large display)** (the 6.9"/6.7" class): 1260 × 2736, 1290 × 2796 or **1320 × 2868**. Optional,
  but it is what the big phones show (else scaled Face ID large).
- **6.5" (Face ID large) is no longer required** when the Dynamic Island large set exists (above). Smaller classes
  (Face ID medium, Home Button) are scaled from the larger ones automatically.
- **iPhone Duo (yes, a fold class exists):** **inner display 2007 × 2853** (2853 × 2007 landscape) and **outer display
  1398 × 2034** (2034 × 1398). "Starting in April 2027, screenshots will be required for any app using the iOS 27.1 SDK
  or later." "When you submit iPhone Duo screenshots … your App Store product page will display a badge to let people
  know your app is optimized for iPhone Duo." Optional for Hush 1.0, but we ship them (the badge).
- Upload support for Duo assets: Apple DTS in Sep 2026 said it "will be available later this year"
  ([forum 845505](https://developer.apple.com/forums/thread/845505)); later developer posts report the iPhone Duo tab is
  live in the web UI ([forum 847849](https://developer.apple.com/forums/thread/847849)). Apple's news post says Duo
  assets can be submitted "alongside a new app version, or in your Asset Library … You can also use the App Store
  Connect API" ([news, 5 Oct 2026](https://developer.apple.com/news/?id=kkphp5qo)). Our tool (`asc.swift`) uses the
  asset library's `IPHONE_DUO` group when the API offers it and otherwise tells the founder to drag them in by hand.

### App previews ([App preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications))
- Optional. "up to three app previews per supported device size and language"; **15–30 s**; ≤ 500 MB; H.264
  (`.mov`, `.m4v`, `.mp4`, 10–12 Mbps) or ProRes 422 HQ; ≤ 30 fps; stereo AAC 256 kbps 44.1/48 kHz.
- Accepted iPhone resolutions: **886 × 1920** portrait for iPhone Duo, Dynamic Island large/medium and Face ID
  large/medium; 1080 × 1920 for Home Button (large). "App previews always appear before screenshots."
- Hush 1.0 ships **no app preview** (DECISIONS.md; a filmed-hands video is a 1.0.1 option). Not a blocker.

### Product page header and search results (iOS 27 creative assets) ([Creative assets specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications), [Manage your App Store assets](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-your-app-store-assets), [Asset best practices](https://developer.apple.com/app-store/asset-best-practices/))
- "Creative assets are optional and separate from your app's screenshots". They show "across the App Store in iOS 27".
- **Product page header:** image **3840 × 1646** (21:9, JPEG or PNG) or the universal **5244 × 2950** PNG (16:9);
  video 21:9 3840 × 1646, 5–30 s, 30/60 fps. **Search results:** image 3:2 from 1920 × 1280 to **3840 × 2560**, or the
  universal PNG; video 3:2, 5–30 s. "Images can't include alpha channels or transparencies."
- Guidance: one clear idea, focal point centred (crops differ by device), short text, no pricing, URLs, unverifiable
  claims, other platforms' logos or Apple recognitions. Without a search asset, search shows previews/screenshots.
- This is the "header" the founder means. We ship both images (`store-placements`).

### App information ([App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information), [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information))
- **Name** 2–30 characters. **Subtitle** ≤ 30. **Privacy Policy URL** required for iOS. **Age rating** required.
  Category (primary/secondary), content rights, SKU, primary language. Bundle ID can't change after a build upload.
- **Promotional text** ≤ 170 (optional, editable any time). **Description** ≤ 4,000, plain text, required.
  **Keywords** ≤ 100 bytes, required; each > 2 characters; no app/company names repeated, no other apps' names.
  **Support URL** required, must "lead to actual contact information". **Marketing URL** optional. **Copyright**
  required ("2026 Name"; © added). **What's New** not shown for 1.0.
- **App Review information:** contact (name, email, phone with + country code) **required**; **notes ≤ 4,000 bytes**;
  sign-in only if the app needs one.
- **App icon:** the 1024 × 1024 App Store icon comes from the build's asset catalog (opaque, square; the system masks
  the corners) ([HIG: App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)).
- Also on the version/app pages (not character fields): App Privacy answers ("Data Not Collected"), price and
  availability, export-compliance answer for the build, EU Digital Services Act trader status, Game Center enabled on
  the version with its achievements and leaderboards.

## 2. Checklist: requirement → our file → status

| Requirement | Our file / where | Status |
|---|---|---|
| iPhone Dynamic Island (medium) screenshots, required: 1–10 PNG, 1206 × 2622, no alpha | store run `store-61/store/P01…P10` | ✅ 10 × 1206 × 2622, RGB, no alpha (§3) |
| iPhone Dynamic Island (large) 1320 × 2868 | `store-69/store/P01…P10` | ✅ 10 × 1320 × 2868 (§3) |
| Face ID large 6.5" | not needed (Dynamic Island large provided) | ✅ n/a |
| iPhone Duo inner 2007 × 2853 (optional until Apr 2027; earns the Duo badge) | `store-duo/duo-screens/store/D01…D10` | ✅ 10 × 2007 × 2853 (§3); upload by hand if the API has no Duo group |
| iPhone Duo outer 1398 × 2034 | none as a set; the outer intro is D02 | ✅ optional, not needed |
| Screenshot content true for the build (R15), no prices/badges (2.3.3, 2.3.7) | every frame viewed (§3) | ✅ |
| App previews (optional) | none in 1.0 | ✅ optional |
| Product page header 3840 × 1646 (optional) | `store-placements/header-3840x1646.png` | ✅ (§3) |
| Search results art 3840 × 2560 (optional) | `store-placements/search-3840x2560.png` | ✅ (§3) |
| App icon 1024 × 1024, opaque, square | `Hush/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` (the only icon file; Contents.json single-size universal) | ✅ 1024 × 1024, RGB 8-bit, no alpha, square full-bleed art (viewed) |
| Name ≤ 30 | `metadata.md` §1 → `asc-metadata.json` | ✅ 26 "Hush: Don't Wake the Mimic" |
| Subtitle ≤ 30 | `metadata.md` §2 | ✅ (count in `node tools/appstore/build-metadata.js`) |
| Promotional text ≤ 170 | `metadata.md` §3 | ✅ |
| Description ≤ 4,000, plain text, R15-true | `metadata.md` §4 (en-GB, en-US) | ✅ |
| Keywords ≤ 100 bytes | `metadata.md` §5 | ✅ |
| Support URL with contact info | https://pravegm.github.io/hush/support.html (`docs/support.html`, live 200) | ⚠️ page live; a **support contact email is a founder decision** (not yet on the page) |
| Marketing URL (optional) | https://pravegm.github.io/hush/ (`docs/index.html`, live 200) | ✅ |
| Privacy Policy URL | https://pravegm.github.io/hush/privacy.html (live 200) | ✅ |
| App Privacy: Data Not Collected | `docs/appstore/privacy.md` (answers) | ⚠️ founder answers the questionnaire in App Store Connect |
| Age rating questionnaire | `asc-metadata.json` `ageRating` (9+: cartoon violence + horror themes infrequent, contests infrequent) | ⚠️ founder confirms; `asc.yml push` sends it |
| Category | `asc-metadata.json` Games › Casual, Adventure; secondary Entertainment | ✅ |
| Copyright | read from Squish at run time (`--inherit-from com.pravegm.squish`) | ⚠️ founder confirms the line |
| Content rights | `DOES_NOT_USE_THIRD_PARTY_CONTENT` | ✅ |
| Price £1.99, availability (no CHN, VNM) | `asc-metadata.json` `price`, `availability` | ⚠️ founder confirms in Pricing |
| App Review contact (name, email, + phone) | inherited from Squish at run time | ⚠️ founder confirms |
| App Review notes ≤ 4,000 bytes, how to play on Duo and any iPhone/Simulator | `review-notes.md` (block) | ✅ < 4,000 bytes, R15 |
| Sign-in for review | none needed (no accounts) | ✅ n/a |
| Game Center: 12 achievements + 2 leaderboards with images | `achievements.md`, CI `badges/` (BADGES_REQUIRED) | ✅ via `asc.yml` |
| Export compliance, EU DSA trader status | App Store Connect pages | ⚠️ founder answers |
| Build attached, release type MANUAL | `asc.yml build=<n>`, `release.type` | ⚠️ founder, after the final TestFlight build |

## 3. The store run checked

**Final run: [40809079356](https://github.com/pravegm/hush/actions/runs/40809079356)** (commit f82dadf on main: the
build-11 app code, 337ba0d + tests; 29 Oct 2026 03:15 UTC). `DEFAULT_STORE_RUN` and `DEFAULT_PLACEMENTS_RUN` in
`.github/workflows/asc.yml` point at it. MANIFESTs: 6.9" ok 10, 6.3" ok 10, Duo ok 10 (flagged 0, missing 0);
placements ok 2, problems 0. Every file read back here (PNG header: size, colour type, tRNS) and looked at:

| Set (artifact) | Files | Pixels | Format |
|---|---|---|---|
| iPhone 6.9" (`store-69/store/`) | P01-hero-open, P02-rules, P03-loot, P04-freeze, P05-bank, P06-chomp, P07-chain, P08-relic, P09-codex, P10-results | 1320 × 2868 each | PNG, 8-bit RGB, no alpha |
| iPhone 6.3" (`store-61/store/`) | the same ten | 1206 × 2622 each | PNG, 8-bit RGB, no alpha |
| iPhone Duo inner (`store-duo/duo-screens/store/`) | D01-hero-open, D02-play, D03-loot, D04-freeze, D05-bank, D06-chomp, D07-chain, D08-relic, D09-codex, D10-results | 2007 × 2853 each | PNG, 8-bit RGB, no alpha |
| Header (`store-placements/`) | header-3840x1646.png | 3840 × 1646 | PNG, 8-bit RGB, no alpha |
| Search results (`store-placements/`) | search-3840x2560.png | 3840 × 2560 | PNG, 8-bit RGB, no alpha |

What the eye check confirmed: R15 copy only ("Open the phone. Slowly.", "Phone shut? Press Play.", "Close the phone to
bank", the lever's "In a chest, slide the lever up slowly to open it."); D02 is the real outer-display intro (wordmark,
mimic, "Steal the mimic's gold while it sleeps", the three rules, Play); no "lid", "laptop", "Hold still", lesson card or
"Close the phone to start"; nothing sideways (the Duo runs are turned upright from their logged k); no debug overlay;
the Dynamic Island covers only the status bar; the bite frames are after the flash; no prices or badges.

Known, accepted: P01/D01 leave empty space above and below the tabletop Duo (the device is wider than tall); D09's Codex
has the R10 two-half layout (title on the lid half, grid on the floor half); P06/D06 show the run-start banner "Candle
lit. Gently does it." under CHOMP (a real bite on chest 1: since R15c the pilots rarely bite, so the noise is held at a
Waking 0.98 until the first bag clink tips it over).

Run history tonight: 40782567781 (first R15 set; 'keep' lint, placements script bug), 40786977121, 40790189482 (clean,
pre-R15d copy), 40793362597 (R15d; P06 no bite), 40796521782 / 40799894378 / 40804566490 (bite experiments),
40806720005 (D06 no bite), 40809079356 (final).

## 4. Only the founder can do (before pressing Submit)

1. App Store Connect → Hush 1.0: the **App Privacy** questionnaire ("Data Not Collected"), the **age rating**
   questionnaire (or let `asc.yml` push 9+), **Pricing** £1.99 (Tier) and availability (no China mainland, Vietnam),
   **export compliance** for build 11, **EU DSA trader** status, the **copyright** line, the **App Review contact**
   (name, email, +44 phone).
2. A **support contact** on https://pravegm.github.io/hush/support.html (Apple: the support URL must lead to contact
   information); the email address is the founder's decision.
3. Run `asc.yml` (Actions → App Store Connect tool → `asc` ticked, `mode=plan`, then `mode=push`, `build=11`,
   `placements_run=40809079356`) or upload by hand: 6.9" P01–P10, 6.3" P01–P10, iPhone Duo D01–D10 (if the API has no
   Duo group, drag them into the iPhone Duo tab), and in *Header and Search Results* the two `store-placements` PNGs.
   Check the product page preview (iPhone and iPhone Duo), then the Submit button.
