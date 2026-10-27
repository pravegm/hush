# Tester 2 — fresh player, Duo screens only (Hush)

I'd never seen the game before. I looked at the 16 frames in the order given and turned the upside-down ones round in my head. I didn't read any code or docs.

## 1. What's the goal?
"Hush — Don't wake the mimic." The phone is a treasure chest, and the chest is alive. It's a mimic (Dozy Doris, Wheezy Walt, Wary Wendell...) with a sleeping eye and teeth on the lid. You open it gently, grab the loot inside and "bank" it without waking it. A run ends with "gold banked" (2,794 in results), plus chests banked, "Hushed" and "Bites". There's also a Relic Codex of 24 collectibles and a Daily Dungeon.

## 2. What do I physically do with the phone?
Stand it up like a little laptop and use the hinge as the chest lid. Open it **slowly**. "Lift the lid... slowly", "Open the lid... slowly" and "Ease the lid down first" all say the speed is what matters. The tutorial seems to want a laptop-ish angle: at about 150° it said "A little lower...". Even the home screen reacts to the angle. At 150° the mimic's eye peeks out ("Shh... something's peeking"); at 120° it's shut.

## 3. Which half do I lift, and how did I know?
The half with the mimic's face (the eye and the nameplate). The pose screen shows two cards side by side: "Lift this half" glowing gold with an up arrow, and "Floor" in grey. The text says "The glowing half is the chest's lid". In the first lesson the lid half has a gold glowing border and a big "Lift this half ↑". The closing card says "Lift me ↑". It was very clear.

## 4. What do I do with my fingers?
Once it's open, the flat floor half shows the inside of the chest with loot (coin piles, purple gems, a gold trinket). The hint says "Drag the loot into your bag". I'm not sure where the bag is. I think it's the round icon with a "0" in the HUD strip at the floor's edge, but it doesn't look like a bag. Menus get normal taps.

## 5. What do the meters mean?
- **Segmented bar with a sleepy face**: I'm guessing it shows how close the mimic is to waking (or how calm it is). It was empty in almost every frame. It only lit up in duo-h4-resumed-120, where green blocks plus an orange one appeared, and I couldn't tell if green is good or bad.
- **Candle tube with a flame**: a timer, the "torch". It burns down while you play. It's lower in duo-h2-after-slam, and the closed-phone screen says "So is your torch", so it pauses when you shut the phone.
- **Coin stack, top-left**: gold this run. It was 0 in every gameplay frame.
- **Right-hand "0" with an icon**: unclear. It could be the bag or a chest count.

## 6. What happens if I go too fast?
I can only guess. Presumably the mimic wakes and bites you, since the results screen has a "Bites" count. None of the frames shows a bite or a wake-up. duo-h2-after-slam just shows a new chest ("Wary Wendell — Wooden chest ×1"), a shorter candle and still 0 gold. I couldn't tell whether slamming was a mistake, a way to bank the chest, or nothing at all.

## 7. What happens if I close the phone?
It pauses. Partly closed (about 60°) you get a card: "Lift the lid a little to carry on — The mimic waits. Your torch does too", with a Home link. Fully shut, the cover screen shows a sleepy chest face: "Open to carry on — The mimic is fast asleep. So is your torch." Opening it again resumes. That was clear and friendly.

## 8. Confusing, unreadable, ugly or broken (by frame)
- **duo-h2-after-slam**: No feedback on what the slam did: no bite, no "banked", no penalty, gold still 0. You just get the next chest. This is the moment that should teach the rule.
- **duo-02-half-135 / duo-03-wide-160**: "Drag the loot into your bag" but I couldn't see a bag. The coin piles look like cinnamon buns or cookies, not gold. Opening wider (160°) shows more loot and gems, yet the lesson told me to go lower at 150°. Is wide good (more loot) or bad (riskier)? It's not explained.
- **duo-h4-resumed-120**: The wake bar suddenly fills green and orange, with no label or legend. The mimic's eye now glints and the teeth look bigger. Does that mean danger? It's a good effect, but I couldn't read it.
- **Gameplay HUD (all game frames)**: Two counters, both "0", with no labels. The right-hand icon is ambiguous.
- **duo-ui-home-150 vs duo-ui-codex**: The home button says "Codex 9/24" but the Codex screen says "22 of 24 found". That's inconsistent and looks like a bug.
- **duo-ui-codex**: "Iron-bound chests and up hide them" is awkward wording. Many relics reuse the same shape in a new colour (2 crowns, 2 keys, 2 goblets, 2 teacups, 2 skulls, 2 mirrors, 2 horns), which looks a bit like a template. The names are funny though.
- **duo-ui-settings**: "Turn the chest round — Lifts the half that blurs as you fold, so the loot stays sharp" is jargon a player won't understand. The toggles sit on the upper half, which is the standing lid in laptop pose, so they'd be wobbly to tap. "Hushed" (results) is never defined either.
- **duo-ui-lesson-after-pose**: The whole screen dims and says "Ease the lid down first" straight after I was told to lift. Briefly feels like I did something wrong.
- **Orientation**: Once flipped round, every in-game frame reads correctly in the hand. I saw no real-life upside-down problems. The pose screen (duo-ui-pose-book) and the shut cover (duo-04-cover-shut) are drawn the other way, but that seems intended.

## 9. Scores
| Statement | /10 |
|---|---|
| I understood what to do | 7 |
| I want to play it | 7 |
| It looks finished / premium | 7 |
| I'd pay £1.99 | 6 |

The concept is charming and immediately fun: the chest is a sleeping monster and the lid is your phone. The pose and pause screens are excellent. What holds it back is that I never saw the core risk play out (waking, biting, banking), and the meters and bag aren't labelled. Show me one bite and one "banked!" moment and I'd go to 8–9.
