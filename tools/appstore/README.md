# App Store Connect from GitHub Actions

`asc.swift` puts the whole Hush 1.0 listing into App Store Connect from `docs/appstore/asc-metadata.json`. It is **Brim's tool, copied on 27 Oct 2026** (`C:\Users\59527\Fold\tools\appstore\`, itself a port of Squish's tool on the same Apple account, plus leaderboards, the review-submission attach step, the featuring nomination and `--inherit-from`). It is idempotent: it changes only what differs, and `push` resumes after a failure.

Nobody pastes anything. The founder only runs the workflow (`docs/LAUNCH-RUNBOOK.md` §1f and §5a).

**What changed from Brim's copy:** the bundle ID (`com.pravegm.hush`); the Game Center source (`Hush/App/GameCenterManager.swift`, falling back to the literal `"hush.ach.*"` strings in `Hush/Core/Ranks.swift` or `Achievements.swift`, because a Swoop-style manager builds `achievementIDs` from Core and Brim's parser could pick up the wrong list); uploaded file names (`hush-…`); `badges.swift` for 12 badges on the dungeon background `#12161C`; and in `asc.yml` the `HUSH-T` log prefix, empty `DEFAULT_STORE_RUN` / `DEFAULT_PLACEMENTS_RUN` (no store run or header art yet), and `BADGES_REQUIRED: "false"` until the app renders its badges. Everything Brim and Squish learned against the live API (masked personal fields, the live subcategory check, the asset-library screenshot path, the 404 on a new app's manual prices, Duo groups only when the API offers them) is kept as it was.

## Run it

GitHub → **Actions** → **App Store Connect tool** → **Run workflow**:

| Input | Meaning |
|---|---|
| `asc` | Tick to contact App Store Connect. Unticked, the run only typechecks and validates |
| `mode` | `check`: read-only status. `plan`: check plus a dry run, still read-only. `push`: check, plan, then write |
| `only` | Optional step list, e.g. `nomination` or `gamecenter,attach` |
| `store_run` | A green **App Store screenshots** run. Empty = `DEFAULT_STORE_RUN` in the workflow (empty until Hush's `store.yml` exists: screenshots are then a gap, not an error) |
| `placements_run` | A store.yml run whose `store-placements` artifact holds product page header and search results art. Hush 1.0 ships none; leave empty |
| `ci_run` | A green **CI** run whose `screenshots` artifact holds `badges/`. Empty = the latest green run on `main` |
| `inherit_from` | Default `com.pravegm.squish`. See "Personal data" |
| `build` | Optional release build number to attach to the version (step `build`) |

Every run uploads `asc-output` (check.txt, plan.txt, push.txt). Read `plan.txt` before running `push`.

```bash
gh workflow run asc.yml -R pravegm/hush -f asc=true -f mode=plan
gh workflow run asc.yml -R pravegm/hush -f asc=true -f mode=push -f only=nomination
```

The secrets are the shared Admin team key: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` (runbook §2). The key is written to a temp file for the job and deleted at the end. The **app record must exist first** (runbook §1c): the API can't create one, and `check` says "app: NOT FOUND" until it does.

## Personal data (the repo is public)

The metadata file has no name, phone, email or legal name: `copyrightHolder` and `review.contact` are `null`. With `--inherit-from com.pravegm.squish` (or `ASC_INHERIT_FROM`), the tool reads Squish's newest version at run time: its `copyright` line and its `appStoreReviewDetail` contact. It uses them in memory for Hush. Every value is masked in all output (`‹hidden›`, plus GitHub's `::add-mask::`), and `asc-output` gets only masked lines. Never put these values in a file.

## What `push` does, in order

| Step | What |
|---|---|
| `appinfo` | Name, subtitle and privacy URL for en-GB and en-US. Primary language en-GB. Content Rights: no third-party content |
| `categories` | Games: Casual and Adventure, then Entertainment. Subcategories are checked against Apple's live list first (on 26 Oct it had dropped Arcade: Brim's run 40340641267) |
| `agerating` | The questionnaire from `metadata.md` §8: Cartoon or Fantasy Violence, Horror/Fear Themes and Contests = Infrequent, everything else None or No. Result **9+** |
| `version` | 1.0: copyright (inherited), release **Manual** (the founder presses Release on Tue 1 Dec 2026) |
| `localizations` | Description (UK and US spellings), keywords, promotional text, support and marketing URLs |
| `review` | Review notes (≤ 4,000 bytes, or validate fails), "no sign-in", and the contact (inherited) |
| `gamecenter` | Enables Game Center for the app and version 1.0. Creates 12 achievements (525 points, none hidden) with en-GB and en-US text and a badge each (only once the badges exist). Creates 2 leaderboards: `hush.best` (classic, "Best Haul") and `hush.daily` (recurring daily from 1 Nov 2026 00:00 UTC, "Daily Dungeon"), both Integer, High to Low, best score, with " gold" suffixes |
| `attach` | Adds every achievement and leaderboard version to the draft iOS review submission. It never adds the build and never submits |
| `screenshots` | 6.9": P1–P6. 6.1"/6.3" class: P1–P6. iPhone Duo inner: D1–D6, only if the API offers a Duo placement group (`check` says). Names in `docs/appstore/screenshots.md` |
| `placements` | Only with `placements_run`: product page header and search results art. None for Hush 1.0 |
| `price` | £1.99, base territory United Kingdom; Apple equalises the rest. Available everywhere except China mainland and Vietnam |
| `accessibility` | Nothing for 1.0: labels go on by hand on launch day |
| `nomination` | The App Launch featuring nomination from `featuring-nomination.md`, publish date 1 Dec 2026. It's **submitted** (`"submit": true`), not left as a draft. Deadline Tue 10 Nov |

Badges: the app draws them (`Hush/UI/AchievementArt.swift`, as Brim's; demo `screen=badges`, log `HUSH-T badges done <n>`), and a CI scenario (still to add to `ci.yml`) renders them into the `screenshots` artifact (`DECISIONS.md` §2 #4). `badges.swift --from <that>/badges` checks the IDs against the app, `achievements.md` and the metadata, and writes opaque RGB copies to `tools/appstore/badges/`, the `badges` artifact. Until then the workflow warns and the `gamecenter` step lists every badge as a gap; set `BADGES_REQUIRED: "true"` in `asc.yml` once they render. Leaderboard images are optional and not pushed.

## Still by hand (no public API)

- **App Privacy**: Get Started → "Data Not Collected" → Publish.
- **Mac and Vision Pro**: Pricing and Availability → untick "iPhone and iPad Apps on Apple Silicon Macs" and "… on Apple Vision Pro".
- **Family Sharing**: on (permanent once on).
- **EU DSA trader status** for Hush: App Information → App Store Regulations and Permits.
- **Accessibility Nutrition Labels**: on launch day.
- **The build**: pick it on the 1.0 page, **Add for Review** (it joins the draft that holds the Game Center items), then **Submit to App Review**.
- **iPhone Duo screenshots**: by hand if the API offers no Duo group.

## Files

- `asc.swift`: the tool (Foundation and CryptoKit only). Commands: `validate`, `check`, `plan`, `push`, `upload-screenshots`, `upload-placements`. Run `xcrun swift tools/appstore/asc.swift help`.
- `badges.swift`: collects and flattens the app-rendered badges.
- `build-metadata.js`: regenerates `docs/appstore/asc-metadata.json` and the fixture from the docs (`node tools/appstore/build-metadata.js`; Node, because this Windows host has no Python). Run it whenever `metadata.md`, `review-notes.md`, `achievements.md` or `featuring-nomination.md` change.
- `fixtures/asc-metadata.sample.json`: the validator's CI fixture.
- `docs/appstore/asc-metadata.json`: the generated listing. Don't edit it by hand.

**Not yet compiled.** These files were copied and edited on a Windows host with no Swift; the first `asc.yml` run (typecheck on `xcode-27`) is their compiler. The Swift edits are small (`contractAchievementIDs`, `coreAchievementIDs`, badges' `appIDs`); if the typecheck fails, look there first.
