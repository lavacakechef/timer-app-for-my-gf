# CozyTime Design System

## Direction

Cute restraint: keep the productivity shell native, calm, and efficient. Put cuteness into the mascot, stickers, rewards, timer skins, empty states, and gentle completion feedback.

## Palette

- Canvas: `#FFF8F0`
- Surface: `#FFFFFF`
- Primary text: `#2B2420`
- Muted text: `#7A6B63`
- Focus jade: `#2F6F64`
- Mist blue: `#8CB8D0`
- Soft mint: `#DDEDE7`
- Reward persimmon: `#A8512D`
- Peach: `#FFD7B8`
- Sticker pink: `#F2AFC5`
- Night ink: `#211C24`
- Plum: `#6E4C77`
- Cool blue: `#496FA6`
- Wasabi accent: `#D9F06A`, text-safe wasabi: `#5F7114`
- Overdue: `#B75239`

Dark mode uses semantic colors instead of reusing light-mode browns:

- Dark canvas: `#151218`
- Dark surface: `#26212B`
- Dark raised surface: `#312936`
- Dark primary text: `#FFF8F0`
- Dark muted text: `#D8CBC3`

Do not hard-code light text colors into cards. Use semantic primary/secondary styles so the app does not become low-contrast in macOS dark mode.

## Mascot

The default mascot is Mochi, a tiny Maltese desk buddy with a twinkle sidekick. Mochi rotates small accents by time of day and changes accessories by state:

- Idle
- Focus
- Break
- Complete
- Overdue
- Countdown

Avoid sad or punitive states. Missed work should say “restart gently,” not “you failed.”

## Progression

Focus minutes, completed tasks, and habit checks create XP and paw coins. Coins unlock mascot accessories, room decor, and timer skins. Do not subtract XP, remove coins, or punish missed days.

The main reward loop should be visible on the first screen:

1. Pick a task.
2. Start a short focus block.
3. Earn XP and paws.
4. See Mochi/desk room change.
5. Spend paws on an accessory or room item.

Starter items must be cheap enough that one or two small sessions can unlock something. The room/shop should not feel like a distant endgame.

Current shop categories:

- Mascot accessories: bows, bandanas, headphones.
- Mascot outfits: hoodies, collars.
- Room decor: desk mats, lamps, calendars, speakers, wall lights, beds.
- Care treats: small non-punitive break rewards.

The dashboard uses daily cozy quests to make rewards legible without turning the app into a pressure streak product.

## Motion

- Completion stamp: 180-240ms.
- Timer breathing: slow and low amplitude.
- Idle mascot motion: rare, every 10-20 seconds at most.
- Reduce Motion: replace movement with fades or static color changes.

Current implementation keeps timer truth date-based and uses low-frequency visual updates. Avoid always-on decorative animation on idle screens.

## Tone

Use:

- “One small session?”
- “Pick the next tiny step.”
- “You showed up today.”
- “Short session counts.”

Avoid:

- “You failed.”
- “Don’t break the chain.”
- “Your streak is dying.”
- Fake urgency.
