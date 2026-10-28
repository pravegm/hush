// audio-probe.js — REVIEW-6 (feel/audio). A faithful Node port of Hush/Feedback/FeelSynth.swift's render loop
// (voices, modal bank, creak / snore / growl / motif / dungeon layers, DC blocker + peak limiter + tanh) and the
// FeelSoundBook recipes it needs, used to MEASURE levels, spectra, envelopes, the mix and the voice budget.
// Run: node tools/audio-probe.js            (all sections)
//      node tools/audio-probe.js creak      (one section: creak | shots | mix | voices | speed | haptic)
// Nothing here is shipped; it only reads numbers out of the Swift design.
//
// R12 (feel): every value the REVIEW-6 top-10 changed lives in CFG below, as the R11 (shipped before) and R12 (now in
// the Swift) sets. The default is R12, matching the code; `--r11` runs any section on the old values, and
// `node tools/audio-probe.js compare` prints the before → after table quoted in design/notes/feel-R12.md.
//      node tools/audio-probe.js tests     (the FeelTests bounds the R12 values must meet, on the R12 values)
'use strict';

const SR = 48000;
const TWO_PI = 2 * Math.PI;

const CFG = {
  r11: {
    name: 'R11', voiceCount: 48, ringLife: 7, groanQ: 5, bodyGain: 0.05, grainGain: 2.0, grainBase: 12, master: 1.25,
    coinGains: [0.09, 0.06, 0.035, 0.045], coinVary: false, kaChord: [293.66, 369.99, 440], kaGlass: 0.04,
    heart: { a: [120, 62], b: [110, 60], harmonics: 4, mode: 'lp', cut: [260, 240] },
    wake: { notes: [146.83, 155.56], harmonics: 3, gain: 0.05 },
    chomp: { thumpGain: 0.36, thumpEnd: 48, thumpHarm: 6, subNoise: 0.34, crack: 0.26, crackDecay: 0.02, wood: 0.26, woodPartials: 4,
      woodDecay: 0.05, crunch: 0, teeth1: 0.2, teeth2: 0.17, teethDecay: 0.012, teethDecay2: 0.01 },
    restingShare: 0.8, bagVary: false, duckGlide: 0.35, duckHold: 0, duckShare: 0.8, loudLevel: 0.8, topLevel: 1,
    hapticExp: 1, burst: 0.055, layered: false, jitter: 0.15, quietTick: 0.18, biteSnap: 0.12, softHeart: false,
  },
  r12: {
    name: 'R12', voiceCount: 96, ringLife: 5, groanQ: 3, bodyGain: 0.18, grainGain: 3.5, grainBase: 30, master: 1.8,
    coinGains: [0.16, 0.11, 0.065, 0.08], coinVary: true, kaChord: [587.33, 739.99, 880], kaGlass: 0.07,
    heart: { a: [150, 80], b: [140, 78], harmonics: 8, mode: 'bp', cut: [500, 480] },
    wake: { notes: [293.66, 311.13], harmonics: 5, gain: 0.06 },
    // REVIEW-6 #9 asked for thump 0.2 / sub 0.2 / crack 0.34 / wood 0.36 / crunch 0.32 (decays unchanged). With #2 and #3
    // the 45°/s creak rose more than that CHOMP (it lost the bite by 2.2 dB on the speaker), so R12 goes further: less
    // sub, and longer, brighter mids (see feel-R12.md).
    chomp: { thumpGain: 0.14, thumpEnd: 70, thumpHarm: 8, subNoise: 0.12, crack: 0.4, crackDecay: 0.05, wood: 0.4, woodPartials: 5,
      woodDecay: 0.08, crunch: 0.4, crunchDecay: 0.08, teeth1: 0.3, teeth2: 0.26, teethDecay: 0.018, teethDecay2: 0.018 },
    restingShare: 0.35, bagVary: true, duckGlide: 0.03, duckHold: 0.12, duckShare: 0.35, loudLevel: 0.68, topLevel: 0.7,
    hapticExp: 0.6, burst: 0.04, layered: true, jitter: 0.30, quietTick: 0.3, biteSnap: 0.06, softHeart: true,
  },
};
const GRUMBLE = { tone: 0.05, noise: 0.09 };
let P = CFG[process.argv.includes('--r11') ? 'r11' : 'r12'];
function using(name, fn) { const keep = P; P = CFG[name]; try { return fn(); } finally { P = keep; } }

