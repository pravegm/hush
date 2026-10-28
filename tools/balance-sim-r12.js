#!/usr/bin/env node
// Hush balance simulator (R12 copy for REVIEW-6-retention: adds career=, plan=, graceRuns=/graceNoise=, noise=)
// Hush balance simulator (Round 2): a line-by-line Node port of Hush/Core (Tuning, ChestFactory, HeistSession,
// ThiefPilot). KEEP IN SYNC with Hush/Core/*.swift. Used to tune Tuning numerically without a Swift compiler.
// R2 = REVIEW-1-feel's tools/balance-sim-r2.js proposal (kept as the reference, with its r1=1 baseline) plus the Duo
// relic depth 0.80-0.88 and the Swift rule that the Hush Chain breaks the moment the mimic stirs (same gold: that chest
// can no longer be Hushed either way).
// R7 ("real hands", design/notes/core-R7.md): quietSpeed 14, closeQuietSpeed 28, the 0.08 s loud onset, the fresh chest,
// LidSensitivity, and novice/casual pilots with real hand speeds and stick-slip (expert/perfect keep the 12/18 lines).
//
//   node tools/balance-sim.js                      # 8 seeds x 4 skills at 60 Hz, prints HUSH-BAL lines + target checks
//   node tools/balance-sim.js seeds=40 skills=casual,expert
//   node tools/balance-sim.js verbose=1 seeds=2    # one line per run
//   node tools/balance-sim.js windows=40           # robustness: medians of 40 different 8-seed windows (min..max)
//   node tools/balance-sim.js sensitivity=forgiving # R7 LidSensitivity (forgiving 0.75 / normal 1 / careful 1.2 noise)
//   node tools/balance-sim.js T.hands=0 T.loudOnsetSeconds=0 T.masterQuiet=0   # R7 ablations (R6 pilots, no onset, ...)
//   Any Tuning value can be overridden: T.decayWooden=0.12
//   Seeds are 1000 + 7919*i (base= and stride= move them), the same as HushTests/BalanceTests.swift.
//
// Numbers are not bit-identical to Swift (libm differs: exp), but R1's CI matched this sim within 1 gold per median.
// The port omits hints, rest()/resumeGrace() and the cosmetic parts of the snapshot (nothing balance-relevant).
'use strict';

// MARK: Tuning (mirror of Hush/Core/Tuning.swift)
const T = {
  shutAngle: 100, wideAngle: 165, shutZoneAngle: 110, tooWideAngle: 172,
  quietSpeed: 14, loudSpeed: 30, lidRateLinear: 0.008, lidRateQuadratic: 0.0004,
  dragQuietSpeed: 350, dragRatePerPoint: 0.0006,
  pickNoise: 0.02, bagNoise: 0.03, dropNoise: 0.08,
  decayGrace: 0.3, quietRateThreshold: 0.01, restlessPerSecond: 0.02, restlessFloor: 0.5,
  stirringNoise: 0.35, wakingNoise: 0.70, biteNoise: 1.0, stageHysteresis: 0.04, noBiteCap: 0.99,
  multSnorer: 1.0, multLight: 1.35, multHeavy: 0.7, multDreamer: 1.0,
  dreamTwitchMin: 4, dreamTwitchMax: 9,
  ironFromIndex: 2, gildedFromIndex: 4, royalFromIndex: 6,
  multWooden: 1, multIron: 1.5, multGilded: 2, multRoyal: 3,
  decayWooden: 0.16, decayIron: 0.14, decayGilded: 0.12, decayRoyal: 0.10,
  itemsWoodenMin: 5, itemsWoodenMax: 6, itemsIronMin: 6, itemsIronMax: 7,
  itemsGildedMin: 7, itemsGildedMax: 8, itemsRoyalMin: 8, itemsRoyalMax: 9,
  heavySleeperItemPenalty: 1,
  copperValueMin: 5, copperValueMax: 10, copperDepthMin: 0.0, copperDepthMax: 0.45, copperMin: 2, copperMax: 3,
  silverValueMin: 20, silverValueMax: 35, silverDepthMin: 0.20, silverDepthMax: 0.60,
  gemValueMin: 60, gemValueMax: 110, gemDepthMin: 0.45, gemDepthMax: 0.80, gemMin: 1, gemMax: 2,
  relicValueMin: 250, relicValueMax: 450, relicDepthMin: 0.80, relicDepthMax: 0.88, relicChance: 0.25,
  oilDepthMin: 0.25, oilDepthMax: 0.55, oilChance: 0.33,
  radiusCopper: 22, radiusSilver: 24, radiusGem: 26, radiusRelic: 34, radiusOil: 24,
  mimicWeightSnorer: 0.35, mimicWeightLight: 0.25, mimicWeightHeavy: 0.20, mimicWeightDreamer: 0.20,
  lootGap: 6, placementJitterY: 60, placementTries: 60, placementGridStep: 12,
  // R4: Tuning.lootKeepOut (floor space): no loot within radius + lootGap of the phone pause coin's corner, in every
  // mode (keepOut=0 switches it off for a comparison run).
  keepOut: 1, keepOutX: 540, keepOutY: 0, keepOutW: 130, keepOutH: 112,
  torchSeconds: 100, oilSeconds: 6, biteTorchPenalty: 10, torchLowSeconds: 15,
  shutHoldSeconds: 0.35, bankMomentSeconds: 1.4, biteMomentSeconds: 1.8, torchOutSeconds: 2.0,
  lightRamp: 0.10, revealLight: 0.4, grabLight: 0.6, lootingStartOpenness: 0.02, lidCrackedOpenness: 0.05,
  grabSlop: 14, maxSubstep: 1 / 120,
  dragSmoothing: 0.06, dragStillAfter: 0.06, dragStillDecay: 0.10,
  // --- R2 rules (set to 0 to switch one off for an ablation) ---
  chainStep: 0.1, chainMax: 5,          // Hush chain: a Hushed bank pays x(1 + chainStep*min(chain, chainMax))
  goldenChance: 0.06, goldenFromIndex: 2, goldenValueMult: 2, goldenNoiseMult: 1.25,  // rare golden mimic
  jinglePerItem: 0.035,                 // bag jingle: noise cannot decay below jinglePerItem*bagCount*mimicMult
  jingleMax: 0.30,                      // ... capped here (below Stirring 0.35, so a full bag never stirs by itself)
  greedExpert: 0.20, greedPerfect: 0.22, // adapted pilots bank once the jingle floor reaches this
  closeQuietSpeed: 28,                  // R7 18 -> 28. >0: the lid is silent below this while CLOSING (0 = same as quietSpeed)
  relicGlimmer: 1,                      // >0: relic chests twinkle; novice/casual then go for the relic (lure odds below)
  lureNovice: 0.5, lureCasual: 0.6,
  adaptPilots: 1,                       // expert/perfect play to the quiet thresholds (speeds x quiet / R1 quiet)
  // --- R7 rules (real hands) ---
  loudOnsetSeconds: 0.08,               // lid noise counts only once the lid has been above quiet this long (0 = off)
  freshChestOpenness: 0.05,             // HeistSession.isFreshChest: .ready, openness never above this, empty bag
  masterQuiet: 12, masterCloseQuiet: 18, // expert/perfect adapt to these lines (0 = to the live Tuning lines)
  hands: 1,                             // novice/casual pilots move like real hands (R7 speeds + stick-slip); 0 = R6 pilots
};
const R1_QUIET = 8, R1_DRAG_QUIET = 250;
const FLOOR = { width: 670, height: 456, bagMinY: 346, ix: 78, iy: 36, iw: 514, ih: 286 };

// overrides
const args = {};
for (const a of process.argv.slice(2)) { const [k, v] = a.split('='); if (!k.startsWith('T.')) args[k] = v === undefined ? '1' : v; }
for (const a of process.argv.slice(2)) { const [k, v] = a.split('='); if (k.startsWith('T.')) T[k.slice(2)] = Number(v); }

