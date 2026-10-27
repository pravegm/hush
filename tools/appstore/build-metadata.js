// Usage (repo root): node tools/appstore/build-metadata.js
// Regenerates docs/appstore/asc-metadata.json and tools/appstore/fixtures/asc-metadata.sample.json from the docs.
// Copied from Brim (pravegm/brim, tools/appstore/build-metadata.js, 26 Oct 2026) on 27 Oct 2026 and adapted for Hush:
// hush.* IDs, the site at https://pravegm.github.io/hush/ (no /site/ folder), " gold" leaderboard suffixes, Casual +
// Adventure, the 9+ answers, MANUAL release, CHN + VNM excluded, and the 1 Dec 2026 nomination. Run it whenever
// metadata.md, review-notes.md, achievements.md or featuring-nomination.md change; asc.yml validates the result.
const fs = require('fs'), path = require('path');
const root = process.argv[2] || path.join(__dirname, '..', '..');
const outFile = process.argv[3] || path.join(root, 'docs/appstore/asc-metadata.json');
const fixtureFile = process.argv[4] || path.join(root, 'tools/appstore/fixtures/asc-metadata.sample.json');
const rd = f => fs.readFileSync(path.join(root, 'docs/appstore', f), 'utf8').replace(/\r\n/g, '\n');
function blockAfter(text, marker) {
  const i = text.indexOf(marker); if (i < 0) throw new Error('marker ' + marker);
  const s = text.indexOf('```\n', i) + 4;
  const e = text.indexOf('\n```', s);
  return text.slice(s, e);
}
const md = rd('metadata.md');
const name = blockAfter(md, '## 1. App name');
const subtitle = blockAfter(md, '## 2. Subtitle');
const promo = blockAfter(md, '## 3. Promotional text');
const descGB = blockAfter(md, '### en-GB (English U.K.)');
const descUS = blockAfter(md, '### en-US (English U.S.)');
const keywords = blockAfter(md, '## 5. Keywords');
const rn = rd('review-notes.md');
const notes = blockAfter(rn, '<!-- REVIEW-NOTES:BEGIN -->');
const fn = rd('featuring-nomination.md');
const nomDesc = blockAfter(fn, '### Description');
const nomNotes = blockAfter(fn, '### Helpful Details');
const nomName = (fn.match(/\| Nomination Name \| `([^`]+)`/) || [])[1];
const ach = rd('achievements.md');
const rows = ach.split('\n').filter(l => /^\| \d+ \| `hush\./.test(l)).map(l => l.split('|').slice(1, -1).map(c => c.trim()));
function split2(c) { const p = c.split(' / '); return [p[0], p[1] || p[0]]; }
const achievements = rows.map(r => {
  const id = r[1].replace(/`/g, '');
  const [tGB, tUS] = split2(r[2]), [bGB, bUS] = split2(r[3]), [aGB, aUS] = split2(r[4]);
  const hidden = /yes/i.test(r[6]);
  const loc = (n, b, a) => ({ name: n, beforeEarnedDescription: b, afterEarnedDescription: a });
  return { vendorIdentifier: id, referenceName: tGB, points: parseInt(r[5], 10), showBeforeEarned: !hidden, repeatable: false,
    localizations: { 'en-GB': loc(tGB, bGB, aGB), 'en-US': loc(tUS, bUS, aUS) }, image: `tools/appstore/badges/${id}.png` };
});
if (achievements.length !== 12) throw new Error(`achievements.md has ${achievements.length} rows, expected 12`);
const site = 'https://pravegm.github.io/hush/';
const loc = (desc) => ({ name, subtitle, privacyPolicyUrl: site + 'privacy.html', description: desc, keywords, promotionalText: promo,
  supportUrl: site + 'support.html', marketingUrl: site });
const lbLoc = (n) => ({ name: n, formatterSuffix: ' gold', formatterSuffixSingular: ' gold' });
// Frame names follow docs/appstore/screenshots.md; the store pipeline (store.yml) must write exactly these files.
const phones = ['P1-hero-open', 'P2-drag-gently', 'P3-freeze', 'P4-bank', 'P5-chomp', 'P6-codex'];
const duo = ['D1-hero-open', 'D2-drag-gently', 'D3-freeze', 'D4-bank', 'D5-chomp', 'D6-codex'];
const meta = {
  _comment: 'Generated 27 Oct 2026 from docs/appstore/metadata.md, review-notes.md, achievements.md and featuring-nomination.md (node tools/appstore/build-metadata.js); asc.swift pushes it (tools/appstore/README.md). No personal data: the copyright and the App Review contact are read at run time from Squish (--inherit-from com.pravegm.squish). Achievements are TBD-sync with Hush/Core Achievements.all.',
  bundleId: 'com.pravegm.hush',
  primaryLocale: 'en-GB',
  copyrightHolder: null,
  contentRights: 'DOES_NOT_USE_THIRD_PARTY_CONTENT',
  categories: { primary: 'GAMES', primarySubcategories: ['GAMES_CASUAL', 'GAMES_ADVENTURE'], secondary: 'ENTERTAINMENT' },
  localizations: { 'en-GB': loc(descGB), 'en-US': loc(descUS) },
  ageRating: {
    _comment: 'metadata.md section 8 (27 Oct 2026): 9+; Cartoon or Fantasy Violence and Horror/Fear Themes Infrequent (the comic bite), Contests Infrequent (the optional leaderboards, as Brim), every other item None or No; not Made for Kids. Names from AgeRatingDeclarationUpdateRequest (read by Brim 26 Oct 2026).',
    parentalControls: false, ageAssurance: false, unrestrictedWebAccess: false, userGeneratedContent: false, messagingAndChat: false,
    advertising: false, socialMedia: false, socialMediaAgeRestricted: false,
    profanityOrCrudeHumor: 'NONE', horrorOrFearThemes: 'INFREQUENT', alcoholTobaccoOrDrugUseOrReferences: 'NONE', matureOrSuggestiveThemes: 'NONE',
    medicalOrTreatmentInformation: 'NONE', healthOrWellnessTopics: false, sexualContentOrNudity: 'NONE', sexualContentGraphicAndNudity: 'NONE',
    violenceCartoonOrFantasy: 'INFREQUENT', violenceRealistic: 'NONE', violenceRealisticProlongedGraphicOrSadistic: 'NONE', gunsOrOtherWeapons: 'NONE',
    gamblingSimulated: 'NONE', contests: 'INFREQUENT', gambling: false, lootBox: false, kidsAgeBand: null,
    ageRatingOverrideV2: 'NONE', koreaAgeRatingOverride: 'NONE'
  },
  review: { notes, demoAccountRequired: false, contact: { firstName: null, lastName: null, phone: null, email: null } },
  release: { _comment: 'Manual release: the founder presses Release This Version on Tue 1 Dec 2026 at about 08:00 UK (runbook section 6).', type: 'MANUAL' },
  price: { baseTerritory: 'GBR', customerPrice: '1.99' },
  availability: { _comment: 'metadata.md section 9: no NPPA (China mainland) or Vietnam game licence (Brim COMPLIANCE.md #15). Mac and Vision Pro off has no public API: the tool prints the clicks.', excludedTerritories: ['CHN', 'VNM'], availableInNewTerritories: true },
  achievements,
  leaderboards: [
    { vendorIdentifier: 'hush.best', referenceName: 'Best Haul', defaultFormatter: 'INTEGER', scoreSortType: 'DESC', submissionType: 'BEST_SCORE',
      scoreRangeStart: 0, scoreRangeEnd: 10000000, recurrence: null, localizations: { 'en-GB': lbLoc('Best Haul'), 'en-US': lbLoc('Best Haul') } },
    { vendorIdentifier: 'hush.daily', referenceName: 'Daily Dungeon', defaultFormatter: 'INTEGER', scoreSortType: 'DESC', submissionType: 'BEST_SCORE',
      scoreRangeStart: 0, scoreRangeEnd: 1000000,
      recurrence: { startDate: '2026-11-01T00:00:00Z', duration: 'PT24H', rule: 'FREQ=DAILY;INTERVAL=1' },
      localizations: { 'en-GB': lbLoc('Daily Dungeon'), 'en-US': lbLoc('Daily Dungeon') } }
  ],
  screenshots: {
    _comment: 'Paths inside a downloaded App Store screenshots run (store.yml, still to be ported: DECISIONS.md section 2 #3). Until a run exists (DEFAULT_STORE_RUN in asc.yml), validate reports them as gaps and push skips them. Order: screenshots.md.',
    APP_IPHONE_67: phones.map(n => `store-69/store/${n}.png`),
    APP_IPHONE_61: phones.map(n => `store-61/store/${n}.png`),
    duoInner: duo.map(n => `store-duo/duo-screens/store/${n}.png`)
  },
  nomination: {
    _comment: 'docs/appstore/featuring-nomination.md. notes = Helpful Details. submit: true presses Submit (a saved draft is not a nomination). Deadline Tue 10 Nov 2026.',
    name: nomName, type: 'APP_LAUNCH', description: nomDesc, notes: nomNotes, publishStartDate: '2026-12-01T08:00:00Z',
    deviceFamilies: ['IPHONE'], locales: ['en-GB', 'en-US'], supplementalMaterialsUris: [site],
    hasInAppEvents: false, launchInSelectMarketsFirst: false, preOrderEnabled: false, submit: true
  }
};
fs.writeFileSync(outFile, JSON.stringify(meta, null, 2) + '\n');
const c = s => [...s].length, b = s => Buffer.byteLength(s);
console.log({ name: c(name), subtitle: c(subtitle), promo: c(promo), descGB: c(descGB), descUS: c(descUS), kwBytes: b(keywords), notesBytes: b(notes), nomName: c(nomName), nomDesc: c(nomDesc), nomNotes: c(nomNotes), ach: achievements.length, pts: achievements.reduce((a, x) => a + x.points, 0) });
console.log(achievements.map(a => `${a.vendorIdentifier} ${a.points} show=${a.showBeforeEarned} | ${a.localizations['en-US'].name} | ${a.localizations['en-US'].beforeEarnedDescription} | ${a.localizations['en-US'].afterEarnedDescription}`).join('\n'));
const fx = JSON.parse(JSON.stringify(meta));
fx._comment = 'CI fixture for asc.swift validate (a placeholder URL, a partial en-US, missing images). The real data is docs/appstore/asc-metadata.json.';
fx.localizations['en-GB'].supportUrl = 'https://[SITE]/support.html';
fx.localizations['en-US'] = { description: descUS };
fx.achievements = fx.achievements.map(a => ({ ...a, localizations: { 'en-GB': a.localizations['en-GB'] }, image: 'tools/appstore/fixtures/missing.png' }));
delete fx.screenshots;
fs.writeFileSync(fixtureFile, JSON.stringify(fx, null, 2) + '\n');