// ---------- seeded dice (stand-in for FeelDice; only the distribution matters) ----------
function makeDice(seed) {
  let s = seed >>> 0;
  const unit = () => {
    s = (s + 0x6D2B79F5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  return { unit, float: (a, b) => a + (b - a) * unit(), seed32: () => ((unit() * 4294967296) >>> 0) | 1 };
}

// ---------- SVF (Zavalishin), as FeelSVF ----------
class SVF {
  constructor() { this.a1 = 0; this.a2 = 0; this.a3 = 0; this.k = 1; this.ic1 = 0; this.ic2 = 0; }
  tune(cutoff, q) {
    const f = Math.min(Math.max(cutoff, 20), SR * 0.45);
    const g = Math.tan(Math.PI * f / SR);
    this.k = 1 / Math.max(q, 0.1);
    this.a1 = 1 / (1 + g * (g + this.k));
    this.a2 = g * this.a1;
    this.a3 = g * this.a2;
  }
  process(x, mode) {
    const v3 = x - this.ic2;
    const v1 = this.a1 * this.ic1 + this.a2 * v3;
    const v2 = this.ic2 + this.a2 * this.ic1 + this.a3 * v3;
    this.ic1 = 2 * v1 - this.ic1;
    this.ic2 = 2 * v2 - this.ic2;
    if (mode === 'lp') return v2;
    if (mode === 'bp') return v1 * this.k;
    return x - this.k * v1 - v2;
  }
}

function polyBlep(t, dt) {
  if (dt <= 0) return 0;
  if (t < dt) { const x = t / dt; return x + x - x * x - 1; }
  if (t > 1 - dt) { const x = (t - 1) / dt; return x * x + x + x + 1; }
  return 0;
}

const RATIOS = {
  chime: [1, 2.0, 3.0, 4.2, 5.4, 6.8],
  bell: [1, 0.5, 1.19, 1.5, 2.0, 2.66],
  marimba: [1, 3.93, 9.3, 12.0, 15.2, 18.6],
  wood: [1, 2.6, 3.9, 5.4, 6.9, 8.6],
  glass: [1, 2.32, 4.25, 6.63, 9.38, 12.1],
  pluck: [1, 2.0, 3.005, 4.015, 5.03, 6.05],
};

function emptyBed() {
  return { master: 0, glide: 0.05, creak: 0, creakHz: 160, grainRate: 0, creakBright: 0.3, squeal: 0, squealHz: 1900,
    snore: 0, snorePeriod: 4.2, growl: 0, motif: 0, motifDensity: 1, drone: 0, dripRate: 0, crackle: 0,
    crackleRate: 0, rattle: 0, rattleRate: 0, grumble: 0 };
}

// ---------- the synth ----------
class Synth {
  constructor(opts = {}) {
    this.voiceCount = opts.voiceCount || P.voiceCount;
    this.groanGain = opts.groanGain ?? 0.11;
    this.bodyGain = opts.bodyGain ?? P.bodyGain;
    this.grainGain = opts.grainGain ?? P.grainGain;
    this.squealGain = opts.squealGain ?? 0.06;
    this.groanQ = opts.groanQ ?? P.groanQ;
    this.ceiling = opts.ceiling ?? 0.9;
    this.ringLife = opts.ringLife ?? P.ringLife;
    this.voices = [];
    for (let i = 0; i < this.voiceCount; i++) this.voices.push({ active: false });
    this.bed = emptyBed(); this.target = emptyBed();
    this.glideK = 1 - Math.exp(-1 / (0.05 * SR));
    this.noiseState = 0x2545F491;
    this.retuneCounter = 0;
    this.creakPhase = 0; this.creakSlip = 0.8; this.creakJitter = 1;
    this.wobbleValue = 0; this.wobbleTarget = 0; this.wobbleCountdown = 0;
    this.groanFilter = new SVF(); this.bodyFilter = new SVF(); this.grainFilter = new SVF();
    this.grainEnv = 0; this.grainAmp = 0; this.grainDecay = 0.99;
    this.squealPhase = 0; this.squealVibrato = 0; this.squealAmp = 0;
    this.snorePhase = 0; this.snoreCycle = 4.2; this.snoreTonePhase = 0; this.snoreFlutter = 0;
    this.inhaleFilter = new SVF(); this.exhaleFilter = new SVF(); this.snoreToneFilter = new SVF();
    this.growlPhase = 0; this.growlRough = 0; this.growlLFO = 0;
    this.growlNoiseFilter = new SVF(); this.growlToneFilter = new SVF();
    this.motifCountdown = 0; this.motifStep = -1;
    this.dA = 0; this.dB = 0; this.dC = 0; this.droneLFO = 0;
    this.airFilter = new SVF(); this.flameFilter = new SVF(); this.crackleFilter = new SVF(); this.crackleEnv = 0;
    this.rattleA = new SVF(); this.rattleB = new SVF(); this.rattleEnv = 0;
    this.grumblePhase = 0; this.grumbleTonePhase = 0; this.grumbleFlutter = 0; this.grumbleNoise = new SVF(); this.grumbleTone = new SVF();
    this.dcIn = 0; this.dcOut = 0; this.envelope = 0;
    this.wobbleStep = 1 - Math.exp(-1 / (0.05 * SR));
    this.squealAmpStep = 1 - Math.exp(-1 / (0.0015 * SR));
    this.crackleDecay = Math.exp(-1 / (0.0016 * SR));
    this.rattleDecay = Math.exp(-1 / (0.0028 * SR));
    this.envelopeRelease = Math.exp(-1 / (0.08 * SR));
    this.dcCoefficient = 1 - 2 * Math.PI * 30 / SR;
    this.motifStepSamples = Math.max(Math.floor(SR * 60 / 92 / 2), 1);
    this.bodyFilter.tune(1100, 2.5); this.grainFilter.tune(1200, 3.5);
    this.inhaleFilter.tune(420, 1.3); this.exhaleFilter.tune(900, 0.9); this.snoreToneFilter.tune(600, 1.2);
    this.growlNoiseFilter.tune(260, 3); this.growlToneFilter.tune(420, 2);
    this.airFilter.tune(240, 0.7); this.flameFilter.tune(1300, 0.5); this.crackleFilter.tune(2400, 0.7);
    this.rattleA.tune(3150, 12); this.rattleB.tune(4720, 12);
    this.grumbleNoise.tune(240, 1.2); this.grumbleTone.tune(320, 1.5);
    this.retune();
    this.peak = 0;
    this.stolen = []; // labels of voices overwritten while still active
    this.layerTap = null; // optional per-sample layer probe
  }
  nextNoise() {
    let s = this.noiseState;
    s ^= s << 13; s >>>= 0; s ^= s >>> 17; s ^= s << 5; s >>>= 0;
    this.noiseState = s;
    return (s | 0) / 2147483647;
  }
  unit() { return (this.nextNoise() + 1) * 0.5; }
  retune() {
    const pitch = Math.min(Math.max(this.bed.creakHz, 40), 900) * (1 + 0.09 * this.wobbleValue);
    const bright = Math.min(Math.max(this.bed.creakBright, 0), 1);
    this.groanFilter.tune(pitch * (2.4 + 2 * bright), this.groanQ);
  }
  setBed(b) { this.target = { ...b }; const g = isFinite(b.glide) ? Math.max(b.glide, 0.004) : 0.05; this.glideK = 1 - Math.exp(-1 / (g * SR)); }
  play(cmds) { for (const c of cmds) this.start(c); }

  start(c) {
    let slot = -1, oldest = -1, oldestAge = -1;
    for (let i = 0; i < this.voiceCount; i++) {
      if (!this.voices[i].active) { slot = i; break; }
      if (this.voices[i].age > oldestAge) { oldestAge = this.voices[i].age; oldest = i; }
    }
    if (slot < 0) { slot = oldest; this.stolen.push({ victim: this.voices[slot].label, by: c.label, victimDelay: this.voices[slot].delay }); }
    if (slot < 0) return;
    const v = { active: true, kind: c.type, delay: 0, age: 0, attack: 1, length: 0, decayRate: 1, level: 1, gain: 0, label: c.label || c.type };
    const d = c.delay || 0;
    v.delay = Math.floor(Math.max(d, 0) * SR);
    if (c.type === 'noise') {
      v.attack = Math.max(Math.floor((c.attack ?? 0.002) * SR), 1);
      v.decayRate = Math.exp(-1 / Math.max(c.decay * SR, 1));
      v.length = v.attack + Math.floor(c.decay * SR * 7);
      v.gain = c.gain; v.mode = c.mode; v.q = c.q ?? 0.8; v.cutoff = c.cutoff; v.cutoffEnd = c.to ?? c.cutoff;
      v.sweepSamples = Math.abs(v.cutoffEnd - v.cutoff) > 1 ? Math.max(Math.floor((c.sweep || 0) * SR), 1) : 0;
      v.filter = new SVF(); v.filter.tune(v.cutoff, v.q);
    } else if (c.type === 'tone') {
      v.attack = Math.max(Math.floor((c.attack ?? 0.01) * SR), 1);
      v.length = Math.max(Math.floor(c.duration * SR), v.attack + 1);
      v.decayRate = Math.exp(-1 / Math.max(c.decay * SR, 1));
      v.gain = c.gain; v.f0 = c.start; v.f1 = c.end ?? c.start; v.glide = Math.max(Math.floor((c.glide ?? 0.1) * SR), 1);
      v.harmonics = Math.min(Math.max(c.harmonics || 1, 1), 8); v.vr = c.vibratoRate || 0; v.vd = c.vibratoDepth || 0;
      v.phase = 0; v.vphase = 0;
    } else if (c.type === 'drop') {
      v.attack = Math.max(Math.floor(0.0015 * SR), 1);
      v.decayRate = Math.exp(-1 / Math.max(c.decay * SR, 1));
      v.length = v.attack + Math.floor(c.decay * SR * 6);
      v.gain = c.gain; v.freq = Math.min(Math.max(c.frequency, 40), SR * 0.4);
      v.chirp = Math.pow(Math.max(c.chirp ?? 1.5, 0.25), 1 / Math.max(v.length, 1)); v.phase = 0;
    } else if (c.type === 'fm') {
      v.attack = Math.max(Math.floor((c.attack ?? 0.0008) * SR), 1);
      v.decayRate = Math.exp(-1 / Math.max(c.decay * SR, 1));
      v.length = v.attack + Math.floor(c.decay * SR * 7);
      v.gain = c.gain; v.freq = Math.min(Math.max(c.carrier, 40), SR * 0.42);
      v.ratio = Math.max(c.ratio, 0.01); v.index = Math.max(c.index, 0);
      v.indexRate = Math.exp(-1 / Math.max(c.indexDecay * SR, 1)); v.phase = 0; v.mphase = 0;
    } else if (c.type === 'ring') {
      v.attack = Math.max(Math.floor(0.0005 * SR), 1);
      v.decayRate = 1;
      v.length = Math.min(Math.floor(c.decay * SR * this.ringLife), Math.floor(SR * 6));
      v.gain = 1;
      const count = Math.min(Math.max(c.partials ?? 4, 1), 6);
      const br = Math.min(Math.max(c.brightness ?? 0.5, 0.05), 0.98);
      let total = 0; for (let n = 0; n < count; n++) total += Math.pow(br, n);
      let jit = ((c.seed ?? 1) | 1) >>> 0;
      v.p = [];
      for (let n = 0; n < count; n++) {
        jit ^= jit << 13; jit >>>= 0; jit ^= jit >>> 17; jit ^= jit << 5; jit >>>= 0;
        const detune = n === 0 ? 1 : 1 + 0.015 * ((jit % 2001) / 1000 - 1);
        const f = c.fundamental * RATIOS[c.kind][n] * detune;
        if (!(f > 20 && f < SR * 0.45)) { v.p.push({ re: 0, im: 0, c: 1, s: 0, d: 0 }); continue; }
        let tau = c.decay / (1 + 0.7 * n);
        if (c.kind === 'bell' && n === 1) tau = c.decay * 1.3;
        if (f > 2500 && f < 4500 && n > 0) tau *= 0.5;
        const w = TWO_PI * f / SR;
        v.p.push({ re: c.gain * Math.pow(br, n) / total * 1.6, im: 0, c: Math.cos(w), s: Math.sin(w), d: Math.exp(-1 / Math.max(tau * SR, 1)) });
      }
    }
    this.voices[slot] = v;
  }

  renderVoice(v) {
    if (v.delay > 0) { v.delay--; return 0; }
    const age = v.age; v.age++;
    if (age >= v.length) { v.active = false; return 0; }
    let env;
    if (age < v.attack) env = age / v.attack; else { v.level *= v.decayRate; env = v.level; }
    if (env < 0.0003 && age > v.attack) { v.active = false; return 0; }
    const left = v.length - age;
    const release = Math.min(left / (0.03 * SR), 1);
    switch (v.kind) {
      case 'noise': {
        if (v.sweepSamples > 0 && age % 32 === 0) {
          const pr = Math.min(age / v.sweepSamples, 1);
          v.filter.tune(v.cutoff * Math.pow(v.cutoffEnd / Math.max(v.cutoff, 1), pr), v.q);
        }
        return v.filter.process(this.nextNoise(), v.mode) * env * v.gain * release;
      }
      case 'tone': {
        const pr = Math.min(age / v.glide, 1);
        let f = v.f0 + (v.f1 - v.f0) * pr;
        if (v.vd > 0) { v.vphase += TWO_PI * v.vr / SR; if (v.vphase > TWO_PI) v.vphase -= TWO_PI; f *= 1 + v.vd * Math.sin(v.vphase); }
        v.phase += TWO_PI * f / SR; if (v.phase > TWO_PI) v.phase -= TWO_PI;
        let val = 0;
        for (let h = 1; h <= v.harmonics; h++) if (f * h < SR * 0.45) val += Math.sin(v.phase * h) / h;
        return val * env * v.gain * release;
      }
      case 'drop': {
        v.freq *= v.chirp; v.phase += TWO_PI * v.freq / SR; if (v.phase > TWO_PI) v.phase -= TWO_PI;
        return Math.sin(v.phase) * env * v.gain * release;
      }
      case 'fm': {
        v.mphase += TWO_PI * v.freq * v.ratio / SR; if (v.mphase > TWO_PI) v.mphase -= TWO_PI;
        v.phase += TWO_PI * v.freq / SR; if (v.phase > TWO_PI) v.phase -= TWO_PI;
        v.index *= v.indexRate;
        return Math.sin(v.phase + v.index * Math.sin(v.mphase)) * env * v.gain * release;
      }
      case 'ring': {
        let sum = 0;
        for (const p of v.p) { const ni = (p.re * p.s + p.im * p.c) * p.d; p.re = (p.re * p.c - p.im * p.s) * p.d; p.im = ni; sum += ni; }
        return sum * env * release;
      }
    }
    return 0;
  }

  renderCreak(parts) {
    const b = this.bed;
    this.wobbleCountdown--;
    if (this.wobbleCountdown <= 0) { this.wobbleTarget = 2 * this.unit() - 1; this.wobbleCountdown = Math.floor(SR * (0.04 + 0.08 * this.unit())) + 1; }
    this.wobbleValue += (this.wobbleTarget - this.wobbleValue) * this.wobbleStep;
    const pitch = Math.min(Math.max(b.creakHz, 40), 900) * (1 + 0.09 * this.wobbleValue);
    const dt = Math.min(pitch * this.creakJitter / SR, 0.25);
    this.creakPhase += dt;
    if (this.creakPhase >= 1) {
      this.creakPhase -= 1;
      if (this.unit() < 0.08) this.creakSlip = 0.15 + 0.15 * this.unit(); else this.creakSlip = 0.55 + 0.45 * this.unit();
      this.creakJitter = 1 + 0.07 * (2 * this.unit() - 1);
    }
    const saw = (2 * this.creakPhase - 1 - polyBlep(this.creakPhase, dt)) * this.creakSlip;
    const groan = this.groanFilter.process(saw, 'lp') * this.groanGain;
    const body = this.bodyFilter.process(saw, 'bp') * this.bodyGain;
    if (b.grainRate > 0.01 && this.unit() < b.grainRate / SR) {
      this.grainAmp = 0.35 + 0.65 * this.unit(); this.grainEnv = 1;
      this.grainDecay = Math.exp(-1 / ((0.0015 + 0.004 * this.unit()) * SR));
      const spread = Math.min(Math.max(0.7 * b.creakBright + 0.45 * this.unit() - 0.1, 0), 1);
      this.grainFilter.tune(600 * Math.pow(2500 / 600, spread), 3.5);
    }
    this.grainEnv *= this.grainDecay;
    const grain = this.grainFilter.process(this.nextNoise() * this.grainEnv * this.grainAmp, 'bp') * this.grainGain;
    let squeal = 0;
    if (b.squeal > 0.00002) {
      this.squealVibrato += TWO_PI * 6.5 / SR; if (this.squealVibrato > TWO_PI) this.squealVibrato -= TWO_PI;
      const wander = 1 + 0.012 * Math.sin(this.squealVibrato) + 0.02 * this.wobbleValue;
      const f = Math.min(Math.max(b.squealHz, 200), SR * 0.4) * wander;
      this.squealPhase += TWO_PI * f / SR; if (this.squealPhase > TWO_PI) this.squealPhase -= TWO_PI;
      this.squealAmp += (this.creakSlip - this.squealAmp) * this.squealAmpStep;
      squeal = Math.sin(this.squealPhase) * (0.4 + 0.6 * this.squealAmp) * this.squealGain * b.squeal;
    }
    if (parts) { parts.groan = groan * b.creak; parts.body = body * b.creak; parts.grain = grain * b.creak; parts.squeal = squeal; }
    return (groan + body + grain) * b.creak + squeal;
  }

  renderSnore() {
    this.snorePhase += 1 / (Math.max(this.snoreCycle, 1) * SR);
    if (this.snorePhase >= 1) { this.snorePhase -= 1; this.snoreCycle = Math.min(Math.max(this.bed.snorePeriod, 2), 8) * (0.85 + 0.3 * this.unit()); }
    let out = 0;
    if (this.snorePhase < 0.42) {
      const s = Math.sin(Math.PI * this.snorePhase / 0.42); const env = s * s;
      this.snoreFlutter += TWO_PI * 27 / SR; if (this.snoreFlutter > TWO_PI) this.snoreFlutter -= TWO_PI;
      const flutter = 0.45 + 0.55 * (0.5 + 0.5 * Math.sin(this.snoreFlutter));
      const dt = 95 / SR; this.snoreTonePhase += dt; if (this.snoreTonePhase >= 1) this.snoreTonePhase -= 1;
      const saw = 2 * this.snoreTonePhase - 1 - polyBlep(this.snoreTonePhase, dt);
      const tone = this.snoreToneFilter.process(saw, 'lp') * 0.08 * flutter;
      const breath = this.inhaleFilter.process(this.nextNoise(), 'bp') * 0.11 * flutter;
      out = (tone + breath) * env;
    } else if (this.snorePhase > 0.48 && this.snorePhase < 0.86) {
      const s = Math.sin(Math.PI * (this.snorePhase - 0.48) / 0.38);
      out = this.exhaleFilter.process(this.nextNoise(), 'bp') * 0.065 * s * s;
    }
    return out * this.bed.snore;
  }

  // R12 (founder): the robbed chest's grumble (FeelSynth.renderGrumble).
  renderGrumble() {
    this.grumblePhase += 1 / (5.5 * SR); if (this.grumblePhase >= 1) this.grumblePhase -= 1;
    const u = this.grumblePhase; let breath = 0; if (u < 0.62) { const x = Math.sin(Math.PI * u / 0.62); breath = x * x; }
    this.grumbleFlutter += TWO_PI * 11 / SR; if (this.grumbleFlutter > TWO_PI) this.grumbleFlutter -= TWO_PI;
    const flutter = 0.55 + 0.45 * (0.5 + 0.5 * Math.sin(this.grumbleFlutter));
    const dt = 62 / SR; this.grumbleTonePhase += dt; if (this.grumbleTonePhase >= 1) this.grumbleTonePhase -= 1;
    const saw = 2 * this.grumbleTonePhase - 1 - polyBlep(this.grumbleTonePhase, dt);
    const tone = this.grumbleTone.process(saw, 'lp') * GRUMBLE.tone; const noise = this.grumbleNoise.process(this.nextNoise(), 'bp') * GRUMBLE.noise;
    return (tone + noise) * flutter * breath * this.bed.grumble;
  }
  renderGrowl() {
    this.growlLFO += TWO_PI * 0.7 / SR; if (this.growlLFO > TWO_PI) this.growlLFO -= TWO_PI;
    this.growlRough += TWO_PI * 23 / SR; if (this.growlRough > TWO_PI) this.growlRough -= TWO_PI;
    const rough = 0.35 + 0.65 * (0.5 + 0.5 * Math.sin(this.growlRough));
    const drift = 1 + 0.06 * Math.sin(this.growlLFO);
    const dt = 78 * drift / SR; this.growlPhase += dt; if (this.growlPhase >= 1) this.growlPhase -= 1;
    const saw = 2 * this.growlPhase - 1 - polyBlep(this.growlPhase, dt);
    const tone = this.growlToneFilter.process(saw, 'lp') * 0.065;
    const noise = this.growlNoiseFilter.process(this.nextNoise(), 'lp') * 0.12;
    return (tone + noise) * rough * this.bed.growl;
  }

  static motifNote(step) {
    const m = { 0: 0, 2: 7, 4: 3, 6: 7, 8: 0, 10: 7, 12: 8, 13: 7, 14: 5, 15: 3, 16: -2, 18: 5, 20: 2, 22: 5, 24: -1, 26: 2, 28: 5, 29: 3, 30: 2, 31: -1 };
    return step in m ? m[step] : null;
  }
  static motifWeight(step) { if (step % 8 === 0) return 1; if (step % 4 === 0) return 0.8; if (step % 2 === 0) return 0.6; return 0.33; }
  runMotif() {
    this.motifCountdown--; if (this.motifCountdown > 0) return;
    this.motifCountdown = this.motifStepSamples;
    this.motifStep = (this.motifStep + 1) % 32;
    const note = Synth.motifNote(this.motifStep); if (note === null) return;
    const w = Synth.motifWeight(this.motifStep); if (w < 1.001 - this.bed.motifDensity) return;
    const f = 293.66 * Math.pow(2, note / 12);
    this.start({ type: 'ring', kind: 'pluck', fundamental: f, partials: 5, decay: 0.14, brightness: 0.42, gain: 0.075 * this.bed.motif * (w >= 1 ? 1 : 0.75), seed: this.motifStep * 7 + 3, label: 'motif' });
  }

  // Render n samples. `layers` (optional) collects per-layer pre-master sums for the mix table.
  render(n, out, offset = 0, layers = null) {
    const parts = layers ? {} : null;
    for (let i = 0; i < n; i++) {
      const b = this.bed, t = this.target, k = this.glideK;
      for (const key in t) if (key !== 'glide') b[key] += (t[key] - b[key]) * k;
      if (++this.retuneCounter >= 32) { this.retuneCounter = 0; this.retune(); }
      let s = 0, sC = 0, sS = 0, sG = 0, sD = 0, sV = 0;
      if (b.creak > 0.00002 || b.squeal > 0.00002) { sC = this.renderCreak(parts); s += sC; }
      if (b.snore > 0.00002) { sS = this.renderSnore(); s += sS; }
      if (b.growl > 0.00002) { sG = this.renderGrowl(); s += sG; }
      if (b.grumble > 0.00002) { const g = this.renderGrumble(); s += g; sS += g; }
      if (b.motif > 0.00002) this.runMotif(); else this.motifCountdown = 0;
      if (b.drone > 0.00002) {
        this.droneLFO += TWO_PI * 0.07 / SR; if (this.droneLFO > TWO_PI) this.droneLFO -= TWO_PI;
        this.dA += TWO_PI * 146.83 / SR; if (this.dA > TWO_PI) this.dA -= TWO_PI;
        this.dB += TWO_PI * 220.6 / SR; if (this.dB > TWO_PI) this.dB -= TWO_PI;
        this.dC += TWO_PI * 293.1 / SR; if (this.dC > TWO_PI) this.dC -= TWO_PI;
        const br = 0.75 + 0.25 * Math.sin(this.droneLFO);
        const hum = 0.5 * Math.sin(this.dA) + 0.3 * Math.sin(this.dB) * br + 0.16 * Math.sin(this.dC);
        const air = this.airFilter.process(this.nextNoise(), 'lp') * 0.5;
        sD += (hum * 0.026 * br + air * 0.024) * b.drone;
      }
      if (b.dripRate > 0.001 && this.unit() < b.dripRate / SR) {
        const f = 1100 + 1300 * this.unit(); const g = 0.035 + 0.04 * this.unit();
        this.start({ type: 'drop', frequency: f, chirp: 1.7, decay: 0.025 + 0.02 * this.unit(), gain: g, label: 'drip' });
        this.start({ type: 'drop', frequency: f * 0.98, chirp: 1.6, decay: 0.03, gain: g * 0.28, delay: 0.13 + 0.05 * this.unit(), label: 'drip' });
      }
      if (b.crackle > 0.00002) {
        if (this.unit() < b.crackleRate / SR) this.crackleEnv = 0.3 + 0.7 * this.unit();
        this.crackleEnv *= this.crackleDecay;
        const flame = this.flameFilter.process(this.nextNoise(), 'bp') * 0.04;
        const pop = this.crackleFilter.process(this.nextNoise() * this.crackleEnv, 'hp') * 0.26;
        sD += (flame + pop) * b.crackle;
      }
      s += sD;
      if (b.rattle > 0.00002) {
        if (this.unit() < b.rattleRate / SR) this.rattleEnv = 0.4 + 0.6 * this.unit();
        this.rattleEnv *= this.rattleDecay;
        if (this.rattleEnv > 0.0005) { const nn = this.nextNoise() * this.rattleEnv; s += (this.rattleA.process(nn, 'bp') + this.rattleB.process(nn, 'bp') * 0.7) * 0.9 * b.rattle; }
      }
      for (let j = 0; j < this.voiceCount; j++) { const v = this.voices[j]; if (v.active) { const x = this.renderVoice(v); s += x; sV += x; } }
      s *= b.master;
      const blocked = s - this.dcIn + this.dcCoefficient * this.dcOut; this.dcIn = s; this.dcOut = blocked;
      const mag = Math.abs(blocked);
      this.envelope = Math.max(mag, this.envelope * this.envelopeRelease);
      const drive = this.envelope > this.ceiling ? this.ceiling / this.envelope : 1;
      let shaped = Math.tanh(blocked * drive);
      shaped = Math.min(Math.max(shaped, -0.98), 0.98);
      if (Math.abs(shaped) > this.peak) this.peak = Math.abs(shaped);
      out[offset + i] = shaped;
      if (layers) {
        const m = b.master;
        layers.creak[offset + i] = sC * m; layers.snore[offset + i] = sS * m; layers.growl[offset + i] = sG * m;
        layers.dungeon[offset + i] = sD * m; layers.voices[offset + i] = sV * m;
        if (parts && parts.groan !== undefined) { layers.groan[offset + i] = parts.groan * m; layers.body[offset + i] = parts.body * m; layers.grain[offset + i] = parts.grain * m; layers.squeal[offset + i] = parts.squeal * m; }
      }
    }
  }
}

// ---------- FeelSoundBook (ported recipes) ----------
const Tuning = { quietSpeed: 14, closeQuietSpeed: 28, loudSpeed: 30 };
const SB = {
  softTop: 20, fullSpeed: 50, squealStart: 25, squealFull: 45, softLevel: 0.4, loudLevel: 0.8,
  smooth(x) { const u = Math.min(Math.max(x, 0), 1); return u * u * (3 - 2 * u); },
  clamp01(x) { return isFinite(x) ? Math.min(Math.max(x, 0), 1) : 0; },
  creakLevel(s) {
    const q = Tuning.quietSpeed; if (!(s > q)) return 0;
    if (s <= SB.softTop) return SB.softLevel * Math.pow((s - q) / (SB.softTop - q), 1.1);
    const loud = SB.loudLevelX ?? P.loudLevel, top = SB.topLevelX ?? P.topLevel;
    if (s <= Tuning.loudSpeed) return SB.softLevel + (loud - SB.softLevel) * (s - SB.softTop) / (Tuning.loudSpeed - SB.softTop);
    return loud + (top - loud) * SB.smooth((s - Tuning.loudSpeed) / (SB.fullSpeed - Tuning.loudSpeed));
  },
  squealLevel(s) { return SB.smooth((s - SB.squealStart) / (SB.squealFull - SB.squealStart)); },
  groanHz(s) { const u = SB.clamp01((s - Tuning.quietSpeed) / (60 - Tuning.quietSpeed)); return 140 + 280 * Math.pow(u, 0.8); },
  grainBase: null, // null = the config's (`try` may override)
  grainRate(s) { return (SB.grainBase ?? P.grainBase) + 240 * SB.clamp01((s - Tuning.quietSpeed) / (60 - Tuning.quietSpeed)); },
  applyCreak(bed, s, share = 1) {
    const level = SB.creakLevel(s) * share;
    bed.creak = level; bed.creakHz = SB.groanHz(s); bed.grainRate = level > 0 ? SB.grainRate(s) : 0;
    bed.creakBright = 0.1 + 0.85 * SB.clamp01((s - Tuning.quietSpeed) / 45);
    bed.squeal = SB.squealLevel(s) * share; bed.squealHz = 1700 + 900 * SB.clamp01((s - SB.squealStart) / 35);
  },
  heistBed({ speed = 0, stage = 'asleep', noise = 0, openness = 0.5, ambience = 1, torch = 60, master = P.master, drag = 0, playing = true }) {
    const bed = emptyBed(); bed.master = master; bed.glide = 0.05; bed.snorePeriod = 4.25;
    SB.applyCreak(bed, speed, playing ? 1 : P.restingShare);
    if (!playing) { /* result moments: creak (resting share) and ambience only */ }
    else if (stage === 'asleep') {
      const lighter = SB.clamp01(noise / 0.35);
      bed.snore = (0.55 + 0.45 * openness) * (1 - 0.45 * lighter); bed.motif = 1; bed.motifDensity = 1 - 0.45 * lighter;
    } else if (stage === 'stirring') { bed.motif = 0.7; bed.motifDensity = 0.3; }
    else bed.growl = 0.45 + 0.55 * SB.clamp01((noise - 0.7) / 0.3);
    if (playing && drag > 250) { const l = SB.clamp01((drag - 250) / 750); bed.rattle = 0.35 + 0.65 * l; bed.rattleRate = 12 + 38 * l; }
    if (ambience > 0) {
      bed.drone = ambience; bed.dripRate = 0.5 * ambience;
      if (torch > 0) { const low = SB.clamp01(1 - torch / 15); bed.crackle = (0.4 + 0.6 * low) * ambience; bed.crackleRate = 4 + 14 * low; }
    }
    return bed;
  },
};

const R = {}; // recipes; each returns commands with labels
const L = (label, arr) => arr.map((c) => ({ ...c, label: c.label || label }));
R.heartbeat = (fast) => { const k = fast ? 1 : 0.75, gap = fast ? 0.14 : 0.18, H = P.heart; return L('heart', [
  { type: 'tone', start: H.a[0], end: H.a[1], glide: 0.06, duration: 0.16, attack: 0.004, decay: 0.05, gain: 0.2 * k, harmonics: H.harmonics },
  { type: 'noise', mode: H.mode, cutoff: H.cut[0], q: 0.9, attack: 0.002, decay: 0.03, gain: 0.1 * k },
  { type: 'tone', start: H.b[0], end: H.b[1], glide: 0.06, duration: 0.14, attack: 0.004, decay: 0.045, gain: 0.13 * k, harmonics: H.harmonics, delay: gap },
  { type: 'noise', mode: H.mode, cutoff: H.cut[1], q: 0.9, attack: 0.002, decay: 0.025, gain: 0.06 * k, delay: gap }]); };
R.snort = (d) => L('snort', [
  { type: 'noise', mode: 'bp', cutoff: d.float(330, 400), q: 2, attack: 0.01, decay: 0.07, gain: 0.16 },
  { type: 'tone', start: 115, end: 88, glide: 0.12, duration: 0.16, attack: 0.008, decay: 0.06, gain: 0.12, harmonics: 5, vibratoRate: 26, vibratoDepth: 0.05 },
  { type: 'noise', mode: 'bp', cutoff: 700, q: 1, attack: 0.03, decay: 0.08, gain: 0.04, delay: 0.14 }]);
R.wakeSting = () => L('wake', [
  { type: 'tone', start: 72, end: 86, glide: 0.5, duration: 0.8, attack: 0.08, decay: 0.3, gain: 0.16, harmonics: 6, vibratoRate: 21, vibratoDepth: 0.05 },
  { type: 'noise', mode: 'lp', cutoff: 200, to: 420, sweep: 0.5, q: 2.5, attack: 0.1, decay: 0.25, gain: 0.18 },
  { type: 'tone', start: P.wake.notes[0], duration: 0.7, attack: 0.02, decay: 0.3, gain: P.wake.gain, harmonics: P.wake.harmonics },
  { type: 'tone', start: P.wake.notes[1], duration: 0.7, attack: 0.02, decay: 0.3, gain: P.wake.gain, harmonics: P.wake.harmonics }]);
R.creakAccent = (d) => L('crack', [
  { type: 'noise', mode: 'hp', cutoff: 2600, q: 0.8, attack: 0.0004, decay: 0.009, gain: 0.24 },
  { type: 'ring', kind: 'wood', fundamental: d.float(620, 700), partials: 5, decay: 0.035, brightness: 0.62, gain: 0.26, seed: d.seed32() },
  { type: 'ring', kind: 'wood', fundamental: d.float(1900, 2200), partials: 3, decay: 0.012, brightness: 0.55, gain: 0.14, delay: 0.014, seed: d.seed32() },
  { type: 'tone', start: 210, end: 120, glide: 0.04, duration: 0.09, attack: 0.001, decay: 0.03, gain: 0.16, harmonics: 4 },
  { type: 'noise', mode: 'bp', cutoff: d.float(1400, 1700), q: 1.4, attack: 0.0004, decay: 0.006, gain: 0.1, delay: d.float(0.045, 0.06) }]);
R.chomp = (d, o = {}) => { const C = { ...P.chomp, ...o }; const cmds = [
  { type: 'tone', start: 150, end: C.thumpEnd, glide: 0.12, duration: 0.3, attack: 0.002, decay: 0.09, gain: C.thumpGain, harmonics: C.thumpHarm },
  { type: 'noise', mode: 'lp', cutoff: 520, to: 180, sweep: 0.1, q: 1.1, attack: 0.001, decay: 0.07, gain: C.subNoise },
  { type: 'noise', mode: 'hp', cutoff: 1800, q: 0.7, attack: 0.0005, decay: C.crackDecay ?? 0.02, gain: C.crack },
  { type: 'ring', kind: 'wood', fundamental: 340, partials: C.woodPartials, decay: C.woodDecay ?? 0.05, brightness: 0.5, gain: C.wood, seed: d.seed32() }];
  if (C.crunch > 0) cmds.push({ type: 'noise', mode: 'bp', cutoff: C.crunchHz ?? 750, to: C.crunchTo ?? 450, sweep: 0.08, q: 1.2, attack: 0.001, decay: C.crunchDecay ?? 0.05, gain: C.crunch });
  cmds.push(
  { type: 'ring', kind: 'wood', fundamental: 1850, partials: 3, decay: C.teethDecay ?? 0.012, brightness: 0.5, gain: C.teeth1 ?? 0.2, delay: 0.035, seed: d.seed32() },
  { type: 'ring', kind: 'wood', fundamental: 2400, partials: 3, decay: C.teethDecay2 ?? C.teethDecay ?? 0.01, brightness: 0.5, gain: C.teeth2 ?? 0.17, delay: 0.06, seed: d.seed32() },
  { type: 'tone', start: 95, end: 70, glide: 0.4, duration: 0.55, attack: 0.04, decay: 0.2, gain: 0.2, harmonics: 7, vibratoRate: 22, vibratoDepth: 0.07, delay: 0.16 },
  { type: 'noise', mode: 'lp', cutoff: 380, to: 160, sweep: 0.4, q: 2.5, attack: 0.05, decay: 0.18, gain: 0.18, delay: 0.16 });
  return L('chomp', cmds); };
// R12: the gains ×1.8 and, per hit, each partial's gain × 0.85…1.15 and index × 0.8…1.2 (the Swift draw order).
R.coinClink = (d, scale = 1, delay = 0, label = 'clink') => { const k = d.float(0.97, 1.03); const G = P.coinGains;
  const g = P.coinVary ? [0, 1, 2, 3].map(() => d.float(0.85, 1.15)) : [1, 1, 1, 1];
  const ix = P.coinVary ? [0, 1, 2, 3].map(() => d.float(0.8, 1.2)) : [1, 1, 1, 1];
  const second = d.float(0.03, 0.05);
  return L(label, [
  { type: 'fm', carrier: 2300 * k, ratio: 1.41, index: 1.6 * ix[0], indexDecay: 0.02, decay: 0.07, gain: G[0] * g[0] * scale, delay },
  { type: 'fm', carrier: 3650 * k, ratio: 2.17, index: 0.9 * ix[1], indexDecay: 0.015, decay: 0.05, gain: G[1] * g[1] * scale, delay: delay + 0.002 },
  { type: 'fm', carrier: 5200 * k, ratio: 1.13, index: 0.5 * ix[2], indexDecay: 0.01, decay: 0.035, gain: G[2] * g[2] * scale, delay: delay + 0.004 },
  { type: 'fm', carrier: 2650 * k, ratio: 1.41, index: 1.0 * ix[3], indexDecay: 0.015, decay: 0.045, gain: G[3] * g[3] * scale, delay: delay + second }]); };
R.silverTing = (d, scale = 1, delay = 0) => L('silver', [
  { type: 'ring', kind: 'glass', fundamental: d.float(2060, 2120), partials: 3, decay: 0.35, brightness: 0.35, gain: 0.08 * scale, delay, seed: d.seed32() },
  { type: 'fm', carrier: 4186, ratio: 1.5, index: 0.8, indexDecay: 0.03, decay: 0.12, gain: 0.04 * scale, delay }]);
R.gemChime = (f, d, scale = 1, delay = 0) => L('gem', [
  { type: 'ring', kind: 'bell', fundamental: f, partials: 6, decay: 1.1, brightness: 0.5, gain: 0.11 * scale, delay, seed: d.seed32() },
  { type: 'ring', kind: 'glass', fundamental: f * 2, partials: 2, decay: 0.2, brightness: 0.3, gain: 0.035 * scale, delay: delay + 0.02, seed: d.seed32() }]);
R.relicVoice = (d, scale = 1, delay = 0) => L('relicvoice', [
  { type: 'ring', kind: 'bell', fundamental: 587.33, partials: 6, decay: 1.2, brightness: 0.45, gain: 0.1 * scale, delay, seed: d.seed32() },
  { type: 'ring', kind: 'glass', fundamental: 1760, partials: 2, decay: 0.3, brightness: 0.3, gain: 0.04 * scale, delay: delay + 0.03, seed: d.seed32() }]);
R.lootVoice = (kind, d, scale, delay) => kind === 'copper' ? R.coinClink(d, scale, delay) : kind === 'silver' ? R.silverTing(d, scale, delay) : kind === 'gem' ? R.gemChime(1174.66, d, scale, delay) : R.relicVoice(d, scale, delay);
R.itemBagged = (kind, d) => { const cut = P.bagVary ? d.float(330, 430) : 380; const pitch = P.bagVary ? d.float(138, 165) : 150; return [...L('bag', [
  { type: 'noise', mode: 'lp', cutoff: cut, to: 160, sweep: 0.06, q: 0.9, attack: 0.002, decay: 0.045, gain: 0.18 },
  { type: 'tone', start: pitch, end: 95, glide: 0.05, duration: 0.12, attack: 0.003, decay: 0.04, gain: 0.12, harmonics: 3 }]), ...R.lootVoice(kind, d, 0.85, 0.03)]; };
R.itemDropped = (d) => L('drop', [
  { type: 'ring', kind: 'wood', fundamental: d.float(240, 290), partials: 3, decay: 0.05, brightness: 0.45, gain: 0.18, seed: d.seed32() },
  { type: 'noise', mode: 'lp', cutoff: 600, q: 0.9, attack: 0.001, decay: 0.03, gain: 0.16 },
  { type: 'tone', start: 140, end: 90, glide: 0.06, duration: 0.11, attack: 0.002, decay: 0.035, gain: 0.12, harmonics: 3 }]);
R.relicChoir = (delay = 0) => { const cmds = []; [293.66, 369.99, 440, 587.33].forEach((f, i) => cmds.push({ type: 'tone', start: f, duration: 2.4, attack: 0.4, decay: 0.9, gain: 0.045, harmonics: 4, vibratoRate: 4.6 + 0.35 * i, vibratoDepth: 0.006, delay: delay + 0.05 * i }));
  cmds.push({ type: 'noise', mode: 'bp', cutoff: 800, q: 1.5, attack: 0.45, decay: 0.5, gain: 0.035, delay });
  cmds.push({ type: 'ring', kind: 'glass', fundamental: 2349.3, partials: 2, decay: 0.4, brightness: 0.3, gain: 0.035, delay: delay + 0.5 });
  return L('choir', cmds); };
R.cascadeCount = (v) => { if (v <= 50) return 6; const dbl = Math.floor(Math.log2(v / 50)); return Math.min(Math.max(6 + dbl + 1, 6), 14); };
R.cascadeTimes = (count) => { const n = Math.min(Math.max(count, 1), 16); const t = []; for (let k = 0; k < n; k++) { const x = n === 1 ? 0 : k / (n - 1); t.push(Math.max(0.12 + 0.8 * Math.pow(x, 1.35) + 0.012 * Math.sin(k * 2.3 + 0.7), 0.1)); } return t; };
R.bank = (value, hushed, d, o = {}) => {
  const cmds = L('thunk', [
    { type: 'tone', start: 140, end: 58, glide: 0.1, duration: 0.26, attack: 0.002, decay: 0.08, gain: 0.3, harmonics: 5 },
    { type: 'noise', mode: 'lp', cutoff: 480, to: 200, sweep: 0.08, q: 1, attack: 0.001, decay: 0.06, gain: 0.26 },
    { type: 'ring', kind: 'wood', fundamental: 210, partials: 4, decay: 0.06, brightness: 0.45, gain: 0.2, seed: d.seed32() }]);
  const times = R.cascadeTimes(R.cascadeCount(value));
  times.forEach((t, i) => { const fade = 1 - 0.4 * i / Math.max(times.length - 1, 1); let c = R.coinClink(d, 0.7 * fade, t, 'cascade'); if (o.cascadeVoices) c = c.slice(0, o.cascadeVoices); cmds.push(...c); });
  cmds.push({ type: 'noise', mode: 'hp', cutoff: 2500, q: 0.7, attack: 0.0005, decay: 0.012, gain: 0.1, delay: 1.0, label: 'kaching' });
  P.kaChord.forEach((f, i) => cmds.push({ type: 'ring', kind: 'bell', fundamental: f, partials: 5, decay: 0.9, brightness: 0.45, gain: o.chordGain ?? 0.075, delay: 1.03 + 0.012 * i, seed: d.seed32(), label: 'kaching' }));
  cmds.push({ type: 'ring', kind: 'glass', fundamental: 2349.3, partials: 2, decay: 0.35, brightness: 0.3, gain: P.kaGlass, delay: 1.06, seed: d.seed32(), label: 'kaching' });
  if (hushed) {
    cmds.push({ type: 'ring', kind: 'chime', fundamental: 1174.66, partials: 3, decay: 0.6, brightness: 0.3, gain: 0.05, delay: 1.3, seed: d.seed32(), label: 'hushed' });
    cmds.push({ type: 'ring', kind: 'chime', fundamental: 1760, partials: 3, decay: 0.7, brightness: 0.3, gain: 0.045, delay: 1.42, seed: d.seed32(), label: 'hushed' });
  }
  return cmds;
};
R.chainLadder = [880, 987.77, 1174.66, 1318.51, 1479.98, 1760, 1975.53, 2349.3];
R.chainUp = (count, delay, d) => { const top = Math.min(Math.max(count, 1), 8) - 1; const notes = R.chainLadder.slice(Math.max(top - 2, 0), top + 1); const cmds = [];
  notes.forEach((f, i) => { const last = i === notes.length - 1; cmds.push({ type: 'ring', kind: 'chime', fundamental: f, partials: 3, decay: last ? 0.8 : 0.35, brightness: 0.35, gain: last ? 0.075 : 0.06, delay: delay + 0.065 * i, seed: d.seed32() }); });
  cmds.push({ type: 'ring', kind: 'glass', fundamental: notes[notes.length - 1] * 2, partials: 2, decay: 0.3, brightness: 0.3, gain: 0.03, delay: delay + 0.065 * (notes.length - 1) + 0.03, seed: d.seed32() });
  return L('chain', cmds); };
R.newBest = (delay = 0) => L('newbest', [1174.66, 1479.98, 1760, 2349.3].map((f, i) => ({ type: 'ring', kind: 'chime', fundamental: f, partials: 4, decay: i === 3 ? 0.9 : 0.5, brightness: 0.35, gain: i === 3 ? 0.1 : 0.08, delay: delay + 0.085 * i, seed: i + 3 })));
R.goldenArrived = (d, delay = 0.4) => { const cmds = []; const g = [1174.66, 1318.51, 1479.98, 1760, 1975.53, 2349.3, 2637.02];
  g.forEach((f, i) => { const last = i === g.length - 1; cmds.push({ type: 'ring', kind: 'glass', fundamental: f, partials: 2, decay: last ? 0.7 : 0.25, brightness: 0.3, gain: last ? 0.05 : 0.04, delay: delay + 0.045 * i, seed: d.seed32() }); });
  [587.33, 739.99, 880].forEach((f, i) => cmds.push({ type: 'tone', start: f, duration: 1.3, attack: 0.25, decay: 0.45, gain: 0.03, harmonics: 2, vibratoRate: 7.5 + 0.6 * i, vibratoDepth: 0.01, delay: delay + 0.1 }));
  cmds.push({ type: 'noise', mode: 'bp', cutoff: 5200, to: 7000, sweep: 0.8, q: 2, attack: 0.2, decay: 0.35, gain: 0.025, delay: delay + 0.05 });
  for (let k = 0; k < 3; k++) cmds.push({ type: 'ring', kind: 'glass', fundamental: d.float(3100, 4200), partials: 2, decay: 0.15, brightness: 0.3, gain: 0.025, delay: delay + 0.45 + 0.17 * k + d.float(0, 0.05), seed: d.seed32() });
  return L('golden', cmds); };
R.chestArrived = (d, tier) => { const cmds = [
  { type: 'noise', mode: 'lp', cutoff: 250, to: 700, sweep: 0.35, q: 0.8, attack: 0.12, decay: 0.12, gain: 0.1 },
  { type: 'ring', kind: 'wood', fundamental: d.float(170, 190), partials: 4, decay: 0.06, brightness: 0.45, gain: 0.15, delay: 0.38, seed: d.seed32() },
  { type: 'tone', start: 110, end: 70, glide: 0.08, duration: 0.15, attack: 0.003, decay: 0.05, gain: 0.1, harmonics: 4, delay: 0.38 }];
  const metal = { wooden: 0, iron: 440, gilded: 523.25, royal: 587.33 }[tier];
  if (metal) cmds.push({ type: 'ring', kind: 'bell', fundamental: metal, partials: 5, decay: 0.5, brightness: 0.45, gain: 0.05, delay: 0.39, seed: d.seed32() });
  return L('arrive', cmds); };
R.spillTimes = (count) => { const n = Math.min(Math.max(count, 0), 12); const t = []; for (let k = 0; k < n; k++) { const x = n === 1 ? 0 : k / (n - 1); t.push(Math.max(0.3 + 0.6 * Math.pow(x, 1.25) + 0.018 * Math.sin(k * 1.7 + 0.4), 0.3)); } return t; };
R.coinSpill = (lost, d) => { const n = lost > 0 ? Math.min(Math.max(R.cascadeCount(lost) - 3, 4), 10) : 0; const times = R.spillTimes(n); const cmds = [];
  times.forEach((t, i) => { const fade = 1 - 0.5 * i / Math.max(times.length - 1, 1); cmds.push({ type: 'fm', carrier: d.float(2100, 3400), ratio: 1.41, index: 1.3, indexDecay: 0.015, decay: 0.05, gain: 0.075 * fade, delay: t });
    if (i % 3 === 0) cmds.push({ type: 'ring', kind: 'wood', fundamental: d.float(900, 1300), partials: 2, decay: 0.01, brightness: 0.4, gain: 0.05 * fade, delay: t, seed: d.seed32() }); });
  cmds.push({ type: 'noise', mode: 'bp', cutoff: 1300, to: 350, sweep: 0.45, q: 0.9, attack: 0.01, decay: 0.18, gain: 0.07, delay: 0.95 });
  return L('spill', cmds); };
R.torchTick = (urgent, tock) => { const p = urgent ? (tock ? 2500 : 3000) : (tock ? 2000 : 2400); const c = [{ type: 'ring', kind: 'wood', fundamental: p, partials: 2, decay: urgent ? 0.01 : 0.008, brightness: 0.35, gain: urgent ? 0.07 : 0.05 }];
  if (urgent) c.push({ type: 'noise', mode: 'hp', cutoff: 4000, q: 0.7, attack: 0.0005, decay: 0.004, gain: 0.03 }); return L('tick', c); };

// ---------- analysis ----------
function biquad(b, a) { let x1 = 0, x2 = 0, y1 = 0, y2 = 0; return (x) => { const y = b[0] * x + b[1] * x1 + b[2] * x2 - a[1] * y1 - a[2] * y2; x2 = x1; x1 = x; y2 = y1; y1 = y; return y; }; }
function kWeight(sig) { // ITU-R BS.1770 K-weighting, 48 kHz coefficients
  const s1 = biquad([1.53512485958697, -2.69169618940638, 1.19839281085285], [1, -1.69065929318241, 0.73248077421585]);
  const s2 = biquad([1, -2, 1], [1, -1.99004745483398, 0.99007225036621]);
  const out = new Float64Array(sig.length); for (let i = 0; i < sig.length; i++) out[i] = s2(s1(sig[i])); return out;
}
function hpButter(fc, q) { const w = TWO_PI * fc / SR, cw = Math.cos(w), al = Math.sin(w) / (2 * q); const a0 = 1 + al;
  return biquad([(1 + cw) / 2 / a0, -(1 + cw) / a0, (1 + cw) / 2 / a0], [1, -2 * cw / a0, (1 - al) / a0]); }
function speakerProxy(sig) { // 4th-order Butterworth high-pass at 400 Hz: a rough phone-speaker low end
  const h1 = hpButter(400, 0.5412), h2 = hpButter(400, 1.3066); const out = new Float64Array(sig.length);
  for (let i = 0; i < sig.length; i++) out[i] = h2(h1(sig[i])); return out;
}
const db = (x) => (x > 0 ? 20 * Math.log10(x) : -Infinity);
function rms(sig, a = 0, b = sig.length) { let s = 0; for (let i = a; i < b; i++) s += sig[i] * sig[i]; return Math.sqrt(s / Math.max(b - a, 1)); }
function peakOf(sig) { let p = 0; for (const x of sig) p = Math.max(p, Math.abs(x)); return p; }
function lufsIntegrated(sig) {
  const k = kWeight(sig); const block = Math.floor(0.4 * SR), hop = Math.floor(0.1 * SR); const ms = [];
  for (let i = 0; i + block <= k.length; i += hop) { let s = 0; for (let j = i; j < i + block; j++) s += k[j] * k[j]; ms.push(s / block); }
  const L = (m) => -0.691 + 10 * Math.log10(m);
  let g = ms.filter((m) => L(m) > -70); if (!g.length) return -Infinity;
  const rel = L(g.reduce((a, b) => a + b, 0) / g.length) - 10; g = g.filter((m) => L(m) > rel);
  return L(g.reduce((a, b) => a + b, 0) / g.length);
}
function lufsMomentaryMax(sig) { const k = kWeight(sig); const block = Math.floor(0.4 * SR), hop = Math.floor(0.02 * SR); let best = -Infinity;
  for (let i = 0; i + block <= k.length; i += hop) { let s = 0; for (let j = i; j < i + block; j++) s += k[j] * k[j]; best = Math.max(best, -0.691 + 10 * Math.log10(s / block + 1e-20)); }
  if (k.length < block) { let s = 0; for (const x of k) s += x * x; best = -0.691 + 10 * Math.log10(s / block + 1e-20); }
  return best; }
function fft(re, im) { const n = re.length; for (let i = 1, j = 0; i < n; i++) { let bit = n >> 1; for (; j & bit; bit >>= 1) j ^= bit; j ^= bit; if (i < j) { [re[i], re[j]] = [re[j], re[i]]; [im[i], im[j]] = [im[j], im[i]]; } }
  for (let len = 2; len <= n; len <<= 1) { const ang = -TWO_PI / len; for (let i = 0; i < n; i += len) for (let j = 0; j < len / 2; j++) { const wr = Math.cos(ang * j), wi = Math.sin(ang * j);
    const ur = re[i + j], ui = im[i + j], vr = re[i + j + len / 2] * wr - im[i + j + len / 2] * wi, vi = re[i + j + len / 2] * wi + im[i + j + len / 2] * wr;
    re[i + j] = ur + vr; im[i + j] = ui + vi; re[i + j + len / 2] = ur - vr; im[i + j + len / 2] = ui - vi; } } }
// Averaged power spectrum (Welch, Hann, N=4096).
function spectrum(sig, a = 0, b = sig.length) { const N = 4096; const P = new Float64Array(N / 2); let frames = 0;
  for (let i = a; i + N <= b; i += N / 2) { const re = new Float64Array(N), im = new Float64Array(N);
    for (let j = 0; j < N; j++) re[j] = sig[i + j] * (0.5 - 0.5 * Math.cos(TWO_PI * j / (N - 1)));
    fft(re, im); for (let j = 0; j < N / 2; j++) P[j] += re[j] * re[j] + im[j] * im[j]; frames++; }
  if (frames === 0) { const re = new Float64Array(N), im = new Float64Array(N); for (let j = 0; j < Math.min(N, b - a); j++) re[j] = sig[a + j] * (0.5 - 0.5 * Math.cos(TWO_PI * j / (N - 1))); fft(re, im); for (let j = 0; j < N / 2; j++) P[j] = re[j] * re[j] + im[j] * im[j]; frames = 1; }
  return { P, df: SR / N };
}
function bands(sig, a, b, edges = [0, 200, 400, 1000, 2500, 5000, 24000]) { const { P, df } = spectrum(sig, a, b); const e = new Array(edges.length - 1).fill(0); let tot = 0, cen = 0, lg = 0, cnt = 0;
  for (let j = 1; j < P.length; j++) { const f = j * df; tot += P[j]; cen += f * P[j]; if (f > 100 && f < 10000) { lg += Math.log(P[j] + 1e-30); cnt++; }
    for (let k = 0; k < e.length; k++) if (f >= edges[k] && f < edges[k + 1]) e[k] += P[j]; }
  let arith = 0, c2 = 0; for (let j = 1; j < P.length; j++) { const f = j * df; if (f > 100 && f < 10000) { arith += P[j]; c2++; } }
  const flat = Math.exp(lg / cnt) / (arith / c2);
  return { share: e.map((x) => x / tot), centroid: cen / tot, flatness: flat };
}
// Normalised autocorrelation peak over a pitch range (1 = perfectly periodic, i.e. a "buzz"; < 0.3 = noisy/irregular).
function periodicity(sig, a, fmin = 80, fmax = 800) { const N = 4096; let best = 0, bestLag = 0; const x = sig.subarray(a, a + N + Math.ceil(SR / fmin));
  let e0 = 0; for (let i = 0; i < N; i++) e0 += x[i] * x[i];
  for (let lag = Math.floor(SR / fmax); lag <= Math.ceil(SR / fmin); lag++) { let s = 0, e1 = 0; for (let i = 0; i < N; i++) { s += x[i] * x[i + lag]; e1 += x[i + lag] * x[i + lag]; } const r = s / Math.sqrt(e0 * e1 + 1e-30); if (r > best) { best = r; bestLag = lag; } }
  return { r: best, hz: SR / Math.max(bestLag, 1) };
}
function envelopeStats(sig) { const p = peakOf(sig); let ip = 0; for (let i = 0; i < sig.length; i++) if (Math.abs(sig[i]) === p) { ip = i; break; }
  const win = Math.floor(0.005 * SR); const envs = []; for (let i = 0; i + win <= sig.length; i += win) envs.push(rms(sig, i, i + win));
  const ep = Math.max(...envs); const ipk = envs.indexOf(ep); let t20 = null, t40 = null; for (let i = ipk; i < envs.length; i++) { if (t20 === null && envs[i] < ep * 0.1) t20 = (i - ipk) * 0.005; if (t40 === null && envs[i] < ep * 0.01) { t40 = i * 0.005; break; } }
  return { peak: p, tPeak: ip / SR, decay20: t20, len40: t40 }; }

function renderShot(cmds, seconds, opts = {}) { const s = new Synth(opts); const bed = emptyBed(); bed.master = opts.master ?? P.master; s.setBed(bed); s.bed = { ...bed }; s.play(cmds); const out = new Float64Array(Math.floor(seconds * SR)); s.render(out.length, out); return { out, synth: s }; }
const f1 = (x, n = 1) => (isFinite(x) ? x.toFixed(n) : String(x));
const pad = (s, n) => String(s).padEnd(n);

// ---------- sections ----------
function sectionCreak(opts = {}, title = 'CREAK (steady speed, creak layer only, after master+limiter)') {
  console.log(`\n## ${title}`);
  console.log('speed  level  RMS dBFS  LUFS   spk-RMS  centroid  <200 200-400 .4-1k 1-2.5k 2.5-5k >5k  flat  period r@Hz   groan/grain/squeal dB');
  for (const sp of [15, 17, 20, 25, 30, 40, 60]) {
    const s = new Synth(opts); const bed = SB.heistBed({ speed: sp, ambience: 0, stage: 'waking', noise: 0 }); bed.growl = 0; s.setBed(bed); s.bed = { ...bed };
    const n = 3 * SR; const out = new Float64Array(n);
    const layers = { creak: new Float64Array(n), snore: new Float64Array(n), growl: new Float64Array(n), dungeon: new Float64Array(n), voices: new Float64Array(n), groan: new Float64Array(n), body: new Float64Array(n), grain: new Float64Array(n), squeal: new Float64Array(n) };
    s.render(n, out, 0, layers);
    const a = SR; const r = rms(out, a); const spk = rms(speakerProxy(out), a); const bnd = bands(out, a, n); const per = periodicity(out, a + 1000);
    const g = db(rms(layers.groan, a) + 1e-12) | 0, gb = db(rms(layers.body, a)) | 0, gr = db(rms(layers.grain, a)) | 0, sq = db(rms(layers.squeal, a) + 1e-12);
    console.log(`${pad(sp, 6)} ${pad(f1(SB.creakLevel(sp), 2), 6)} ${pad(f1(db(r)), 9)} ${pad(f1(lufsIntegrated(out.subarray(a))), 6)} ${pad(f1(db(spk)), 8)} ${pad(Math.round(bnd.centroid), 9)} ${bnd.share.map((x) => pad(f1(100 * x, 0) + '%', 6)).join('')} ${pad(f1(bnd.flatness, 2), 5)} ${pad(f1(per.r, 2) + '@' + Math.round(per.hz), 12)} ${g}/${gb}(body)/${gr}/${isFinite(sq) ? sq.toFixed(0) : '-'}`);
  }
  // Onset/tail: a hand that moves at 30°/s for 1 s then stops; speed follows FeelSpeedEstimator (port below).
}

function sectionShots() {
  console.log(`\n## ONE-SHOTS [${P.name}] (each alone on silence; master ${P.master} + limiter). spk = after a 400 Hz 4th-order HPF (phone-speaker proxy)`);
  console.log(pad('sound', 26) + pad('peak dBFS', 10) + pad('mom.LUFS', 9) + pad('spk mom', 9) + pad('spk loss', 9) + pad('centroid', 9) + pad('<200Hz', 7) + pad('t20dB', 7) + pad('len-40', 7) + 'voices');
  const d = makeDice(7);
  const list = [
    ['creak accent (crack)', R.creakAccent(d), 0.4],
    ['CHOMP', R.chomp(d), 1.2],
    ['CHOMP + coin spill 300g', [...R.chomp(d), ...R.coinSpill(300, d)], 1.6],
    ['coin clink', R.coinClink(d), 0.4],
    ['silver ting', R.silverTing(d), 1.0],
    ['gem chime', R.gemChime(1174.66, d), 2.5],
    ['bag thud + copper', R.itemBagged('copper', d), 0.6],
    ['bag thud + gem', R.itemBagged('gem', d), 2.0],
    ['drop clunk', R.itemDropped(d), 0.5],
    ['bank 30g', R.bank(30, false, d), 3.0],
    ['bank 400g hushed', R.bank(400, true, d), 3.0],
    ['ka-ching chord only', R.bank(30, false, d).filter((c) => c.label === 'kaching'), 3.0],
    ['relic choir', R.relicChoir(0), 3.0],
    ['chain up x3', R.chainUp(3, 0, d), 1.5],
    ['golden arrival', R.goldenArrived(d, 0), 2.0],
    ['new best', R.newBest(0), 1.5],
    ['heartbeat slow', R.heartbeat(false), 0.6],
    ['heartbeat fast', R.heartbeat(true), 0.6],
    ['snort', R.snort(d), 0.6],
    ['wake sting', R.wakeSting(), 1.5],
    ['chest arrived (iron)', R.chestArrived(d, 'iron'), 1.5],
    ['torch tick', R.torchTick(false, false), 0.2],
  ];
  for (const [name, cmds, secs] of list) {
    const { out } = renderShot(cmds, secs); const spk = speakerProxy(out); const e = envelopeStats(out); const b = bands(out, 0, out.length);
    const m = lufsMomentaryMax(out), ms = lufsMomentaryMax(spk);
    console.log(pad(name, 26) + pad(f1(db(e.peak)), 10) + pad(f1(m), 9) + pad(f1(ms), 9) + pad(f1(ms - m), 9) + pad(Math.round(b.centroid), 9) + pad(f1(100 * b.share[0], 0) + '%', 7) + pad(e.decay20 === null ? '-' : f1(e.decay20, 3), 7) + pad(e.len40 === null ? '>' + secs : f1(e.len40, 2), 7) + cmds.length);
  }
  // Variation: 8 coin clinks, spread of carrier and of level.
  const vd = makeDice(11); const cents = []; for (let i = 0; i < 8; i++) { cents.push(1200 * Math.log2(R.coinClink(vd)[0].carrier / 2300)); }
  const lv = []; for (let i = 0; i < 8; i++) { const { out } = renderShot(R.coinClink(vd), 0.4); lv.push(lufsMomentaryMax(out)); }
  console.log(`coin clink over 8 repeats: pitch ${Math.min(...cents).toFixed(0)}…${Math.max(...cents).toFixed(0)} cents, momentary ${f1(Math.min(...lv))}…${f1(Math.max(...lv))} LUFS`);
}

function sectionChompVariants() {
  console.log('\n## CHOMP variants (speaker proxy matters most: the thump body is 48–150 Hz)');
  const d = makeDice(3);
  const variants = [['as shipped (end 48 Hz, harm 6, gain 0.36)', {}], ['end 70 Hz, harm 8', { thumpEnd: 70, thumpHarm: 8 }], ['end 70 Hz, harm 8, gain 0.42', { thumpEnd: 70, thumpHarm: 8, thumpGain: 0.42 }]];
  for (const [name, o] of variants) { const { out } = renderShot(R.chomp(d, o), 1.2); const spk = speakerProxy(out); console.log(`${pad(name, 44)} peak ${f1(db(peakOf(out)))} dBFS  mom ${f1(lufsMomentaryMax(out))}  spk mom ${f1(lufsMomentaryMax(spk))}  spk first-80ms RMS ${f1(db(rms(spk, 0, Math.floor(0.08 * SR))))} dB`); }
}

function sectionMix() {
  console.log('\n## MIX (10 s scenes, full bed; integrated LUFS (BS.1770 K-weighted, mono) and the speaker proxy)');
  const scenes = [
    ['asleep, lid still (bed+snore+motif)', { speed: 0, stage: 'asleep', noise: 0.1 }],
    ['asleep, opening at 20°/s', { speed: 20, stage: 'asleep', noise: 0.2 }],
    ['asleep, opening at 30°/s', { speed: 30, stage: 'asleep', noise: 0.3 }],
    ['stirring, still (+60 bpm heart)', { speed: 0, stage: 'stirring', noise: 0.5, heart: 1.0 }],
    ['waking, still (growl+110 bpm heart)', { speed: 0, stage: 'waking', noise: 0.85, heart: 60 / 110, fast: true }],
    ['waking, 40°/s', { speed: 40, stage: 'waking', noise: 0.95, heart: 60 / 110, fast: true }],
  ];
  console.log(pad('scene', 38) + pad('LUFS', 7) + pad('spk LUFS', 9) + pad('peak', 7) + 'layer RMS dBFS (creak / snore / growl / dungeon / one-shots)');
  for (const [name, p] of scenes) {
    const s = new Synth(); const bed = SB.heistBed(p); s.setBed(bed); s.bed = { ...bed };
    const n = 10 * SR; const out = new Float64Array(n);
    const layers = { creak: new Float64Array(n), snore: new Float64Array(n), growl: new Float64Array(n), dungeon: new Float64Array(n), voices: new Float64Array(n), groan: new Float64Array(n), body: new Float64Array(n), grain: new Float64Array(n), squeal: new Float64Array(n) };
    const block = 480; let nextHeart = 0.25;
    for (let i = 0; i < n; i += block) { const t = i / SR; if (p.heart && t >= nextHeart) { s.play(R.heartbeat(!!p.fast)); nextHeart += p.heart; } s.render(block, out, i, layers); }
    const ly = ['creak', 'snore', 'growl', 'dungeon', 'voices'].map((k) => { const v = db(rms(layers[k], SR)); return isFinite(v) ? v.toFixed(0) : '-'; }).join(' / ');
    console.log(pad(name, 38) + pad(f1(lufsIntegrated(out.subarray(SR))), 7) + pad(f1(lufsIntegrated(speakerProxy(out).subarray(SR))), 9) + pad(f1(db(peakOf(out))), 7) + ly);
  }
  // Reward vs bed: the bank moment over the asleep bed.
  for (const [name, cmds] of [['bank 400g hushed + chain3 + relic + best, over the bed', null], ['bite: CHOMP + spill over the waking bed', 'bite']]) {
    const s = new Synth(); const bed = SB.heistBed(cmds === 'bite' ? { speed: 0, stage: 'waking', noise: 0.95 } : { speed: 0, stage: 'asleep', noise: 0.1 }); s.setBed(bed); s.bed = { ...bed };
    const n = 4 * SR; const out = new Float64Array(n); s.render(SR, out, 0); const d = makeDice(5);
    if (cmds === 'bite') s.play([...R.chomp(d), ...R.coinSpill(300, d)]);
    else s.play([...R.bank(400, true, d), ...R.chainUp(3, 1.55, d), ...R.relicChoir(1.15), ...R.newBest(1.4)]);
    s.render(3 * SR, out, SR);
    const bedL = lufsIntegrated(out.subarray(0, SR)), mom = lufsMomentaryMax(out.subarray(SR));
    console.log(`${pad(name, 56)} bed ${f1(bedL)} LUFS -> moment max ${f1(mom)} LUFS (+${f1(mom - bedL)} LU), peak ${f1(db(peakOf(out)))} dBFS, voices stolen ${s.stolen.length}`);
  }
  // Limiter ceiling: the most any sample can reach.
  console.log(`hard ceiling: tanh(${0.9}) = ${Math.tanh(0.9).toFixed(3)} = ${db(Math.tanh(0.9)).toFixed(2)} dBFS (limiter drives tanh to at most 0.9, so the ±0.98 clamp never acts)`);
  const s = new Synth(); const bed = emptyBed(); bed.master = P.master; s.setBed(bed); s.bed = { ...bed }; const out = new Float64Array(SR); const d = makeDice(9);
  s.play([...R.chomp(d), ...R.bank(800, true, d), ...R.creakAccent(d)]); s.render(SR, out); console.log(`hot pile-up (CHOMP+bank 800+crack at once): peak ${f1(db(peakOf(out)), 2)} dBFS`);
}

function sectionVoices() {
  console.log('\n## VOICE BUDGET (R11: 48 voices, rings held decay×7; R12: 96, ×5. All bank commands are queued in one frame; delayed voices hold a slot from the start)');
  const scen = [
    ['bank 30g', (d) => R.bank(30, false, d)],
    ['bank 120g hushed + chain2', (d) => [...R.bank(120, true, d), ...R.chainUp(2, 1.55, d)]],
    ['bank 400g hushed + chain3 + relic', (d) => [...R.bank(400, true, d), ...R.chainUp(3, 1.55, d), ...R.relicChoir(1.15)]],
    ['bank 1700g hushed + chain5 + relic + best', (d) => [...R.bank(1700, true, d), ...R.chainUp(5, 1.55, d), ...R.relicChoir(1.15), ...R.newBest(1.4)]],
    ['bank 3400g (golden royal) + chain5 + relic + best', (d) => [...R.bank(3400, true, d), ...R.chainUp(5, 1.55, d), ...R.relicChoir(1.15), ...R.newBest(1.4)]],
  ];
  for (const cfg of ['r11', 'r12']) for (const [name, mk] of scen) using(cfg, () => {
    const voiceCount = P.voiceCount;
    const s = new Synth(); const bed = SB.heistBed({ speed: 0, stage: 'asleep', noise: 0.1 }); s.setBed(bed); s.bed = { ...bed };
    const pre = new Float64Array(2 * SR); s.render(pre.length, pre); // the bed runs: motif plucks and drips hold slots
    // A few bag events before the bank, as in play (a gem rings for 6 s).
    const d = makeDice(21); s.play(R.itemBagged('gem', d)); s.render(SR / 2, new Float64Array(SR / 2)); s.play(R.itemBagged('copper', d)); s.render(SR / 4, new Float64Array(SR / 4));
    s.stolen = []; const cmds = mk(d); s.play(cmds);
    const lost = {}; for (const x of s.stolen) lost[x.victim] = (lost[x.victim] || 0) + 1;
    // Which of the just-queued commands survived to be heard?
    const queued = {}; for (const c of cmds) queued[c.label] = (queued[c.label] || 0) + 1;
    const live = {}; for (const v of s.voices) if (v.active) live[v.label] = (live[v.label] || 0) + 1;
    const fate = Object.keys(queued).map((k) => `${k} ${live[k] || 0}/${queued[k]}`).join(', ');
    const atQueue = s.stolen.length; let most = 0;
    for (let k = 0; k < 300; k++) { s.render(480, new Float64Array(480)); most = Math.max(most, s.voices.filter((v) => v.active).length); }
    console.log(`[${voiceCount}] ${pad(name, 50)} cmds ${pad(cmds.length, 3)} steals ${pad(atQueue, 3)} (+${s.stolen.length - atQueue} in the next 3 s, most live ${most}) | kept: ${fate}`);
  });
  // Ring slots are held for decay×ringLife even when inaudible.
  for (const [what, decay, br] of [['gem bell', 1.1, 0.5], ['ka-ching bell', 0.9, 0.45]]) for (const life of [7, 5]) {
    const hold = Math.min(decay * life, 6); const prime = -8.686 * hold / decay; const hum = -8.686 * hold / (1.3 * decay) + 20 * Math.log10(br);
    console.log(`ring slot hold ×${life}: ${what} (decay ${decay}) frees at ${hold.toFixed(2)} s, prime ${prime.toFixed(0)} dB, hum ${hum.toFixed(0)} dB re the prime's start (then a 30 ms release)`); }
}

// ---------- the speed estimator (FeelSpeedEstimator, .hinge) for onset/tail of the creak ----------
function oneEuro(minCutoff = 2, beta = 0.12, dCutoff = 1.5) { let v = null, dv = 0, lt = null; const al = (c, dt) => { const r = TWO_PI * c * dt; return r / (r + 1); };
  return { reset() { v = null; dv = 0; lt = null; }, f(x, t) { if (v === null) { v = x; lt = t; dv = 0; return x; } const dt = Math.min(Math.max(t - lt, 1 / 240), 0.2); dv += ((x - v) / dt - dv) * al(dCutoff, dt); v = v + (x - v) * al(minCutoff + beta * Math.abs(dv), dt); lt = t; return v; } }; }
function estimator(deadband = 0.4, breakaway = 0.10) { const sm = oneEuro(); let ts = [], vs = [], sampleSpeed = 0, speed = 0, last = null, lastFrame = null, anchor = null, moveStart = -Infinity;
  const win = () => { const c = ts.length; if (c < 2) return 0; const nw = ts[c - 1], st = nw - 0.25; let base = 0; for (let i = c - 2; i >= 0; i--) if (ts[i] <= st) { base = i; break; } let path = 0; for (let k = base + 1; k < c; k++) path += Math.abs(vs[k] - vs[k - 1]); const net = Math.abs(vs[c - 1] - vs[base]); let sh = 1 / 60; if (breakaway > 0 && nw - moveStart < breakaway) sh = Math.max(sh, breakaway); return Math.min(0.5 * (net + path) / Math.max(nw - ts[base], sh), 720); };
  const restart = (x, t) => { if (last !== null) { const q = Math.max(t - last - 0.12, 0); speed = Math.min(speed, sampleSpeed * Math.exp(-q / 0.15)); } sm.reset(); ts = [t]; vs = [sm.f(x, t)]; last = t; sampleSpeed = 0; anchor = x; moveStart = t; };
  return { sample(x, t) { if (last === null || t - last > 0.25) return restart(x, t); if (t - last > 0.12) moveStart = t; let val = x; if (deadband > 0) { if (anchor !== null && Math.abs(x - anchor) < deadband) val = anchor; else anchor = x; } ts.push(t); vs.push(sm.f(val, t)); if (ts.length > 40) { ts.shift(); vs.shift(); } last = t; sampleSpeed = win(); },
    speed(t) { if (last === null) return 0; if (lastFrame !== null && t <= lastFrame) return speed; const dt = lastFrame === null ? 0 : t - lastFrame; lastFrame = t; const age = t - last; if (age <= 0.12) speed += (sampleSpeed - speed) * (1 - Math.exp(-Math.min(dt, 0.1) / 0.04)); else { speed *= Math.exp(-Math.max(Math.min(dt, age - 0.12), 0) / 0.15); if (speed < 1e-4) speed = 0; } return speed; } }; }
function sectionSpeed() {
  console.log('\n## CREAK TIMING through the real speed estimator (fake Duo: 30 Hz reports, ≥0.25° steps, nothing while still)');
  for (const v of [20, 30, 45]) {
    const est = estimator(); let ang = 110, lastRep = -1, lastAng = 110; const rows = []; let tAud = null, tLoud = null, tStop = null, tSilent = null;
    for (let f = 0; f < 120 * 2.0; f++) { const t = f / 120; const moving = t >= 0.2 && t < 1.2; if (moving) ang += v / 120;
      if (t - lastRep >= 1 / 30 && Math.abs(ang - lastAng) >= 0.25) { est.sample(Math.min(Math.max(ang, 97), 162), t); lastRep = t; lastAng = ang; }
      const s = est.speed(t); const lvl = SB.creakLevel(s);
      if (moving && tAud === null && lvl > 0.05) tAud = t - 0.2; if (moving && tLoud === null && lvl >= 0.95 * SB.creakLevel(v)) tLoud = t - 0.2;
      if (!moving && t >= 1.2 && tSilent === null && lvl === 0) tSilent = t - 1.2; }
    console.log(`${v}°/s hand: creak audible (level > 0.05) ${f1(1000 * tAud, 0)} ms after the hand starts; 95 % of its level at ${f1(1000 * tLoud, 0)} ms; silent ${f1(1000 * tSilent, 0)} ms after the hand stops (+ the bed's 0.05 s glide)`);
  }
}

function sectionHaptic() {
  console.log(`\n## HAPTIC TIMING [${P.name}] (Strong: ${P.layered ? `each transient KEPT, plus a ${P.burst * 1000} ms burst under it (×0.7, sharpness ≤ 0.5)` : `each transient REPLACED by a ${P.burst * 1000} ms burst at sharpness 0.4`})`);
  for (const n of [6, 9, 14]) { const t = R.cascadeTimes(n); const gaps = t.slice(1).map((x, i) => x - t[i]); const over = gaps.filter((g) => g < P.burst).length;
    console.log(`bank cascade n=${n}: gaps ${gaps.map((g) => (1000 * g).toFixed(0)).join(' ')} ms → ${over}/${gaps.length} Strong bursts overlap the next${P.layered ? ' (each still starts on its own crisp tap)' : ' (a smear, not taps)'}`); }
  const sp = R.spillTimes(10); const sg = sp.slice(1).map((x, i) => x - sp[i]); console.log(`coin spill n=10: gaps ${sg.map((g) => (1000 * g).toFixed(0)).join(' ')} ms`);
  const level = (s) => Math.pow(Math.min(Math.max((s - 14) / 30, 0), 1), P.hapticExp);
  for (const sp2 of [14.5, 16, 18, 20, 25, 30, 40]) { const lvl = level(sp2); const strong = Math.min(lvl * 1.4, 1);
    console.log(`creak texture at ${sp2}°/s: Normal ${lvl.toFixed(2)}  Strong ${strong.toFixed(2)} ±${(strong * P.jitter).toFixed(2)} (jitter ±${P.jitter * 100} %)  sharpness ${(0.3 + 0.3 * Math.min(Math.max((sp2 - 14) / 40, 0), 1)).toFixed(2)}${strong < 0.25 ? '  <- under ~0.25: near threshold' : ''}`); }
  const tick = Math.min(P.quietTick * 1.15, 1);
  for (const v of [5, 10, 14]) console.log(`quiet ticks at ${v}°/s: ${(v / 4).toFixed(1)} per second (Strong: ${P.layered ? `a tap at ${tick.toFixed(2)} sharpness 0.7 + a 40 ms burst at ${(P.quietTick * 0.7).toFixed(2)}` : `55 ms bursts at ${tick.toFixed(2)}`})`);
  console.log(`bite: second snap at ${P.biteSnap * 1000} ms (the sound's last tooth-clack is at 60 ms) → offset ${Math.round(Math.abs(P.biteSnap - 0.06) * 1000)} ms`);
  console.log(`heartbeat haptic: Stirring ${P.softHeart ? 'tap 0.40 + tap 0.28 at 0.18 s (soft lub-dub, 60 bpm)' : 'none'}; Waking tap 0.75 + tap 0.5 at 0.14 s (110 bpm)`);
}

// Proposed parameter changes, measured against the shipped values.
function sectionVariants() { using('r11', sectionVariantsR11); }
function sectionVariantsR11() {
  console.log('\n## REVIEW-6 VARIANTS, measured against the R11 recipes (one-shots alone; master 1.25 unless stated)');
  const d = makeDice(13);
  const show = (name, cmds, secs, opts) => { const { out } = renderShot(cmds, secs, opts); const spk = speakerProxy(out);
    console.log(`${pad(name, 60)} peak ${pad(f1(db(peakOf(out))), 6)} mom ${pad(f1(lufsMomentaryMax(out)), 6)} spk mom ${f1(lufsMomentaryMax(spk))}`); };
  const hb = (fast, o) => { const k = fast ? 1 : 0.75, gap = fast ? 0.14 : 0.18; return [
    { type: 'tone', start: o.f0 ?? 120, end: o.f1 ?? 62, glide: 0.06, duration: 0.16, attack: 0.004, decay: 0.05, gain: (o.g ?? 0.2) * k, harmonics: o.h ?? 4 },
    { type: 'noise', mode: o.nm ?? 'lp', cutoff: o.nc ?? 260, q: 0.9, attack: 0.002, decay: 0.03, gain: (o.ng ?? 0.1) * k },
    { type: 'tone', start: (o.f0 ?? 120) - 10, end: (o.f1 ?? 62) - 2, glide: 0.06, duration: 0.14, attack: 0.004, decay: 0.045, gain: (o.g2 ?? 0.13) * k, harmonics: o.h ?? 4, delay: gap },
    { type: 'noise', mode: o.nm ?? 'lp', cutoff: (o.nc ?? 260) - 20, q: 0.9, attack: 0.002, decay: 0.025, gain: (o.ng2 ?? 0.06) * k, delay: gap }]; };
  show('heartbeat slow, shipped', hb(false, {}), 0.6);
  show('heartbeat slow, 150→80 Hz, harmonics 8, noise lp 260 → bp 500 Hz', hb(false, { f0: 150, f1: 80, h: 8, nm: 'bp', nc: 500 }), 0.6);
  show('heartbeat fast, shipped', hb(true, {}), 0.6);
  show('heartbeat fast, 150→80 Hz, harmonics 8, noise lp 260 → bp 500 Hz', hb(true, { f0: 150, f1: 80, h: 8, nm: 'bp', nc: 500 }), 0.6);
  const chompV = (o) => { const c = R.chomp(makeDice(3), o); if (o.ring) c[3] = { ...c[3], gain: o.ring, partials: 5 }; if (o.crack) c[2] = { ...c[2], gain: o.crack }; return c; };
  show('CHOMP shipped', chompV({}), 1.2);
  show('CHOMP thump 0.36→0.26 end 48→70 harm 6→8; wood 340 Hz 0.26→0.36 (5 partials)', chompV({ thumpGain: 0.26, thumpEnd: 70, thumpHarm: 8, ring: 0.36 }), 1.2);
  const crunch = [...chompV({ thumpGain: 0.26, thumpEnd: 70, thumpHarm: 8, ring: 0.36 }),
    { type: 'noise', mode: 'bp', cutoff: 750, to: 450, sweep: 0.08, q: 1.2, attack: 0.001, decay: 0.05, gain: 0.32, label: 'chomp' }];
  show('  + a mid "crunch" (bp noise 750→450 Hz, Q 1.2, decay 0.05, gain 0.32)', crunch, 1.2);
  const win50 = (sig) => { const k = kWeight(sig); const w = Math.floor(0.05 * SR); let best = -Infinity; for (let i = 0; i + w <= k.length; i += w / 5) { let s = 0; for (let j = i; j < i + w; j++) s += k[j] * k[j]; best = Math.max(best, -0.691 + 10 * Math.log10(s / w + 1e-20)); } return best; };
  const lean = chompV({ thumpGain: 0.2, thumpEnd: 70, thumpHarm: 8, ring: 0.36, crack: 0.34 }); lean[1] = { ...lean[1], gain: 0.2 };
  lean.push({ type: 'noise', mode: 'bp', cutoff: 750, to: 450, sweep: 0.08, q: 1.2, attack: 0.001, decay: 0.05, gain: 0.32, label: 'chomp' });
  for (const [name, cmds] of [['CHOMP shipped', chompV({})], ['CHOMP +crunch (above)', crunch], ['CHOMP lean: thump 0.2, sub noise 0.34→0.2, crack 0.26→0.34, wood 0.36, +crunch', lean]]) {
    const { out } = renderShot(cmds, 1.2); console.log(`  ${pad(name, 78)} 50 ms max: full ${f1(win50(out))}  spk ${f1(win50(speakerProxy(out)))} LUFS  peak ${f1(db(peakOf(out)))}`); }
  { const s = new Synth(); const b0 = SB.heistBed({ speed: 45, stage: 'waking', noise: 0.98 }); s.setBed(b0); s.bed = { ...b0 }; const out = new Float64Array(SR); s.render(SR, out); console.log(`  reference: 45°/s creak + growl bed, 50 ms max: full ${f1(win50(out))} spk ${f1(win50(speakerProxy(out)))}`); }
  // The CHOMP against the creak it usually lands on (40°/s, playing → resting share).
  for (const share of [0.8, 0.3]) { const s = new Synth({ voiceCount: 96 }); const b0 = SB.heistBed({ speed: 45, stage: 'waking', noise: 0.98 }); s.setBed(b0); s.bed = { ...b0 };
    const out = new Float64Array(3 * SR); s.render(SR, out, 0); const b1 = SB.heistBed({ speed: 45, stage: 'waking', noise: 1 }); SB.applyCreak(b1, 45, share); b1.growl = 0; b1.snore = 0; b1.motif = 0; b1.glide = 0.35; s.setBed(b1);
    s.play(crunch); s.render(2 * SR, out, SR); const pre = speakerProxy(out);
    console.log(`  CHOMP(+crunch) on a 45°/s creak, resting creak share ${share}: spk creak before ${f1(lufsMomentaryMax(pre.subarray(0, SR)))} → spk with CHOMP ${f1(lufsMomentaryMax(pre.subarray(SR, SR + SR / 2)))} LUFS`); }
  const ka = (chord, glass) => { const cmds = [{ type: 'noise', mode: 'hp', cutoff: 2500, q: 0.7, attack: 0.0005, decay: 0.012, gain: 0.1 }];
    chord.forEach((f, i) => cmds.push({ type: 'ring', kind: 'bell', fundamental: f, partials: 5, decay: 0.9, brightness: 0.45, gain: 0.075, delay: 0.03 + 0.012 * i, seed: 5 + i }));
    cmds.push({ type: 'ring', kind: 'glass', fundamental: 2349.3, partials: 2, decay: 0.35, brightness: 0.3, gain: glass, delay: 0.06, seed: 9 }); return cmds; };
  show('ka-ching shipped (D4 F#4 A4 bells, glass 0.04)', ka([293.66, 369.99, 440], 0.04), 2.5);
  show('ka-ching up an octave (D5 F#5 A5), glass 0.04 → 0.07', ka([587.33, 739.99, 880], 0.07), 2.5);
  show('coin clink shipped', R.coinClink(makeDice(4)), 0.4);
  show('coin clink ×1.8 gain (0.09/0.06/0.035/0.045 → 0.16/0.11/0.065/0.08)', R.coinClink(makeDice(4), 1.8), 0.4);
  show('wake sting shipped', R.wakeSting(), 1.5);
  const ws = R.wakeSting(); ws[2] = { ...ws[2], start: 293.66, harmonics: 5, gain: 0.06 }; ws[3] = { ...ws[3], start: 311.13, harmonics: 5, gain: 0.06 };
  show('wake sting, sour 2nd up an octave (D4/D#4, harmonics 5, 0.06)', ws, 1.5);
  console.log('\n## MASTER GAIN 1.25 → 2.0 (+4.1 dB): the mix and the moments');
  for (const master of [1.25, 2.0]) {
    for (const [name, p, shot] of [['asleep still', { speed: 0, stage: 'asleep', noise: 0.1 }], ['asleep 20°/s', { speed: 20, stage: 'asleep', noise: 0.2 }], ['waking 40°/s', { speed: 40, stage: 'waking', noise: 0.95 }], ['bite over waking', { speed: 0, stage: 'waking', noise: 0.95 }, 'bite'], ['bank 400 over asleep', { speed: 0, stage: 'asleep', noise: 0.1 }, 'bank']]) {
      const s = new Synth({ voiceCount: 96 }); const bed = SB.heistBed({ ...p, master }); s.setBed(bed); s.bed = { ...bed }; const n = 5 * SR; const out = new Float64Array(n); s.render(SR, out, 0); const dd = makeDice(5);
      if (shot === 'bite') s.play([...R.chomp(dd), ...R.coinSpill(300, dd)]); if (shot === 'bank') s.play([...R.bank(400, true, dd), ...R.chainUp(3, 1.55, dd), ...R.relicChoir(1.15)]);
      s.render(4 * SR, out, SR); const seg = out.subarray(SR);
      console.log(`master ${master}  ${pad(name, 22)} integrated ${pad(f1(lufsIntegrated(seg)), 6)} LUFS  momentary max ${pad(f1(lufsMomentaryMax(seg)), 6)}  peak ${f1(db(peakOf(seg)))} dBFS`);
    }
  }
}

// FeelTests `tenSecondsOfMixedEventsStaySane`-like run: fraction of samples over 0.6 ("hot", test bound < 2 %).
function sectionHot() {
  console.log('\n## "hot" fraction (|x| > 0.6) in the 10 s mixed-events test scenario (FeelTests bound < 2 %), R11 vs R12');
  for (const [cfg, master] of [['r11', 1.25], ['r12', 1.8], ['r12', 2.0]]) using(cfg, () => {
    const opts = {}; const s = new Synth(opts); const d = makeDice(1); const n = 10 * SR; const out = new Float64Array(n); let nextCue = 0, idx = 0;
    for (let i = 0; i < n; i += 480) { const t = i / SR; const speed = t < 3 ? 6 + 4 * t : (t < 5 ? 45 : 12); const noise = Math.min(t / 9, 1);
      const stage = noise < 0.35 ? 'asleep' : noise < 0.7 ? 'stirring' : 'waking';
      s.setBed(SB.heistBed({ speed, noise, stage, openness: Math.min(t / 4, 1), drag: t > 6 && t < 7 ? 900 : 0, torch: 20 - t, master }));
      if (t >= nextCue) { nextCue += 0.35; idx++; const k = idx % 9; const cue = k === 0 ? R.chomp(d) : k === 1 ? R.itemBagged('copper', d) : k === 2 ? R.bank(800, true, d) : k === 3 ? R.heartbeat(true) : k === 4 ? [{ type: 'ring', kind: 'glass', fundamental: 2093, partials: 3, decay: 0.2, brightness: 0.35, gain: 0.045 }] : k === 5 ? R.relicChoir() : k === 6 ? R.itemDropped(d) : k === 7 ? R.wakeSting() : [...R.newBest(), ...R.coinClink(d, 0.45, 0.1)]; s.play(cue); }
      s.render(480, out, i); }
    let hot = 0; for (const x of out) if (Math.abs(x) > 0.6) hot++;
    console.log(`[${P.name}] master ${master}: hot ${(100 * hot / n).toFixed(2)} %, peak ${f1(db(peakOf(out)), 2)} dBFS (${peakOf(out).toFixed(3)}), integrated ${f1(lufsIntegrated(out))} LUFS, steals ${s.stolen.length}`);
  });
}

// ---------- R12: before → after, and the FeelTests bounds ----------
const win50 = (sig) => { const k = kWeight(sig); const w = Math.floor(0.05 * SR); let best = -Infinity; for (let i = 0; i + w <= k.length; i += w / 5) { let s = 0; for (let j = i; j < i + w; j++) s += k[j] * k[j]; best = Math.max(best, -0.691 + 10 * Math.log10(s / w + 1e-20)); } return best; };
function creakAlone(sp, master = P.master) {
  const s = new Synth(); const bed = SB.heistBed({ speed: sp, ambience: 0, stage: 'waking', noise: 0, master }); bed.growl = 0; s.setBed(bed); s.bed = { ...bed };
  const n = 3 * SR; const out = new Float64Array(n); s.render(n, out); return out.subarray(SR);
}
// The bite lands on a 45°/s slam that keeps going: the director's bite frame leaves play, so the bed drops the creak to
// `restingCreakShare` with `duckGlide` (R12: 0.03 s for `duckHold`; R11: the 0.35 s fade) and the CHOMP plays.
function biteOnSlam(o = {}, speed = 45) {
  const s = new Synth(); const b0 = SB.heistBed({ speed, stage: 'waking', noise: 0.98 }); s.setBed(b0); s.bed = { ...b0 };
  const out = new Float64Array(2 * SR); s.render(SR, out, 0);
  const b1 = SB.heistBed({ speed, stage: 'waking', noise: 1, playing: false }); b1.glide = o.duckGlide ?? P.duckGlide;
  const duckShare = o.duckShare ?? P.duckShare; const ducked = { ...b1 }; SB.applyCreak(ducked, speed, duckShare); s.setBed(ducked);
  s.play(R.chomp(makeDice(3), o)); const hold = Math.floor((o.duckHold ?? P.duckHold) * SR / 480) * 480; s.render(hold, out, SR);
  const b2 = { ...b1, glide: 0.35 }; s.setBed(b2); s.render(SR - hold, out, SR + hold); const spk = speakerProxy(out);
  return { before: win50(spk.subarray(SR / 2, SR)), moment: win50(spk.subarray(SR, SR + SR / 4)), after: lufsIntegrated(spk.subarray(SR + SR / 2)),
    before400: lufsMomentaryMax(spk.subarray(SR / 2, SR)), moment400: lufsMomentaryMax(spk.subarray(SR, SR + SR / 2)),
    alone: win50(speakerProxy(renderShot(R.chomp(makeDice(3), o), 1.2).out)) };
}
function sectionChompTry() { // node tools/audio-probe.js chomp '{"crunch":0.4}'
  const o = JSON.parse(process.argv.slice(3).find((a) => a.startsWith('{')) || '{}');
  for (const sp of [30, 45, 60]) { const r = biteOnSlam(o, sp); console.log(`[${P.name}] ${JSON.stringify(o)} on ${sp}°/s: CHOMP alone spk50 ${f1(r.alone)} | creak before ${f1(r.before)} → moment ${f1(r.moment)} (${r.moment > r.before ? 'wins' : 'LOSES'} by ${f1(r.moment - r.before)}) → after ${f1(r.after)} | 400 ms: before ${f1(r.before400)} moment ${f1(r.moment400)} (${f1(r.moment400 - r.before400)})`); }
}
function metrics() {
  const m = {};
  for (const sp of [16, 20, 30, 40, 60]) { const out = creakAlone(sp); const b = bands(out, 0, out.length);
    m[`creak ${sp}°/s RMS dBFS`] = db(rms(out)); m[`creak ${sp}°/s spk LUFS`] = lufsIntegrated(speakerProxy(out));
    m[`creak ${sp}°/s centroid Hz`] = b.centroid; m[`creak ${sp}°/s periodicity r`] = periodicity(out, 1000).r; }
  const shot = (name, cmds, secs) => { const { out } = renderShot(cmds, secs); m[`${name} peak dBFS`] = db(peakOf(out)); m[`${name} mom LUFS`] = lufsMomentaryMax(out); m[`${name} spk LUFS`] = lufsMomentaryMax(speakerProxy(out)); return out; };
  const d = makeDice(7);
  shot('coin clink', R.coinClink(d), 0.4);
  shot('bag thud + copper', R.itemBagged('copper', d), 0.6);
  shot('ka-ching alone', R.bank(30, false, d).filter((c) => c.label === 'kaching'), 3.0);
  shot('bank 30 g', R.bank(30, false, d), 3.0);
  shot('heartbeat slow', R.heartbeat(false), 0.6);
  shot('heartbeat fast', R.heartbeat(true), 0.6);
  shot('wake sting', R.wakeSting(), 1.5);
  shot('creak accent', R.creakAccent(d), 0.4);
  const chomp = shot('CHOMP', R.chomp(makeDice(3)), 1.2);
  m['CHOMP 50 ms max spk LUFS'] = win50(speakerProxy(chomp));
  { const s = new Synth(); const b0 = SB.heistBed({ speed: 45, stage: 'waking', noise: 0.98 }); s.setBed(b0); s.bed = { ...b0 }; const out = new Float64Array(SR); s.render(SR, out); m['45°/s creak + growl 50 ms max spk LUFS'] = win50(speakerProxy(out)); }
  { // The bite lands on a 45°/s slam: play stops, so the creak drops to the resting share (the duck).
    const s = new Synth(); const b0 = SB.heistBed({ speed: 45, stage: 'waking', noise: 0.98 }); s.setBed(b0); s.bed = { ...b0 };
    const r = biteOnSlam();
    m['bite on a 45°/s slam: creak before, spk 50 ms'] = r.before; m['bite on a 45°/s slam: CHOMP moment, spk 50 ms'] = r.moment;
    m['bite on a 45°/s slam: creak 0.5–1 s after, spk LUFS'] = r.after; }
  for (const [name, p] of [['asleep still', { speed: 0, stage: 'asleep', noise: 0.1 }], ['asleep 20°/s', { speed: 20, stage: 'asleep', noise: 0.2 }],
    ['stirring still + heart', { speed: 0, stage: 'stirring', noise: 0.5, heart: 1.0 }], ['waking still + heart', { speed: 0, stage: 'waking', noise: 0.85, heart: 60 / 110, fast: true }],
    ['waking 40°/s', { speed: 40, stage: 'waking', noise: 0.95, heart: 60 / 110, fast: true }]]) {
    const s = new Synth(); const bed = SB.heistBed(p); s.setBed(bed); s.bed = { ...bed }; const n = 10 * SR; const out = new Float64Array(n); let next = 0.25;
    for (let i = 0; i < n; i += 480) { if (p.heart && i / SR >= next) { s.play(R.heartbeat(!!p.fast)); next += p.heart; } s.render(480, out, i); }
    m[`scene ${name} LUFS`] = lufsIntegrated(out.subarray(SR)); m[`scene ${name} spk LUFS`] = lufsIntegrated(speakerProxy(out).subarray(SR)); m[`scene ${name} peak dBFS`] = db(peakOf(out)); }
  { const s = new Synth(); const bed = SB.heistBed({ speed: 0, stage: 'asleep', noise: 0.1 }); s.setBed(bed); s.bed = { ...bed }; const out = new Float64Array(4 * SR); s.render(SR, out, 0); const dd = makeDice(5);
    s.play([...R.bank(1700, true, dd), ...R.chainUp(5, 1.55, dd), ...R.relicChoir(1.15), ...R.newBest(1.4)]); s.render(3 * SR, out, SR);
    m['bank 1,700 g + chain 5 + relic + best: moment max LUFS'] = lufsMomentaryMax(out.subarray(SR)); m['bank 1,700 g moment: voices stolen'] = s.stolen.length; m['bank 1,700 g moment: peak dBFS'] = db(peakOf(out)); }
  return m;
}
function sectionCompare() {
  console.log('\n## R11 → R12 (each set at its own master: R11 1.25, R12 1.8)');
  const a = using('r11', metrics), b = using('r12', metrics);
  for (const k of Object.keys(a)) { const x = a[k], y = b[k]; const dd = y - x; const n = /centroid/.test(k) ? 0 : (/periodicity/.test(k) ? 2 : 1);
    console.log(`${pad(k, 58)} ${pad(f1(x, n), 8)} → ${pad(f1(y, n), 8)} (${dd >= 0 ? '+' : ''}${f1(dd, n)})`); }
}
// Ports of the FeelTests that the R12 values have to keep passing (render-based ones), on the current config.
function sectionTests() {
  console.log(`\n## FeelTests bounds [${P.name}, master ${P.master}, ${P.voiceCount} voices]`);
  const ok = (name, pass, detail) => console.log(`${pass ? 'PASS' : 'FAIL'}  ${pad(name, 64)} ${detail}`);
  const homeBed = (sp) => { const b = emptyBed(); b.master = P.master; b.glide = 0.005; b.snorePeriod = 4.25; SB.applyCreak(b, sp, 0.85); return b; };
  const renderBed = (bed, secs, each) => { const s = new Synth(); s.setBed(bed); const n = Math.floor(secs * SR / 512) * 512; const out = new Float64Array(n);
    for (let i = 0, blk = 0; i < n; i += 512, blk++) { if (each) each(s, blk, i / SR); s.render(512, out, i); } let hot = 0; for (const x of out) if (Math.abs(x) > 0.6) hot++; return { rms: rms(out), peak: peakOf(out), hot: hot / n, out, s }; };
  // creakRendersSilentBelowTheQuietSpeedAndGrowsWithSpeed
  const lv = [17, 30, 60].map((sp) => renderBed(homeBed(sp), 1.5));
  ok('creak grows: 17°/s rms > 0.005', lv[0].rms > 0.005, lv[0].rms.toFixed(4));
  ok('creak grows: 30°/s > 2 × 17°/s', lv[1].rms > 2 * lv[0].rms, `${lv[1].rms.toFixed(4)} vs ${(2 * lv[0].rms).toFixed(4)}`);
  ok('creak grows: 60°/s > 30°/s and < 0.3 rms, peak < 1', lv[2].rms > lv[1].rms && lv[2].rms < 0.3 && lv[2].peak < 1, `${lv[2].rms.toFixed(4)}, peak ${lv[2].peak.toFixed(3)}`);
  // creakFollowsASweepWithoutBlowingUp (home bed at 60 Hz, 0 → 70 → 0 over 4 s)
  { const r = renderBed(homeBed(0), 4, (s, blk, t) => { const b = homeBed(70 * Math.sin(Math.PI * t / 4)); b.glide = 0.05; s.setBed(b); });
    ok('sweep: rms > 0.01, hot < 1 %, peak < 1', r.rms > 0.01 && r.hot < 0.01 && r.peak < 1, `rms ${r.rms.toFixed(4)}, hot ${(100 * r.hot).toFixed(3)} %, peak ${r.peak.toFixed(3)}`); }
  // eachContinuousLayerIsAudibleButGentle
  for (const [name, set] of [['snore', (b) => { b.snore = 1; }], ['growl', (b) => { b.growl = 1; }], ['motif', (b) => { b.motif = 1; b.motifDensity = 1; }],
    ['dungeon', (b) => { b.drone = 1; b.dripRate = 2; b.crackle = 1; b.crackleRate = 12; }], ['rattle', (b) => { b.rattle = 1; b.rattleRate = 50; }]]) {
    const b = emptyBed(); b.master = P.master; b.glide = 0.01; b.snorePeriod = 4.25; set(b); const r = renderBed(b, 4.5);
    ok(`layer ${name}: 0.001 < rms < 0.1, peak < 0.9`, r.rms > 0.001 && r.rms < 0.1 && r.peak < 0.9, `rms ${r.rms.toFixed(4)} (${f1(db(r.rms))} dBFS), peak ${r.peak.toFixed(3)}`); }
  // The CHOMP is the biggest sound; the crack sits between a coin and the CHOMP (rendered, 0.4 s RMS from the onset).
  const shotRms = (cmds) => { const { out } = renderShot(cmds, 0.4); return { rms: rms(out), peak: peakOf(out) }; };
  let worstCoin = 0, worstCoinPeak = 0; const dc = makeDice(31); for (let i = 0; i < 40; i++) { const r = shotRms(R.coinClink(dc)); worstCoin = Math.max(worstCoin, r.rms); worstCoinPeak = Math.max(worstCoinPeak, r.peak); }
  let leastChomp = Infinity, leastCrackPeak = Infinity, mostCrack = 0; const dk = makeDice(32);
  for (let i = 0; i < 20; i++) { leastChomp = Math.min(leastChomp, shotRms(R.chomp(dk)).rms); const c = shotRms(R.creakAccent(dk)); leastCrackPeak = Math.min(leastCrackPeak, c.peak); mostCrack = Math.max(mostCrack, c.rms); }
  ok('CHOMP rms (0.4 s) > 2 × the loudest coin clink and > 2 × the loudest crack', leastChomp > 2 * worstCoin && leastChomp > 2 * mostCrack, `${leastChomp.toFixed(4)} vs coin ${worstCoin.toFixed(4)}, crack ${mostCrack.toFixed(4)} (×${(leastChomp / Math.max(worstCoin, mostCrack)).toFixed(2)})`);
  ok('crack peak (quietest) > coin clink peak (loudest): it cuts through', leastCrackPeak > worstCoinPeak, `${leastCrackPeak.toFixed(3)} vs ${worstCoinPeak.toFixed(3)}`);
  // tenSecondsOfMixedEventsNeverClipOrNaN: see `hot` (same scenario).
  // R12 new test: the biggest banks keep every voice (same scenario as the Swift test).
  for (const value of [1700, 9999]) {
    const bed = SB.heistBed({ speed: 0, stage: 'asleep', noise: 0.1 }); bed.glide = 0.01; const s = new Synth(); s.setBed(bed); const buf = new Float64Array(512);
    const run = (secs) => { for (let k = 0; k < Math.floor(secs * SR / 512); k++) s.render(512, buf); };
    const d = makeDice(21); run(2); s.play(R.itemBagged('gem', d)); run(0.5); s.play(R.itemBagged('copper', d)); run(0.25);
    const moment = [...R.bank(value, true, d), ...R.chainUp(5, 1.55, d), ...R.relicChoir(1.15), ...R.newBest(1.4)];
    const before = s.stolen.length; s.play(moment); run(1 / 100); const live = s.voices.filter((v) => v.active).length; run(3);
    ok(`bank ${value} g + chain 5 + relic + best: ${moment.length} commands (> 48), no steals`, moment.length > 48 && s.stolen.length === 0 && before === 0, `steals ${s.stolen.length}, live right after ${live}`);
  }
  // R12 (founder): the robbed grumble is audible but under the dungeon bed (and the snore it replaces).
  { const lay = (set) => { const b = emptyBed(); b.master = P.master; b.glide = 0.01; b.snorePeriod = 4.25; set(b); const r = renderBed(b, 11); return { ...r, lufs: lufsIntegrated(r.out.subarray(SR)) }; };
    const g = lay((b) => { b.grumble = 0.6; }), dn = lay((b) => { b.drone = 1; b.dripRate = 0.5; b.crackle = 0.4; b.crackleRate = 4; }), sn = lay((b) => { b.snore = 0.78; });
    ok('robbed grumble (0.6): 0.001 < rms, peak < 0.9, under the dungeon bed and the snore', g.rms > 0.001 && g.peak < 0.9 && g.lufs < dn.lufs && g.lufs < sn.lufs, `${f1(g.lufs)} LUFS (rms ${g.rms.toFixed(4)}) vs bed ${f1(dn.lufs)}, snore ${f1(sn.lufs)}`); }
  // R12 new test: a ring frees its slot after decay × 5.
  { const s = new Synth(); const b = emptyBed(); b.master = P.master; s.setBed(b); s.play([{ type: 'ring', kind: 'chime', fundamental: 880, partials: 3, decay: 0.2, gain: 0.05 }]);
    const buf = new Float64Array(512); const live = (secs) => { for (let k = 0; k < Math.floor(secs * SR / 512); k++) s.render(512, buf); return s.voices.filter((v) => v.active).length; };
    const at08 = live(0.8); const at115 = live(0.35); ok('a 0.2 s ring is live at 0.8 s and free by 1.15 s (×5 = 1.0 s; ×7 would be 1.4 s)', at08 === 1 && at115 === 0, `${at08} / ${at115}`); }
}

// ---------- main ----------
const which = require.main === module ? (process.argv[2] || 'all') : 'none';
if (which === 'all' || which === 'creak') sectionCreak({}, `CREAK [${P.name}] (steady speed, creak layer only, after master ${P.master} + limiter)`);
if (which === 'try') { // node tools/audio-probe.js try '{"bodyGain":0.2}' 30
  if (process.argv[4]) SB.grainBase = Number(process.argv[4]);
  sectionCreak(JSON.parse(process.argv[3] || '{}'), 'CREAK variant ' + (process.argv[3] || '{}') + ' grainBase ' + (SB.grainBase ?? P.grainBase));
}
if (which === 'chomp') sectionChompTry();
if (which === 'all' || which === 'compare') sectionCompare();
if (which === 'all' || which === 'tests') sectionTests();
if (which === 'all' || which === 'speed') sectionSpeed();
if (which === 'all' || which === 'shots') { sectionShots(); sectionChompVariants(); }
if (which === 'all' || which === 'mix') sectionMix();
if (which === 'all' || which === 'voices') sectionVoices();
if (which === 'all' || which === 'haptic') sectionHaptic();
if (which === 'all' || which === 'variants') sectionVariants();
if (which === 'all' || which === 'hot') sectionHot();

module.exports = { GRUMBLE, SR, CFG, using, Synth, SB, R, makeDice, renderShot, rms, db, peakOf, lufsMomentaryMax, lufsIntegrated, speakerProxy, win50, biteOnSlam, emptyBed, get P() { return P; } };