// MARK: SeededRandom (SplitMix64)
const M64 = (1n << 64n) - 1n;
class SeededRandom {
  constructor(seed) { this.state = BigInt.asUintN(64, BigInt(seed)); }
  next() {
    this.state = (this.state + 0x9E3779B97F4A7C15n) & M64;
    let z = this.state;
    z = ((z ^ (z >> 30n)) * 0xBF58476D1CE4E5B9n) & M64;
    z = ((z ^ (z >> 27n)) * 0x94D049BB133111EBn) & M64;
    return z ^ (z >> 31n);
  }
  unit() { return Number(this.next() >> 11n) * (1.0 / 9007199254740992.0); }
  range(lo, hi) { return lo + (hi - lo) * this.unit(); }
  int(lo, hi) { if (hi <= lo) return lo; const n = BigInt(hi - lo + 1); return lo + Number(this.next() % n); }
}

// MARK: Noise / Lid
function quietLine(closing) { return closing && T.closeQuietSpeed > 0 ? T.closeQuietSpeed : T.quietSpeed; }
// R7: the share of a sub-step of length h past the loud onset (Noise.onsetShare): the first loudOnsetSeconds of a loud
// stretch are free.
function onsetShare(before, after, h) { if (!(h > 0)) return 0; return Math.min(Math.max((after - Math.max(before, T.loudOnsetSeconds)) / h, 0), 1); }
function lidRate(speed, closing) { const q = quietLine(closing); if (!(speed > q)) return 0; const x = speed - q; return T.lidRateLinear * x + T.lidRateQuadratic * x * x; }
function dragRate(speed) { if (!(speed > T.dragQuietSpeed)) return 0; return T.dragRatePerPoint * (speed - T.dragQuietSpeed); }
const ASLEEP = 0, STIRRING = 1, WAKING = 2, BITING = 3;
function upThreshold(s) { return s === STIRRING ? T.stirringNoise : s === WAKING ? T.wakingNoise : s === BITING ? T.biteNoise : 0; }
function stageFor(n, prev) {
  let s = prev;
  while (s < BITING && n >= upThreshold(s + 1)) s += 1;
  while (s > ASLEEP && n < upThreshold(s) - T.stageHysteresis) s -= 1;
  return s;
}
function openness(angle) { return Math.min(Math.max((angle - T.shutAngle) / (T.wideAngle - T.shutAngle), 0), 1); }
function angleFor(o) { return T.shutAngle + Math.min(Math.max(o, 0), 1) * (T.wideAngle - T.shutAngle); }

// MARK: ChestFactory
const TIERS = ['wooden', 'iron', 'gilded', 'royal'];
function tierFor(i) { return i >= T.royalFromIndex ? 3 : i >= T.gildedFromIndex ? 2 : i >= T.ironFromIndex ? 1 : 0; }
function tierMult(t) { return [T.multWooden, T.multIron, T.multGilded, T.multRoyal][t]; }
function tierDecay(t) { return [T.decayWooden, T.decayIron, T.decayGilded, T.decayRoyal][t]; }
function tierItems(t) { return [[T.itemsWoodenMin, T.itemsWoodenMax], [T.itemsIronMin, T.itemsIronMax], [T.itemsGildedMin, T.itemsGildedMax], [T.itemsRoyalMin, T.itemsRoyalMax]][t]; }
function mimicMult(k) { return [T.multSnorer, T.multLight, T.multHeavy, T.multDreamer][k]; }
const SNORER = 0, LIGHT = 1, HEAVY = 2, DREAMER = 3;
function chestSeed(seed, index) {
  const s = BigInt.asUintN(64, BigInt(seed)) ^ ((BigInt(index + 1) * 0x9E3779B97F4A7C15n) & M64);
  const r = new SeededRandom(s); return r.next();
}
function relicIDs() { const a = []; for (let i = 1; i <= 24; i++) a.push('relic' + String(i).padStart(2, '0')); return a; }
function chest(seed, index, found) {
  const rng = new SeededRandom(chestSeed(seed, index));
  const tier = tierFor(index);
  // mimic
  let mimic;
  {
    const u = rng.unit();
    const w = [T.mimicWeightSnorer, T.mimicWeightLight, T.mimicWeightHeavy, T.mimicWeightDreamer];
    const total = w[0] + w[1] + w[2] + w[3];
    let acc = 0; mimic = DREAMER;
    for (let k = 0; k < 4; k++) { acc += w[k] / total; if (u < acc) { mimic = k; break; } }
    if (index === 0 && mimic === LIGHT) mimic = SNORER;
  }
  const nameRoll = rng.next();
  const [lo, hi] = tierItems(tier);
  let n = rng.int(lo, hi);
  if (mimic === HEAVY) n = Math.max(3, n - T.heavySleeperItemPenalty);
  const hasRelic = tier >= 1 && rng.unit() < T.relicChance;
  let oil = rng.unit() < T.oilChance ? 1 : 0;
  let gems = rng.int(T.gemMin, T.gemMax);
  let coppers = rng.int(T.copperMin, T.copperMax);
  let relics = hasRelic ? 1 : 0;
  let silver = n - relics - oil - gems - coppers;
  while (silver < 0) {
    if (coppers > 1) coppers -= 1; else if (gems > 1) gems -= 1; else if (oil > 0) oil = 0; else break;
    silver += 1;
  }
  silver = Math.max(0, silver);
  const kinds = [];
  for (let i = 0; i < relics; i++) kinds.push('relic');
  for (let i = 0; i < gems; i++) kinds.push('gem');
  for (let i = 0; i < oil; i++) kinds.push('oil');
  for (let i = 0; i < silver; i++) kinds.push('silver');
  for (let i = 0; i < coppers; i++) kinds.push('copper');
  const items = [];
  let id = 0;
  for (const k of kinds) {
    let value, depth, radius, relicID = null;
    if (k === 'copper') { value = rng.int(T.copperValueMin, T.copperValueMax); depth = rng.range(T.copperDepthMin, T.copperDepthMax); radius = T.radiusCopper; }
    else if (k === 'silver') { value = rng.int(T.silverValueMin, T.silverValueMax); depth = rng.range(T.silverDepthMin, T.silverDepthMax); radius = T.radiusSilver; }
    else if (k === 'gem') { value = rng.int(T.gemValueMin, T.gemValueMax); depth = rng.range(T.gemDepthMin, T.gemDepthMax); radius = T.radiusGem; rng.int(0, 3); }
    else if (k === 'relic') {
      value = rng.int(T.relicValueMin, T.relicValueMax); depth = rng.range(T.relicDepthMin, T.relicDepthMax); radius = T.radiusRelic;
      const pick = rng.unit();
      const all = relicIDs(); const unfound = all.filter((r) => !found.has(r)); const pool = unfound.length > 0 ? unfound : all;
      relicID = pool[Math.min(pool.length - 1, Math.floor(pick * pool.length))];
    }
    else { value = 0; depth = rng.range(T.oilDepthMin, T.oilDepthMax); radius = T.radiusOil; }
    const pos = place(rng, depth, radius, items);
    const rotation = rng.range(-0.5, 0.5);
    items.push({ id, kind: k, relicID, value, depth, x: pos.x, y: pos.y, radius, rotation });
    id += 1;
  }
  // R2 golden mimic: its own stream, so every other draw (and the Daily) is unchanged.
  const grng = new SeededRandom(chestSeed(seed, index) ^ 0x601DE7n);
  const golden = index >= T.goldenFromIndex && grng.unit() < T.goldenChance;
  const multiplier = tierMult(tier) * (golden ? T.goldenValueMult : 1);
  return { index, tier, mimic, golden, multiplier, decay: tierDecay(tier), items, nameRoll };
}
function place(rng, depth, radius, items) {
  const minX = FLOOR.ix + radius, maxX = FLOOR.ix + FLOOR.iw - radius;
  const minY = FLOOR.iy + radius, maxY = FLOOR.iy + FLOOR.ih - radius;
  const kx0 = T.keepOutX, kx1 = T.keepOutX + T.keepOutW, ky0 = T.keepOutY, ky1 = T.keepOutY + T.keepOutH;
  const clear = (x, y) => !T.keepOut
    || Math.sqrt((x - Math.min(Math.max(x, kx0), kx1)) ** 2 + (y - Math.min(Math.max(y, ky0), ky1)) ** 2) >= radius + T.lootGap;
  const free = (x, y) => clear(x, y) && items.every((o) => Math.hypot(o.x - x, o.y - y) >= o.radius + radius + T.lootGap);
  const baseY = maxY - depth * (maxY - minY);
  for (let t = 0; t < T.placementTries; t++) {
    const x = rng.range(minX, maxX);
    const spread = T.placementJitterY * (1 + t / 15);
    const y = Math.min(Math.max(baseY + rng.range(-spread, spread), minY), maxY);
    if (free(x, y)) return { x, y };
  }
  for (let y = minY; y <= maxY; y += T.placementGridStep) for (let x = minX; x <= maxX; x += T.placementGridStep) if (free(x, y)) return { x, y };
  return { x: (minX + maxX) / 2, y: (minY + maxY) / 2 };
}

