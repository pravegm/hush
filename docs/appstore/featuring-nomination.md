# Hush: Featuring nomination (App Launch)

*Final copy, Tue 27 Oct 2026, ready to paste (or pushed by the App Store Connect tool's `nomination` step, which presses Submit). The founder submits it (needs an App Store Connect login: Account Holder, Admin, App Manager or Marketing role).*

## Timing

**Launch date: Tue 1 Dec 2026.** Brim launches on Tue 17 Nov and Swoop on Tue 24 Nov, so Hush takes the next Tuesday and the three games never share a week.

Apple asks for nominations as early as possible, **at least 3 weeks before** the date. For Tue 1 Dec that means **submit by Tue 10 Nov 2026**, and sooner is better. It needs only the app record (runbook §1), not a build.

Where: App Store Connect → Apps → Hush → **Featuring** → **Nominations** → **Create Nomination**. A saved draft is not a nomination: press **Submit**.

If the launch moves to the fallback date (**Tue 15 Dec**, runbook timeline), edit the nomination's Publish Date the same day.

## Fields

| Field | Value | Count / limit |
|---|---|---|
| Nomination Name | `Hush - App Launch - iPhone Duo hinge-speed stealth` | 50 / 60 |
| Nomination Type | **App Launch** | — |
| Description | the block below | **950 / 1,000** |
| Publish Date | **Specific day: 2026-12-01** | — |
| Related Apps | Hush only (auto-filled). Don't add Brim, Swoop or Squish: they have their own nominations | up to 10 |
| Platforms | iOS | — |
| Countries or Regions | leave the auto-selection (every territory the app is in) | — |
| Localizations | leave the auto-selection (English (U.K.), English (U.S.)) | — |
| In-App Events | none | — |
| Supplemental Materials | 1. `https://pravegm.github.io/hush/` 2. the teaser post URL (once posted, Thu 26 Nov; add it by editing the nomination) 3. the TestFlight public link (only if you open external testing) | up to 5 URLs |
| Helpful Details | the block below | **467 / 500** |

### Description
```
Hush turns iPhone Duo into a treasure chest, and the chest is a sleeping mimic. Stand the Duo like a little laptop: the raised half is the lid. Open it slowly and candlelight spills in to show the gold; drag the loot into your bag gently, then ease the lid shut to bank it. Too fast, and the lid creaks, the mimic wakes and it bites.

It is the first game we know of that scores how slowly you move the hinge. The game reads how fast you move the lid, and the creak in your speaker and your fingers follows it exactly, so being gentle is the whole challenge, and the losing move is the one that's hard on a hinge.

Push-your-luck runs of about two minutes against a burning torch, chests that get richer from Wooden to Royal, four kinds of mimic, a Daily Dungeon with the same chests for everyone, a 24-relic Codex, 12 thief ranks and Game Center. Every other iPhone plays with an on-screen lid slider. No ads, no in-app purchases, no data collected.
```

### Helpful Details
```
Optimized for iPhone Duo: built for tabletop pose on the inner display. iOS blurs one half of the screen when a fold starts, so Hush draws the chest turned round: the blurring half is the lid, and the loot, meters and warnings stay on the sharp half (Settings: Turn the chest round). Uses the public iOS 27.1 hinge API; never asks for flat, closed or fast. A First Chest lesson teaches by doing. All sound synthesized in the app. Also from us: Squish, Brim and Swoop.
```

**Why this copy:**
- **New hardware first:** the opening line, and "Optimized for iPhone Duo" in Helpful Details (Apple's Duo guidance asks for exactly that phrase).
- **Unique input:** hinge *speed*, not angle, which `research/01-market.md` found in no other Duo game. Editors look for apps that do something only the new device can.
- **Craft:** a creak in sound and haptics that follows the hinge exactly; synthesized audio.
- **Built for the real device:** the blurred-half answer, said plainly; editors look for apps that handle the Duo's quirks.
- **Kind to the hardware, by design:** the losing move is the rough one. That answers the wear question before an editor asks it.
- **Replayability:** short runs, the Daily Dungeon, the Codex, ranks, Game Center.
- **Reach:** every iPhone plays with the lid slider. No VoiceOver claim (`accessibility.md`).
- **No ads:** the last line.

## Later nominations (optional)
- **New Content**, for the first update with real new content (new relics, a new mimic kind or chest tier). Description: what's new, one line restating no ads and a free update. Submit 3 weeks ahead.
- An **In-App Event** (a "Royal Vault week" Daily Dungeon, for example) needs a build that implements it first; don't create one for 1.0.

## Sources
- App Store Connect Help, *Nominations template* (name ≤ 60, description ≤ 1,000, helpful details ≤ 500, up to 5 URLs, types): https://developer.apple.com/help/app-store-connect/reference/nominations/nominations-template
- App Store Connect Help, *Nominate your app for featuring* (minimum 3 weeks' lead time; roles): https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring
- Swoop's and Brim's nominations (format mirrored): `C:\Users\59527\Wing\docs\appstore\featuring-nomination.md`, `C:\Users\59527\Fold\docs\appstore\featuring-nomination.md`
