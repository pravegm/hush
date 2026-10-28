# Hush: App Privacy answers and privacy policy (v1.0)

**Answer: Data Not Collected.** Based on the design (no accounts, no analytics, no network: `design/ARCHITECTURE.md`, `CLAUDE.md`) and the privacy manifest `Hush/PrivacyInfo.xcprivacy` (no tracking, no tracking domains, no collected data types; required-reason APIs UserDefaults `CA92.1` and elapsed-time measurement `35F9.1`). The app code was still being written on 27 Oct 2026, so the grep in §3 must pass on the release-candidate build **before** you publish this answer.

The live policy page is `docs/privacy.html` (the text in §4 is the same; keep the two in step).

---

## 1. What to click (App Store Connect → the app → App Privacy)

1. **Privacy Policy URL:** `https://pravegm.github.io/hush/privacy.html`. The page must load before you save.
2. Click **Get Started**. "Do you or your third-party partners collect data from this app?" → **No, we do not collect data from this app.**
3. **Save**, then **Publish**. The product page shows **"Data Not Collected"**.

There's no tracking question once you choose "No". For the record, Hush doesn't track: no advertising identifier, no `AppTrackingTransparency`, no data brokers.

## 2. Why these things don't change the answer

| Thing | Declare? | Why |
|---|---|---|
| **Hinge angle and lid speed** | No | Read through the public `onHingeChange` API only to move the chest lid while the game is on screen. Never leaves the phone. Kept **on the phone only**: the diagnostics event log (`Persistence/EventLog.swift`, UserDefaults `hush.diag.events`: the last 80 events, each with its hinge angle, across launches) and the last hand-off and relight angles (`hush.diag.handoff`, `hush.diag.relight`). The policy says so (QA-6 P1-2). Nothing is transmitted; it leaves the device only if the user taps Copy log and pastes it somewhere themselves. Apple: "collect" means transmitting data off the device |
| **Touches** (dragging loot, the lever) | No | Used live for play only; never stored or sent |
| **Game Center** (sign-in, leaderboard scores, achievements) | No | Apple collects it under Apple's privacy policy. Apple: "You are not responsible for disclosing data collected by Apple." Hush never sends it anywhere itself |
| **Crash reports** via iOS "Share With App Developers" | No | Apple-collected and opt-in. We add no crash SDK. *If one is ever added, the label must declare Crash Data first* |
| **Rating prompt** (if added) | No | Apple's `requestReview` |
| **Support through GitHub issues** | No | Happens on GitHub, outside the app, under GitHub's privacy statement; covered by the policy |
| **Progress, Codex, rank, bests, Daily result, settings** | No | Stored only on the device (`ProgressStore`, `SettingsStore`, UserDefaults). Never transmitted |