// MARK: HeistSession
// R7: LidSensitivity -> noise scale (the scored Daily always plays .normal).
const SENSITIVITY = { forgiving: 0.75, normal: 1.0, careful: 1.2 };  // Tuning.forgiving/normal/carefulNoiseScale
class HeistSession {
  constructor(seed, options) {
    this.seed = seed; this.opt = Object.assign({ torch: true, bites: true, noiseScale: 1, sensitivity: 'normal' }, options || {});
    this.opt.noiseScale *= SENSITIVITY[this.opt.sensitivity];
    this.loudFor = 0; this.peakOpenness = 0;
    this.time = 0; this.phase = 'ready'; this.elapsed = 0;
    this.index = 0; this.found = new Set(this.opt.found || []);  // R12: career mode carries the Codex
    this.noise = 0; this.stage = ASLEEP; this.quietFor = 0; this.chestTime = 0;
    this.torch = T.torchSeconds; this.torchTotal = T.torchSeconds; this.torchLowSent = false;
    this.banked = 0; this.chestsBanked = 0; this.hushed = 0; this.bites = 0; this.chestsOpened = 0;
    this.lostToBites = 0; this.itemsBagged = 0; this.relics = []; this.bestChest = 0;
    this.chain = 0; this.bestChain = 0; this.goldens = 0; this.goldenBanked = 0; this.chainGold = 0; this.chainBreaks = 0;
    this.chestLog = [];
    this.touches = new Map();
    this.lid = { openness: 0, speed: 0, inShutZone: true, tooWide: false };
    this.pending = [];
    this.setupChest(chest(seed, 0, this.found));
    this.pending.push({ e: 'chestArrived' });
  }
  setupChest(spec) {
    this.chest = spec;
    this.loot = spec.items.map((it) => ({ item: it, x: it.x, y: it.y, place: 'inChest', touch: -1, light: 0, grabbable: false }));
    this.phase = 'ready'; this.sawShut = false; this.cracked = false; this.chestTime = 0; this.shutHold = 0;
    this.bagCount = 0; this.bagValue = 0; this.leftAsleep = false; this.revealed = new Set();
    this.noise = 0; this.quietFor = 0; this.loudFor = 0; this.peakOpenness = this.lid ? this.lid.openness : 0;
    this.twitchRng = new SeededRandom(chestSeed(this.seed, spec.index) ^ 0x7417C4n);
    this.twitchIn = this.twitchRng.range(T.dreamTwitchMin, T.dreamTwitchMax);
  }
  jingleFloor() { return Math.min(T.jingleMax, T.jinglePerItem * this.bagCount * this.mult()); }
  mult() { return mimicMult(this.chest.mimic) * (this.chest.golden ? T.goldenNoiseMult : 1) * this.opt.noiseScale; }
  scaled(v) { return Math.round(v * this.chest.multiplier); }
  step(dt, lid) {
    if (this.phase === 'finished') return [];
    const ev = this.pending; this.pending = [];
    const d = Number.isFinite(dt) ? Math.max(0, dt) : 0;
    const newO = Math.min(Math.max(lid.openness, 0), 1);
    this.closing = newO < this.lid.openness - 1e-9;
    this.lid = { openness: newO, speed: Math.max(0, lid.speed), inShutZone: lid.inShutZone, tooWide: lid.tooWide };
    const n = Math.max(1, Math.ceil(d / T.maxSubstep - 1e-9));
    const h = d / n;
    for (let i = 0; i < n; i++) { this.tick(h, ev); if (this.phase === 'finished') break; }
    return ev;
  }
  tick(h, ev) {
    this.time += h;
    if (this.phase === 'banked') { this.elapsed += h; if (this.elapsed >= T.bankMomentSeconds) this.nextChest(ev); return; }
    if (this.phase === 'bitten') { this.elapsed += h; if (this.elapsed >= T.biteMomentSeconds) { if (this.opt.torch && this.torch <= 0) this.startTorchOut(ev); else this.nextChest(ev); } return; }
    if (this.phase === 'torchOut') { this.elapsed += h; if (this.elapsed >= T.torchOutSeconds) this.finish(ev); return; }
    if (this.phase === 'finished') return;
    this.play(h, ev);
  }
  // R7: an untouched .ready chest (the App skips the stillness wait for it).
  isFreshChest() { return this.phase === 'ready' && this.bagCount === 0 && this.peakOpenness <= T.freshChestOpenness; }
  play(h, ev) {
    const o = this.lid.openness;
    this.peakOpenness = Math.max(this.peakOpenness, o);
    if (this.phase === 'ready') {
      if (this.lid.inShutZone) this.sawShut = true;
      if (this.sawShut && o > T.lootingStartOpenness) { this.phase = 'looting'; this.chestsOpened += 1; this.chestTime = 0; }
    }
    if (this.phase === 'looting') {
      this.chestTime += h;
      if (!this.cracked && o > T.lidCrackedOpenness) { this.cracked = true; ev.push({ e: 'lidCracked' }); }
    }
    this.updateLight(ev);
    // held-drag stillness
    for (const t of this.touches.values()) { t.stillFor += h; if (t.stillFor > T.dragStillAfter) t.speed *= Math.exp(-h / T.dragStillDecay); }
    // noise
    // R7 loud onset: the lid only counts once it has been above its quiet line for loudOnsetSeconds.
    const loudBefore = this.loudFor;
    if (this.lid.speed > quietLine(this.closing)) this.loudFor += h; else this.loudFor = 0;
    let raw = lidRate(this.lid.speed, this.closing) * onsetShare(loudBefore, this.loudFor, h);
    for (const t of this.touches.values()) raw += dragRate(t.speed);
    const rate = raw * this.mult();
    this.noise += rate * h;
    if (rate > T.quietRateThreshold) this.quietFor = 0; else this.quietFor += h;
    if (this.quietFor >= T.decayGrace) {
      const restless = Math.max(T.restlessFloor, 1 - T.restlessPerSecond * this.chestTime);
      const floor = this.jingleFloor();
      const before = this.noise;
      this.noise -= this.chest.decay * restless * h;
      if (this.noise < floor) this.noise = Math.min(before, floor);
    }
    this.settleNoise(ev);
    if (this.phase !== 'ready' && this.phase !== 'looting') return;
    // bank
    if (this.phase === 'looting' && this.bagCount > 0 && this.lid.inShutZone) {
      this.shutHold = Math.min(1, this.shutHold + h / T.shutHoldSeconds);
      if (this.shutHold >= 1) { this.bank(ev); return; }
    } else this.shutHold = 0;
    // torch
    if (this.opt.torch) {
      this.torch -= h;
      if (!this.torchLowSent && this.torch <= T.torchLowSeconds) { this.torchLowSent = true; ev.push({ e: 'torchLow' }); }
      if (this.torch <= 0) { this.torch = 0; this.startTorchOut(ev); return; }
    }
    if (this.chest.mimic === DREAMER) {
      this.twitchIn -= h;
      if (this.twitchIn <= 0) { ev.push({ e: 'dreamTwitch' }); this.twitchIn = this.twitchRng.range(T.dreamTwitchMin, T.dreamTwitchMax); }
    }
  }
  updateLight(ev) {
    const looting = this.phase === 'looting';
    const o = this.lid.openness;
    for (const s of this.loot) {
      if (s.place === 'inChest') {
        s.light = looting ? Math.min(Math.max((o - s.item.depth) / T.lightRamp, 0), 1) : 0;
        s.grabbable = looting && s.light >= T.grabLight;
        if (s.light >= T.revealLight && !this.revealed.has(s.item.id)) { this.revealed.add(s.item.id); ev.push({ e: 'itemRevealed', id: s.item.id }); }
      } else if (s.place === 'lost') { s.grabbable = false; }
      else { s.light = 1; s.grabbable = false; }
    }
  }
  canBite() { return this.opt.bites && this.phase === 'looting'; }
  settleNoise(ev) {
    const cap = this.canBite() ? 1 : T.noBiteCap;
    this.noise = Math.min(Math.max(this.noise, 0), cap);
    if (this.canBite() && this.noise >= T.biteNoise) { this.bite(ev); return; }
    const ns = stageFor(this.noise, this.stage);
    if (ns !== this.stage) { ev.push({ e: 'stageChanged', from: this.stage, to: ns }); this.stage = ns; if (ns > ASLEEP) this.markStirred(ev); }
  }
  // Swift: the chain breaks the moment the mimic leaves Asleep (that chest can no longer be Hushed).
  markStirred(ev) { if (this.leftAsleep) return; this.leftAsleep = true; this.breakChain(ev); }
  breakChain(ev) { if (this.chain >= 2) { ev.push({ e: 'chainBroken', count: this.chain }); this.chainBreaks += 1; } this.chain = 0; }
  addOneOff(a, ev) { this.noise += a * this.mult(); this.quietFor = 0; this.settleNoise(ev); }
  inHandValue() {
    let v = this.bagValue;
    for (const s of this.loot) if (s.place === 'held') v += this.scaled(s.item.value);
    return v;
  }
  bite(ev) {
    const lost = this.inHandValue();
    for (const s of this.loot) if (s.place === 'held' || s.place === 'inBag') s.place = 'lost';
    this.touches.clear();
    ev.push({ e: 'stageChanged', from: this.stage, to: BITING }); this.stage = BITING;
    ev.push({ e: 'bitten', lost });
    this.bites += 1; this.lostToBites += lost; this.bagValue = 0; this.bagCount = 0;
    const torchBefore = this.torch;
    if (this.opt.torch) this.torch = Math.max(0, this.torch - T.biteTorchPenalty);
    ev.push({ e: 'biteCost', lost, seconds: torchBefore - this.torch });
    this.chestLog.push({ tier: this.chest.tier, golden: this.chest.golden, value: 0, hushed: false, bitten: true });
    this.leftAsleep = true; this.breakChain(ev);
    this.phase = 'bitten'; this.elapsed = 0; this.shutHold = 0; this.noise = 1;
  }
  bank(ev) {
    const hushedNow = !this.leftAsleep;
    if (hushedNow) this.chain += 1; else this.chain = 0;
    this.bestChain = Math.max(this.bestChain, this.chain);
    const value = hushedNow ? Math.round(this.bagValue * (1 + T.chainStep * Math.min(this.chain, T.chainMax))) : this.bagValue;
    this.chainGold += value - this.bagValue;
    if (this.chest.golden) this.goldenBanked += 1;
    this.banked += value; this.chestsBanked += 1; if (hushedNow) this.hushed += 1;
    this.bestChest = Math.max(this.bestChest, value);
    this.chestLog.push({ tier: this.chest.tier, golden: this.chest.golden, value, hushed: hushedNow, bitten: false });
    for (const s of this.loot) {
      if (s.place === 'inBag' && s.item.kind === 'relic') { this.relics.push(s.item.relicID); this.found.add(s.item.relicID); }
      if (s.place === 'held') { s.place = 'inChest'; s.touch = -1; }
    }
    this.touches.clear();
    ev.push({ e: 'banked', value, items: this.bagCount, hushed: hushedNow });
    this.bagValue = 0; this.phase = 'banked'; this.elapsed = 0; this.shutHold = 1;
  }
  nextChest(ev) {
    this.index += 1;
    if (this.stage !== ASLEEP) { ev.push({ e: 'stageChanged', from: this.stage, to: ASLEEP }); this.stage = ASLEEP; }
    this.setupChest(chest(this.seed, this.index, this.found));
    if (this.chest.golden) this.goldens += 1;
    ev.push({ e: 'chestArrived' });
  }
  startTorchOut(ev) {
    if (this.phase === 'looting') this.chestLog.push({ tier: this.chest.tier, golden: this.chest.golden, value: 0, hushed: false, bitten: false });
    for (const s of this.loot) if (s.place === 'held' || s.place === 'inBag') s.place = 'lost';
    this.touches.clear(); this.bagValue = 0; this.bagCount = 0;
    this.phase = 'torchOut'; this.elapsed = 0; ev.push({ e: 'torchOut' });
  }
  finish(ev) { this.phase = 'finished'; ev.push({ e: 'finished' }); }
  // touches
  touchBegan(id, p, time) {
    if (this.phase !== 'looting' || this.touches.has(id)) return [];
    let best = -1, bestD = Infinity;
    this.loot.forEach((s, k) => {
      if (s.place !== 'inChest' || !s.grabbable) return;
      const d = Math.hypot(s.x - p.x, s.y - p.y);
      if (d <= s.item.radius + T.grabSlop && d < bestD) { best = k; bestD = d; }
    });
    if (best < 0) return [];
    const ev = [];
    const s = this.loot[best];
    s.place = 'held'; s.touch = id; s.x = clampX(p.x); s.y = clampY(p.y);
    this.touches.set(id, { k: best, lx: p.x, ly: p.y, lt: time, speed: 0, stillFor: 0 });
    ev.push({ e: 'itemPicked', id: s.item.id });
    this.addOneOff(T.pickNoise, ev);
    return ev;
  }
  touchMoved(id, p, time) {
    const t = this.touches.get(id); if (!t) return [];
    const dtt = time - t.lt;
    if (dtt > 1e-4) {
      const inst = Math.hypot(p.x - t.lx, p.y - t.ly) / dtt;
      const a = Math.min(1, dtt / T.dragSmoothing);
      t.speed += (inst - t.speed) * a; t.lx = p.x; t.ly = p.y; t.lt = time;
    }
    t.stillFor = 0;
    const s = this.loot[t.k]; s.x = clampX(p.x); s.y = clampY(p.y);
    return [];
  }
  touchEnded(id, p, time) {
    const t = this.touches.get(id); if (!t) return [];
    this.touches.delete(id);
    const s = this.loot[t.k];
    if (s.place !== 'held' || s.touch !== id) return [];
    const ev = [];
    s.touch = -1;
    if (p.y >= FLOOR.bagMinY) {
      s.place = 'inBag';
      const v = this.scaled(s.item.value);
      this.bagCount += 1; this.bagValue += v; this.itemsBagged += 1;
      ev.push({ e: 'itemBagged', id: s.item.id, value: v });
      if (s.item.kind === 'oil') { this.torch += T.oilSeconds; this.torchTotal += T.oilSeconds; ev.push({ e: 'oilAdded' }); }
      this.addOneOff(T.bagNoise, ev);
    } else {
      s.place = 'inChest';
      const r = s.item.radius;
      s.x = Math.min(Math.max(p.x, FLOOR.ix + r), FLOOR.ix + FLOOR.iw - r);
      s.y = Math.min(Math.max(p.y, FLOOR.iy + r), FLOOR.iy + FLOOR.ih - r);
      ev.push({ e: 'itemDropped', id: s.item.id });
      this.addOneOff(T.dropNoise, ev);
    }
    return ev;
  }
}
function clampX(x) { return Math.min(Math.max(x, 0), FLOOR.width); }
function clampY(y) { return Math.min(Math.max(y, 0), FLOOR.height); }

