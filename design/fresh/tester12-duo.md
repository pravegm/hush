# Tester 12: first-time Duo player (images only)

I looked at 29 in-game captures from `artifacts/duo13/duo-screens/duo-screens/` (I skipped `raw/`), in this order: duo-ui-*, then duo-h*, then duo-0*. After that I looked at the store images D1 to D6. I turned each capture in my head so the mimic half was at the top.

## 1. Goal
The phone is a treasure chest, and the chest is a sleeping mimic. You open the lid slowly, drag the gold and gems into your bag, and bank them before the candle burns out. If you make too much noise it wakes up and bites. You get a score in gold, ranks ("Lockpick Rank 4, Next: Cat Burglar"), 24 relics to collect in a Codex, badges, and a Daily Dungeon.

## 2. What I physically do
- I stand the phone up like a little laptop. The bottom half lies flat and holds the chest inside (velvet, loot, HUD). The top half is the lid: the mimic's eye, tongue and teeth, plus a brass nameplate ("Wheezy Walt, Snorer · Wooden").
- I start nearly closed ("Lower the lid a little, nearly upright…"). Then I open the lid slowly ("Open the lid… slowly. Watch the noise.").
- When the inside lights up, I use a finger on the flat half: "Drag the loot into your bag". The bag is the pouch in the middle of the HUD. The "+6s" bottle looks like a pickup that adds candle time.
- When it starts waking I keep the phone still ("Freeze!").
- To bank, I ease the lid back down. I only learned this from store image D3, "Ease it down to bank". None of the in-game captures I saw show it.

## 3. Which half I lift, and how I knew
I lift the half with the mimic's eye and teeth. I knew from four things:
- In duo-ui-lesson-1-150 the first lesson puts a tag with an arrow on that half: "Lower this half a little".
- The teeth hang down toward the hinge, so that half reads as the lid.
- The cover screen shows a chest with its lid up.
- Settings has "Turn the chest round: puts the loot on the half that stays flat, the lid on the half you lift".

It was clear to me.

## 4. Meters and labels
- **NOISE bar:** fills from green to orange to red toward a little toothy mouth. When it's high, the label changes to **WAKING!**
- **Candle:** the run timer.
- **IN BAG:** loot you're holding that isn't safe yet. D2 says "not safe yet".
- **BANKED:** gold that's safe.
- **CHAIN ×1.1 to ×1.5 (Hush Chain):** a bonus for banking while it's still asleep.
- **Nameplate:** the mimic's name, temperament (Snorer, Light sleeper, Dreamer) and material (Wooden, Iron-bound). I guess this sets how easily it wakes. "GOLD ×1.5" seems to mark a golden mimic.
- **Zzz:** it's asleep. When the eye opens, it's waking.

## 5. Too fast, or closing the phone
- **Too fast:** the eye snaps open (duo-h2c-slam-creak), then the teeth slam down over the hinge: "CHOMP! Too loud!" with −10s on the candle (duo-h2-slam-bite, duo-h2-after-slam). Store image D5 says you also lose your bag ("−179").
- **Closing the phone:** the game pauses.
  - Partly closed (duo-h3-closing-card-55): a card says "Lift the lid a little to carry on. The mimic waits. Your candle does too." It has Carry on and Home buttons.
  - Fully shut (duo-04-cover-shut, duo-h7): the outer screen says "Open to carry on. Open me gently, then hold still. Your candle waits."
  - There is also an "Already open? Carry on / Home" fallback (duo-01-closed-105).
  - Reopening drops me back at "Open the lid… slowly" (duo-h4, duo-h6). This felt reassuring and fair.

## 6. Would I buy it from the App Store images alone?
Probably yes. The idea comes across in about three seconds: "Open the lid. Slowly." plus "Your Duo is the treasure chest." The mimic's eye in D2/D5 is a great hook, and the art is charming.

What would make me more likely to buy:
- Show the fold on more shots. Only D1 shows the phone half-open like a laptop. D2 to D6 are flat portrait screens, so they could be any phone game.
- Show a hand or finger. The phone-tilting part of the game is never shown.
- Make one shot that tells the whole loop as a strip: open, then drag, then ease down, then bank.
- Replace D6 (Codex) with something stronger. Half of it is empty space.
- Tell me how long a run lasts and how many mimic types there are.

## 7. Confusing, unreadable, cut off, ugly or broken
- **Banking isn't taught in game.** The captures never show a bank happening; IN BAG and BANKED are 0 in every in-game capture. I only learned "ease it down to bank" from D3. The lesson's "Lower the lid a little" (getting into position) could be confused with lowering to bank.
- **Loot appears, then disappears.** duo-ui-lesson-1-150 shows loot (coins, key, ruby) before you start. duo-ui-lesson-after-pose then goes dark, and duo-h6-reopened-120 and duo-h4-resumed-120 are dark and empty too. A first-timer could think the loot vanished. A hint like "open wider to see inside" would help.
- **Unexplained bag button.** The round coin-and-pouch button at the end of the HUD never has its purpose explained. Is it a bank button?
- **Results screen (duo-ui-results):**
  - The last chest in the row is labelled "out", which is unclear (candle out?).
  - The chest colours (brown vs maroon, with grey or gold stripes) aren't explained. The legend only covers zzz and glow.
  - The line "You lifted the Lullaby Music Box from right under its nose." runs almost edge to edge.
- **Settings (duo-ui-settings):** a scroll fade and chevron sit across the "Normal: If it wakes while you're being gentle, try Forgiving." helper line, so it looks half-erased. The "Turn the chest round" description also runs the full width.
- **Codex (duo-ui-codex, D6):** there's a large empty gap between the title and the grid, and the third row is faded and cut off. It reads as a scroll hint but looks unfinished.
- **Closing card (duo-h3-closing-card-55):** the grey subtitle "The mimic waits. Your candle does too." is low contrast on the brown wood.
- **Cover screen (duo-01-closed-105):** the black camera hole sits right on the drifting Zzz.
- **Store image D4:** the sparkle burst covers the "BANKED" label. The "Hushed! BANKED +429" text is faded and muddy on the dark velvet.
- **Raw captures:** many are upside down or sideways. I understand the game rotates itself on the device, so that's fine, but it's worth knowing for anyone reviewing captures.
- **Duplicate captures (minor):** duo-ui-pose-book and duo-ui-pose-card both just show the home menu turned sideways. I expected a pose prompt.

## 8. Scores
| | /10 |
|---|---|
| Understood | 8 |
| Want to play | 8 |
| Looks finished / premium | 8 |
| Would pay £1.99 | 7 |