**The limit to watch:** if a future version ever sends anything to our own server (analytics, online ghosts, a remote daily seed), or adds a share button that posts anywhere itself, this answer and the privacy manifest change **before** that build ships. (A share button that only hands text to the iOS share sheet doesn't change it; add a "Sharing" paragraph to the policy if one is added.)

## 3. Evidence to collect on the release-candidate build (Claude runs this; paste the result here)

| Look for, in `Hush/` | Expect | Result |
|---|---|---|
| Networking: `URLSession`, `URLRequest`, `NWConnection`, `import Network`, sockets | none | [ ] |
| Web/links: `WKWebView`, `SFSafariViewController`, `openURL`, SwiftUI `Link(` | none, or only a link to the support/privacy page (opening Safari is not collection) | [ ] |
| SDKs: Firebase, Crashlytics, Sentry, Mixpanel, Amplitude, AdSupport, `ASIdentifierManager` | none | [ ] |
| Tracking: `AppTrackingTransparency`, `ATTrackingManager` | none | [ ] |
| Cloud: `CloudKit`, `NSUbiquitousKeyValueStore` | none | [ ] |
| Notifications: `UNUserNotificationCenter` | none | [ ] |
| Hinge angle written to disk | only the diagnostics log (`EventLog` `hush.diag.events`, 80 entries) and `hush.diag.handoff` / `hush.diag.relight`, all UserDefaults on the device; never in `ProgressStore` or `SettingsStore`, never sent | [ ] |
| Packages in `project.yml` | none (true on 27 Oct) | [ ] |
| `NS*UsageDescription` keys in `project.yml` | none (true on 27 Oct) | [ ] |
| `Hush/PrivacyInfo.xcprivacy` in the built app | present | [ ] |
| Required-reason APIs | UserDefaults `CA92.1`, elapsed time `35F9.1` (declared). If the code uses file timestamps or disk space, add those reasons | [ ] |

One-line grep: `URLSession|URLRequest|NWConnection|WKWebView|SFSafari|openURL|Link\(|ATTrackingManager|ASIdentifier|CloudKit|NSUbiquitous|Firebase|Sentry|UNUserNotification`

---

## 4. Privacy policy (public text)

*Effective: 1 December 2026. Live at `https://pravegm.github.io/hush/privacy.html`.*

> # Hush Privacy Policy
>
> **The short version: Hush doesn't collect any data about you.** There are no accounts, no ads, no analytics and no tracking, and the app makes no network requests of its own. Your progress stays on your iPhone.
>
> ## What Hush collects
> Nothing. Hush has no sign-up and no login. It contains no advertising, analytics, crash-reporting or tracking code from anyone, and it doesn't ask for your camera, microphone, photos, contacts or location.
>
> ## The hinge on iPhone Duo
> On iPhone Duo, Hush reads how far, and how fast, the phone is opening or closing, only to move the chest lid while you play. That reading never leaves your iPhone.
>
> ## The diagnostics log
> To help fix problems, Hush keeps a short diagnostics log on your iPhone: the last 80 game events (such as a pause, a resume or the screen turning), each with the hinge angle at that moment, and the angles at which the Duo last switched screens. It stays on your iPhone (like the rest of the app's data, it is part of your device backup), it is never sent to us or anyone else, and it is deleted with the app. It leaves your iPhone only if you copy it yourself (Settings > About > hold Version > Copy log) and choose where to paste it.
>
> ## What stays on your device
> Your best hauls, your Daily Dungeon results, the relics in your Codex, your thief rank, your achievements, your settings and the diagnostics log are saved only on your iPhone. We can't see them. If you delete the app, they're deleted too.
>
> ## Game Center (optional)
> If you're signed in to Game Center, your scores and achievements are handled by Apple under Apple's Privacy Policy (apple.com/legal/privacy). We don't receive your Game Center profile.
>
> ## Crash reports
> If you've chosen in iOS Settings to share analytics with app developers, Apple may pass us anonymous crash reports. We use them only to fix bugs. You can turn this off at any time in Settings > Privacy & Security > Analytics & Improvements.
>
> ## Tracking
> Hush doesn't track you across apps or websites, and it never asks for tracking permission.
>
> ## Children
> Hush is rated 9+ and collects no personal information from anyone, including children.
>
> ## This website
> These pages have no cookies, analytics, trackers, embedded media, external fonts or scripts. They are hosted by GitHub Pages, which may keep standard server logs (such as IP addresses) for security, under GitHub's own privacy statement.
>
> ## If you contact us
> Support happens through GitHub issues (github.com/pravegm/hush/issues). Issues are public, so please don't include personal details. GitHub handles your GitHub account under its own privacy statement. We use what you write only to reply and fix the problem, and we'll delete or hide an issue if you ask.
>
> ## Changes
> If this policy ever changes, we'll update this page and its date before the change reaches the app.
>
> ## Contact
> Hush, an independent game by pravegm. Privacy questions: open an issue at github.com/pravegm/hush/issues.

*(Founder to decide: if a legal or trading name, an email address or a postal address is ever required, for example for EU trader status, add it to the Contact section and the live page. It is deliberately left off.)*

## Sources
- Apple, *App privacy details on the App Store* ("collect" means transmitting off the device beyond real-time servicing; "You are not responsible for disclosing data collected by Apple"): https://developer.apple.com/app-store/app-privacy-details/
- Apple, *Privacy manifest files* and required-reason APIs: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- Swoop's and Brim's reviewed answers (structure mirrored): `C:\Users\59527\Wing\docs\appstore\privacy.md`, `C:\Users\59527\Fold\docs\appstore\privacy.md`