// MARK: ThiefPilot (mirror of Hush/Core/ThiefPilot.swift)
const PROFILES = {
  novice: { open: [10, 35], close: [10, 15], slamChance: 0.3, slam: [70, 120], drag: [700, 1200], reaction: 0.6, freezeStage: WAKING, freezeObey: 0.5, unfreeze: 0.5, concurrent: false, reach: 0.62, drop: 0.15, torchAware: false, frontFirst: true },
  casual: { open: [8, 16], close: [8, 15], slamChance: 0, slam: [0, 0], drag: [450, 800], reaction: 0.55, freezeStage: WAKING, freezeObey: 1, unfreeze: 0.5, concurrent: false, reach: 0.80, drop: 0.05, torchAware: false, frontFirst: true },
  expert: { open: [5, 9], close: [8, 12], slamChance: 0, slam: [0, 0], drag: [200, 320], reaction: 0.25, freezeStage: STIRRING, freezeObey: 1, unfreeze: 0.25, concurrent: true, reach: 1, drop: 0, torchAware: true, frontFirst: false },
  perfect: { open: [6, 6], close: [15, 15], slamChance: 0, slam: [0, 0], drag: [240, 240], reaction: 0.12, freezeStage: STIRRING, freezeObey: 1, unfreeze: 0.25, concurrent: true, reach: 1, drop: 0, torchAware: true, frontFirst: false },
};
// R7 "real hands" (T.hands): novice and casual move like a person (DEVICE-RISKS-1 item 1, REVIEW-1-feel): a natural
// slow close is 20-40 deg/s, and every stroke from still starts with a stick-slip jump (slip, degrees in one frame).
const HANDS = {
  novice: { open: [12, 40], close: [30, 60], slip: [0.5, 2] },  // "faster still" (slams stay: 30 % at 70-120)
  casual: { open: [10, 25], close: [20, 40], slip: [0.5, 2] },
};
const SLIP_SALT = 0x5715B11n;
const P = { shutTarget: 0.06, openMargin: 0.015, bagY: 400, dropY: 302, bagJitter: 40, bagMinX: 60, bagMaxX: 610, torchMargin: 1.0 };
const LID_TRAVEL = () => T.wideAngle - T.shutAngle;
class ThiefPilot {
  constructor(skill, seed) {
    this.skill = skill; this.p = Object.assign({ slip: [0, 0] }, PROFILES[skill]); this.rng = new SeededRandom(seed);
    if (T.hands && HANDS[skill]) this.p = Object.assign({}, this.p, HANDS[skill]);
    this.slipRng = new SeededRandom(BigInt.asUintN(64, BigInt(seed)) ^ SLIP_SALT); this.stillBefore = true;
    // Sensitivity (args, not Tuning): casualObey=0.85 (a human sometimes fails to freeze); casualScale=1 (casual also
    // plays relative to the new thresholds: speeds x quiet/8, drags x dragQuiet/250).
    if (skill === 'casual' && (args.casualObey || args.casualScale)) {
      const p = this.p; const q = {};
      if (args.casualObey) q.freezeObey = Number(args.casualObey);
      if (args.casualScale) { const kl = T.quietSpeed / R1_QUIET, kd = T.dragQuietSpeed / R1_DRAG_QUIET; q.open = p.open.map((x) => x * kl); q.close = p.close.map((x) => x * kl); q.drag = p.drag.map((x) => x * kd); }
      this.p = Object.assign({}, p, q);
    }
    if (T.adaptPilots && (skill === 'expert' || skill === 'perfect')) {
      // R7: the masters play to the R2-R6 lines (masterQuiet 12, masterCloseQuiet 18), not to R7's forgiving 14 / 28:
      // the forgiveness is for real hands on unknown hardware, not a free speed-up for the skill ceiling.
      const mq = T.masterQuiet > 0 ? T.masterQuiet : T.quietSpeed;
      const kl = mq / R1_QUIET, kd = T.dragQuietSpeed / R1_DRAG_QUIET; const p = this.p;
      // Experts play just under the audible creak: close at 0.75-1.0 x quiet (perfect 0.95 x), open as R1 x quiet/8.
      const cq = T.masterCloseQuiet > 0 ? T.masterCloseQuiet : (T.closeQuietSpeed > 0 ? T.closeQuietSpeed : T.quietSpeed);
      const close = skill === 'perfect' ? [0.95 * cq, 0.95 * cq] : [0.75 * cq, cq];
      this.p = Object.assign({}, p, { open: p.open.map((x) => x * kl), close, drag: p.drag.map((x) => x * kd) });
      // With a jingling bag they leave the copper (base value < 15) unless nothing else is left.
      this.skipCheap = T.jinglePerItem > 0;
    }
    this.o = P.shutTarget; this.speed = 0; this.lastChest = -1; this.mode = 'open';
    this.openSpeed = 6; this.closeSpeed = 10; this.slam = false; this.slamSpeed = 0;
    this.frozen = false; this.freezeDecided = false; this.obey = true; this.wait = 0; this.drag = null; this.nextID = 1;
  }
  lidOut() { const a = angleFor(this.o); return { openness: this.o, speed: this.speed, inShutZone: a <= T.shutZoneAngle, tooWide: a > T.tooWideAngle }; }
  rollChest() {
    this.openSpeed = this.rng.range(this.p.open[0], this.p.open[1]);
    this.closeSpeed = this.rng.range(this.p.close[0], this.p.close[1]);
    this.slam = this.rng.unit() < this.p.slamChance;
    this.slamSpeed = this.rng.range(this.p.slam[0], this.p.slam[1]);
  }
  moveLid(target, degPerSec, dt) {
    let step = degPerSec / LID_TRAVEL() * dt;
    // R7 stick-slip: a stroke from still breaks away with a jump (one draw from the slip stream per stroke).
    if (this.stillBefore && this.p.slip[1] > 0 && Math.abs(target - this.o) > 1e-9) {
      step = Math.max(step, this.slipRng.range(this.p.slip[0], this.p.slip[1]) / LID_TRAVEL());
    }
    this.stillBefore = false;
    const before = this.o;
    if (Math.abs(target - this.o) <= step) this.o = target; else this.o += Math.sign(target - this.o) * step;
    this.speed = dt > 0 ? Math.abs(this.o - before) * LID_TRAVEL() / dt : 0;
    return this.o === target;
  }
  wanted(snap) {
    const inChest = snap.loot.filter((s) => s.place === 'inChest');
    let reach = this.p.reach;
    if (this.lured && inChest.some((s) => s.item.kind === 'relic')) reach = 1;
    let w = inChest.filter((s) => s.item.depth <= reach);
    if (this.skipCheap) { const rich = w.filter((s) => s.item.kind !== 'copper'); if (rich.length > 0) w = rich; }
    if (w.length > 0) return w;
    // Nothing within reach: only then (bag empty, nothing held) does it go deeper, so it never gets stuck.
    const inHand = snap.loot.some((s) => s.place === 'inBag' || s.place === 'held');
    return inHand ? [] : inChest;
  }
  openTarget(snap) {
    const w = this.wanted(snap); if (w.length === 0) return null;
    let d = 0; for (const s of w) d = Math.max(d, s.item.depth);
    return Math.min(1, d + T.grabLight * T.lightRamp + P.openMargin);
  }
  step(dt, snap) {
    const touches = [];
    this.stillBefore = !(this.speed > 0);
    this.speed = 0;
    if (snap.phase !== 'ready' && snap.phase !== 'looting') {
      if (this.drag) { touches.push({ phase: 'ended', id: this.drag.id, x: this.drag.x, y: this.drag.y }); this.drag = null; }
      this.frozen = false; this.freezeDecided = false;
      return { lid: this.lidOut(), touches };
    }
    const idx = snap.chestIndex;
    if (idx !== this.lastChest) {
      if (T.relicGlimmer && (this.skill === 'novice' || this.skill === 'casual')) {
        if (!this.lureRng) this.lureRng = new SeededRandom(0x6117AE5n ^ BigInt(this.skill.length));
        this.lured = this.lureRng.unit() < (this.skill === 'novice' ? T.lureNovice : T.lureCasual);
      }
      this.lastChest = idx; this.rollChest(); this.mode = this.o > P.shutTarget + 0.04 ? 'settle' : 'open'; this.wait = 0; }
    // freeze
    const slamming = this.mode === 'close' && this.slam;
    if (!this.frozen) {
      if (snap.stage >= this.p.freezeStage) {
        if (!this.freezeDecided) { this.freezeDecided = true; this.obey = this.rng.unit() < this.p.freezeObey; }
        if (this.obey && !slamming) this.frozen = true;
      } else this.freezeDecided = false;
    } else if (snap.noise < Math.max(this.p.unfreeze, (T.adaptPilots ? snap.jingle + 0.04 : 0))) { this.frozen = false; this.freezeDecided = false; this.wait = this.p.reaction; }
    if (this.frozen) return { lid: this.lidOut(), touches };
    if (this.wait > 0) this.wait -= dt;
    // the held drag
    if (this.drag) {
      const held = snap.loot.find((s) => s.item.id === this.drag.item);
      if (!held || held.place !== 'held' || held.touch !== this.drag.id) {
        touches.push({ phase: 'ended', id: this.drag.id, x: this.drag.x, y: this.drag.y }); this.drag = null;
      } else {
        const dx = this.drag.tx - this.drag.x, dy = this.drag.ty - this.drag.y; const dist = Math.hypot(dx, dy);
        const stepLen = this.drag.v * dt;
        if (dist <= stepLen) {
          this.drag.x = this.drag.tx; this.drag.y = this.drag.ty;
          touches.push({ phase: 'moved', id: this.drag.id, x: this.drag.x, y: this.drag.y });
          touches.push({ phase: 'ended', id: this.drag.id, x: this.drag.x, y: this.drag.y });
          this.drag = null; this.wait = this.p.reaction;
        } else {
          this.drag.x += dx / dist * stepLen; this.drag.y += dy / dist * stepLen;
          touches.push({ phase: 'moved', id: this.drag.id, x: this.drag.x, y: this.drag.y });
        }
      }
    }
    const bagHas = snap.loot.some((s) => s.place === 'inBag');
    // R2: adapted expert/perfect bank once the bag jingles too loudly (the new push-your-luck call).
    if (T.adaptPilots && T.jinglePerItem > 0 && (this.skill === 'expert' || this.skill === 'perfect') && bagHas && !this.drag
        && this.mode !== 'close' && this.mode !== 'settle' && snap.jingle >= (this.skill === 'expert' ? T.greedExpert : T.greedPerfect)) this.mode = 'close';
    // torch awareness: bank what's in hand before the torch goes out
    if (this.p.torchAware && snap.torchOn && bagHas && this.mode !== 'close' && this.mode !== 'settle') {
      const need = this.o * LID_TRAVEL() / this.closeSpeed + T.shutHoldSeconds + P.torchMargin;
      if (snap.torchRemaining < need && !this.drag) this.mode = 'close';
    }
    // lid
    if (this.mode === 'settle') {
      if (this.moveLid(P.shutTarget, this.closeSpeed, dt)) this.mode = 'open';
    } else if (this.mode === 'open') {
      const target = this.openTarget(snap);
      if (target !== null && this.o < target - 1e-9) {
        if (this.p.concurrent || !this.drag) this.moveLid(target, this.openSpeed, dt);
      } else this.mode = 'collect';
    } else if (this.mode === 'collect') {
      const w = this.wanted(snap);
      const anyGrab = w.some((s) => s.grabbable);
      if (!anyGrab && !this.drag) {
        if (w.length > 0) this.mode = 'open';
        else if (bagHas && this.wait <= 0) this.mode = 'close';
        else if (!bagHas) this.mode = 'open';
      }
    } else if (this.mode === 'close') {
      if (!bagHas && !this.drag) this.mode = 'open';
      else this.moveLid(P.shutTarget, this.slam ? this.slamSpeed : this.closeSpeed, dt);
    }
    // start a drag
    if (!this.drag && this.wait <= 0 && (this.mode === 'collect' || (this.mode === 'open' && this.p.concurrent))) {
      const cands = this.wanted(snap).filter((s) => s.grabbable);
      if (cands.length > 0) {
        let best = cands[0];
        for (const s of cands) {
          if (this.p.frontFirst ? s.y > best.y : pilotWorth(s) > pilotWorth(best)) best = s;
        }
        const v = this.rng.range(this.p.drag[0], this.p.drag[1]);
        const drop = this.rng.unit() < this.p.drop;
        const jitter = this.rng.range(-P.bagJitter, P.bagJitter);
        const tx = drop ? best.x : Math.min(Math.max(best.x + jitter, P.bagMinX), P.bagMaxX);
        const ty = drop ? P.dropY : P.bagY;
        this.drag = { id: this.nextID++, item: best.item.id, x: best.x, y: best.y, tx, ty, v };
        touches.push({ phase: 'began', id: this.drag.id, x: best.x, y: best.y });
      }
    }
    return { lid: this.lidOut(), touches };
  }
}
function pilotWorth(s) { return s.item.kind === 'oil' ? 60 : s.item.value; }

function snapshotOf(s) {
  return {
    phase: s.phase, chestIndex: s.chest.index, stage: s.stage, noise: s.noise, torchRemaining: s.torch, torchOn: s.opt.torch, jingle: s.jingleFloor(),
    loot: s.loot.map((l) => ({ item: l.item, x: l.x, y: l.y, place: l.place, touch: l.touch, grabbable: l.grabbable })),
  };
}

// MARK: Harness (mirror of HushTests/BalanceTests.swift)
function runOne(skill, seed, extra) {
  // R12: noise= scales every run; extra.found carries the Codex between career runs, extra.noiseScale a grace.
  const session = new HeistSession(seed, Object.assign({ sensitivity: args.sensitivity || 'normal', noiseScale: Number(args.noise || 1) }, extra || {}));
  const pilot = new ThiefPilot(skill, BigInt.asUintN(64, BigInt(seed) * 7n + 1n));
  const dt = 1 / 60; let t = 0; let frames = 0; let maxNoise = 0; let stirs = 0;
  const use = { moment: 0, open: 0, close: 0, drag: 0, frozen: 0, idle: 0 }; let firstChestBitten = false;
  while (session.phase !== 'finished' && frames < 60 * 600) {
    const out = pilot.step(dt, snapshotOf(session));
    for (const tc of out.touches) {
      const p = { x: tc.x, y: tc.y };
      if (tc.phase === 'began') session.touchBegan(tc.id, p, t);
      else if (tc.phase === 'moved') session.touchMoved(tc.id, p, t);
      else session.touchEnded(tc.id, p, t);
    }
    const ev = session.step(dt, out.lid);
    for (const e of ev) {
      if (e.e === 'stageChanged' && e.from === ASLEEP && e.to === STIRRING) stirs += 1;
      if (e.e === 'bitten' && session.index === 0) firstChestBitten = true;
    }
    const ph = session.phase;
    if (ph === 'banked' || ph === 'bitten' || ph === 'torchOut' || ph === 'finished') use.moment += dt;
    else if (pilot.frozen) use.frozen += dt;
    else if (pilot.drag) use.drag += dt;
    else if (pilot.speed > 0.05 && pilot.mode === 'open') use.open += dt;
    else if (pilot.speed > 0.05) use.close += dt;
    else use.idle += dt;
    maxNoise = Math.max(maxNoise, session.noise);
    t += dt; frames += 1;
  }
  const logOK = session.chestLog.length === session.chestsOpened && session.chestLog.reduce((a, c) => a + c.value, 0) === session.banked;
  return { relicIDs: session.relics.slice(), logOK, chainBreaks: session.chainBreaks, use, firstChestBitten, bestChain: session.bestChain, goldens: session.goldens, goldenBanked: session.goldenBanked, chainGold: session.chainGold, gold: session.banked, seconds: session.time, banked: session.chestsBanked, opened: session.chestsOpened, bites: session.bites, hushed: session.hushed, relics: session.relics.length, lost: session.lostToBites, stirs, capped: session.phase !== 'finished' };
}
function pct(a, p) { if (a.length === 0) return 0; const s = a.slice().sort((x, y) => x - y); const pos = (s.length - 1) * p; const lo = Math.floor(pos); const hi = Math.min(s.length - 1, lo + 1); return s[lo] + (s[hi] - s[lo]) * (pos - lo); }

// MARK: Targets (mirror of HushTests/BalanceTests.swift: medians, with bands around the R2 table)
//   R2 table (40 seeds): novice ~1,635 gold / 5 chests / 3 bites; casual ~3,945 / 8 / 0 bites / 2 Hushed;
//   expert ~10,847 / 13; perfect ~11,553 / never bitten. 8 seeds: novice >= 1,000 gold and >= 3 chests.
//   R7: casual (real hands) banks more but Hushes less: gold 3,500-7,000, banked 6-12, Hushed >= 0.5.
const BANDS = {
  novice: { gold: [1000, 2600], banked: [3, 8], bites: [1, 6] },
  casual: { gold: [3500, 7000], banked: [6, 12], bites: [0, 0.5], hushed: [0.5, 5], seconds: [90, 160] },
  expert: { gold: [8000, 14000], banked: [10, 16], bites: [0, 1], hushed: [8, 16] },
  perfect: { gold: [8500, 15000], banked: [10, 16], hushed: [9, 16] },
};
// R12: bands=r12 widens the expert/perfect gold bands for the chainMax 8 proposal (REVIEW-6-retention change 3).
if (args.bands === 'r12') { BANDS.expert.gold = [8000, 16000]; BANDS.perfect.gold = [8500, 17000]; }
function medians(runs) {
  const m = (f) => pct(runs.map(f), 0.5);
  return { gold: m((r) => r.gold), seconds: m((r) => r.seconds), banked: m((r) => r.banked), bites: m((r) => r.bites),
    hushed: m((r) => r.hushed), relics: m((r) => r.relics), maxBites: Math.max(...runs.map((r) => r.bites)),
    capped: runs.filter((r) => r.capped).length, logBad: runs.filter((r) => !r.logOK).length };
}
function checks(med) {
  const out = [];
  for (const sk of Object.keys(BANDS)) {
    const m = med[sk]; if (!m) continue;
    for (const [k, [lo, hi]] of Object.entries(BANDS[sk])) out.push([`${sk} ${k} ${lo}-${hi} (${m[k]})`, m[k] >= lo && m[k] <= hi]);
    out.push([`${sk} never capped, chest log adds up`, m.capped === 0 && m.logBad === 0]);
  }
  if (med.perfect) out.push(['perfect never bitten (max)', med.perfect.maxBites === 0]);
  if (med.novice && med.casual) out.push(['novice < casual (gold)', med.novice.gold < med.casual.gold]);
  if (med.casual && med.expert) out.push(['casual < expert (gold)', med.casual.gold < med.expert.gold]);
  if (med.expert && med.perfect) out.push(['perfect >= 0.95 x expert (gold)', med.perfect.gold >= 0.95 * med.expert.gold]);
  return out;
}

function main() {
  const seeds = Number(args.seeds || 8);
  const base = Number(args.base || 1000), stride = Number(args.stride || 7919);
  const skills = (args.skills || 'novice,casual,expert,perfect').split(',');
  if (args.career) {
    // R12 (REVIEW-6-retention): a player's first N Runs in a row. The Codex (found set), lifetime gold, best and badges
    // carry over. plan=novice,casual,casual repeats its last entry. graceRuns=k graceNoise=x: the first k runs play at
    // noise x (an App-side beginner grace). Reports the median run on which each milestone first lands, over players=.
    const N = Number(args.career), players = Number(args.players || 40);
    const plan = (args.plan || 'casual').split(',');
    const graceList = args.grace ? args.grace.split(',').map(Number) : [];  // grace=0.8,0.9: run k plays at noise graceList[k-1]
    const graceRuns = Number(args.graceRuns || 0), graceNoise = Number(args.graceNoise || 1);
    const RANKS = [0, 1000, 3000, 7000, 14000, 25000, 42000, 66000, 100000, 150000, 220000, 320000];
    const rankOf = (g) => { let r = 0; for (let i = 0; i < RANKS.length; i++) if (g >= RANKS[i]) r = i; return r; };
    const ms = {}; const note = (k, run) => { (ms[k] = ms[k] || []).push(run); };
    const perRun = [];
    for (let p = 0; p < players; p++) {
      const found = new Set(); let life = 0, best = 0; const badges = new Set(); const seen = {};
      const first = (k, run) => { if (!seen[k]) { seen[k] = run; note(k, run); } };
      for (let r = 1; r <= N; r++) {
        const skill = plan[Math.min(r - 1, plan.length - 1)];
        const seed = 500000 + 7919 * (p * 1000 + r);
        const extra = { found: [...found] }; if (r <= graceRuns) extra.noiseScale = graceNoise; if (r <= graceList.length) extra.noiseScale = graceList[r - 1];
        const x = runOne(skill, seed, extra);
        const rb = rankOf(life); life += x.gold; const ra = rankOf(life);
        let nr = 0; for (const id of x.relicIDs) if (!found.has(id)) { found.add(id); nr++; }
        const nb = x.gold > best && best > 0; best = Math.max(best, x.gold);
        const want = { firstHaul: x.banked >= 1, notAPeep: x.hushed >= 1, firstRelic: found.size >= 1, fiveChests: x.banked >= 5,
          midas: x.goldenBanked >= 1, heavyBag: x.gold >= 3000, hoard: x.gold >= 8000, untouchable: x.bites === 0 && x.banked >= 3,
          hushChain: x.bestChain >= 5, curator: found.size >= 12, fullCodex: found.size >= 24, fortune: life >= 50000 };
        let nbad = 0; for (const [k, ok] of Object.entries(want)) if (ok && !badges.has(k)) { badges.add(k); nbad++; first('badge:' + k, r); }
        for (let k = rb + 1; k <= ra; k++) first('rank' + (k + 1), r);
        if (x.relicIDs.length) first('firstRelic', r);
        if (x.goldens > 0) first('firstGoldenSeen', r);
        if (x.goldenBanked > 0) first('firstGoldenBanked', r);
        if (x.bestChain >= 2) first('firstChain2', r);
        if (x.bites > 0) first('firstBite', r);
        for (const c of [6, 12, 18, 24]) if (found.size >= c) first('codex' + c, r);
        const row = perRun[r - 1] = perRun[r - 1] || { gold: [], rankUps: [], relics: [], badges: [], best: [], bites: [], secs: [], hushed: [] };
        row.gold.push(x.gold); row.rankUps.push(ra - rb); row.relics.push(nr); row.badges.push(nbad); row.best.push(nb ? 1 : 0);
        row.bites.push(x.bites); row.secs.push(x.seconds); row.hushed.push(x.hushed);
      }
    }
    console.log(`CAREER plan=${plan.join(',')} runs=${N} players=${players}${graceRuns ? ` grace=${graceRuns}x${graceNoise}` : ''}${graceList.length ? ` grace=${graceList}` : ''}`);
    const show = Math.min(N, Number(args.show || 6));
    const avg = (a) => (a.reduce((x, y) => x + y, 0) / a.length).toFixed(2);
    for (let r = 0; r < show; r++) {
      const w = perRun[r];
      console.log(`  run ${r + 1}: gold med ${pct(w.gold, 0.5).toFixed(0)} | rank-ups ${avg(w.rankUps)} | new relics ${avg(w.relics)} | new badges ${avg(w.badges)} | new best ${avg(w.best)} | bites ${avg(w.bites)} | hushed ${avg(w.hushed)} | ${pct(w.secs, 0.5).toFixed(0)} s`);
    }
    if (N > show) {
      const tail = (lo, hi) => { const rows = perRun.slice(lo, hi); const f = (k) => avg(rows.flatMap((w) => w[k])); return `runs ${lo + 1}-${hi}: rank-ups/run ${f('rankUps')} | new relics/run ${f('relics')} | new badges/run ${f('badges')} | new best/run ${f('best')}`; };
      for (const [lo, hi] of [[6, 10], [10, 20], [20, 30], [30, 45], [45, 60]]) if (hi <= N) console.log('  ' + tail(lo, hi));
    }
    const keys = Object.keys(ms).sort((a, b) => pct(ms[a], 0.5) - pct(ms[b], 0.5));
    for (const k of keys) console.log(`  ${k.padEnd(24)} ${String(ms[k].length).padStart(3)}/${players}  run p25/med/p75 ${pct(ms[k], 0.25).toFixed(0)}/${pct(ms[k], 0.5).toFixed(0)}/${pct(ms[k], 0.75).toFixed(0)}`);
    return;
  }
  if (args.attract) {
    // Attract mode (torch off, no bites) must never stall: chests banked in 600 s per skill (CoreTests: >= 4 in 120 s).
    for (const sk of skills) {
      const session = new HeistSession(7, { torch: false, bites: false });
      const pilot = new ThiefPilot(sk, 7n);
      const dt = 1 / 60; let t = 0; let at120 = 0;
      for (let f = 0; f < 60 * 600; f++) {
        const out = pilot.step(dt, snapshotOf(session));
        for (const tc of out.touches) {
          const p = { x: tc.x, y: tc.y };
          if (tc.phase === 'began') session.touchBegan(tc.id, p, t); else if (tc.phase === 'moved') session.touchMoved(tc.id, p, t); else session.touchEnded(tc.id, p, t);
        }
        session.step(dt, out.lid); t += dt;
        if (f === 60 * 120 - 1) at120 = session.chestsBanked;
      }
      console.log(`ATTRACT skill=${sk} banked@120s=${at120} banked@600s=${session.chestsBanked} bites=${session.bites}`);
    }
    return;
  }
  if (args.windows) {
    // Robustness: the medians of N disjoint windows of `seeds` seeds (window w starts at seed index w*seeds).
    const n = Number(args.windows); const per = {}; let fails = 0; const failNames = {};
    for (let w = 0; w < n; w++) {
      const med = {};
      for (const sk of skills) {
        const runs = []; for (let i = 0; i < seeds; i++) runs.push(runOne(sk, base + (w * seeds + i) * stride));
        med[sk] = medians(runs); (per[sk] = per[sk] || []).push(med[sk]);
      }
      const bad = checks(med).filter(([, ok]) => !ok);
      if (bad.length) { fails += 1; for (const [name] of bad) { const key = name.replace(/ \(.*\)$/, ''); failNames[key] = (failNames[key] || 0) + 1; } }
    }
    for (const sk of skills) {
      const f = (k) => { const a = per[sk].map((m) => m[k]); return `${k} ${pct(a, 0).toFixed(1)}..${pct(a, 0.5).toFixed(1)}..${pct(a, 1).toFixed(1)}`; };
      console.log(`WINDOWS skill=${sk} n=${n}x${seeds}: ${['gold', 'banked', 'bites', 'hushed', 'seconds', 'maxBites'].map(f).join(' | ')}`);
    }
    console.log(`windows failing a check: ${fails}/${n}`, JSON.stringify(failNames));
    return;
  }
  const med = {};
  for (const sk of skills) {
    const runs = [];
    for (let i = 0; i < seeds; i++) {
      const seed = base + i * stride;
      const r = runOne(sk, seed); runs.push(r);
      if (args.verbose) console.log(`  ${sk} seed=${seed} gold=${r.gold} s=${r.seconds.toFixed(1)} banked=${r.banked}/${r.opened} bites=${r.bites} hushed=${r.hushed} relics=${r.relics} stirs=${r.stirs} chain=${r.bestChain} golden=${r.goldenBanked}/${r.goldens}`);
    }
    med[sk] = medians(runs);
    const g = runs.map((r) => r.gold), s = runs.map((r) => r.seconds), b = runs.map((r) => r.banked), bi = runs.map((r) => r.bites);
    const u = {}; for (const k of ['moment', 'open', 'close', 'drag', 'frozen', 'idle']) u[k] = pct(runs.map((r) => r.use[k]), 0.5).toFixed(1);
    const cb = runs.filter((r) => r.firstChestBitten).length;
    console.log(`  ${sk} use(s): moments=${u.moment} open=${u.open} close=${u.close} drag=${u.drag} frozen=${u.frozen} idle=${u.idle} | chest#1 bitten ${cb}/${runs.length} | lost=${pct(runs.map((r) => r.lost), 0.5).toFixed(0)} chainGold=${pct(runs.map((r) => r.chainGold), 0.5).toFixed(0)} bestChain=${pct(runs.map((r) => r.bestChain), 0.5).toFixed(1)} chainBreaks=${pct(runs.map((r) => r.chainBreaks), 0.5).toFixed(1)} golden seen/banked=${runs.reduce((a, r) => a + r.goldens, 0)}/${runs.reduce((a, r) => a + r.goldenBanked, 0)} | hushed p10-p90 ${pct(runs.map((r) => r.hushed), 0.1).toFixed(0)}-${pct(runs.map((r) => r.hushed), 0.9).toFixed(0)} | banked p10 ${pct(runs.map((r) => r.banked), 0.1).toFixed(0)}`);
    console.log(`HUSH-BAL skill=${sk} gold=${pct(g, 0.5).toFixed(0)} p10=${pct(g, 0.1).toFixed(0)} p90=${pct(g, 0.9).toFixed(0)} seconds=${pct(s, 0.5).toFixed(1)} (${Math.min(...s).toFixed(0)}-${Math.max(...s).toFixed(0)}) banked=${pct(b, 0.5).toFixed(1)} (${Math.min(...b)}-${Math.max(...b)}) bites=${pct(bi, 0.5).toFixed(1)} max=${Math.max(...bi)} hushed=${pct(runs.map((r) => r.hushed), 0.5).toFixed(1)} relics=${pct(runs.map((r) => r.relics), 0.5).toFixed(1)} stirs=${pct(runs.map((r) => r.stirs), 0.5).toFixed(1)} n=${runs.length}`);
  }
  for (const [name, ok] of checks(med)) console.log(`${ok ? 'PASS' : 'FAIL'} ${name}`);
}
main();
