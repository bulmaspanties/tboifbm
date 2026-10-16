# Gridiron

A mod for **The Binding of Isaac: Repentance+** (all DLC) that adds American football gear.
None of the items replaces a vanilla item, and none is just cosmetic: each one has its own mechanic.
It uses only the vanilla Lua API, so REPENTOGON is **not** required.

## Items

| Item | Type | Pools | What it does |
|---|---|---|---|
| **Football Helmet** | Passive (Q3) | Treasure | **Tackle:** run in a straight line for ~1s and Isaac starts glowing. Running into enemies then deals 3× damage + 5, knocks them back hard and confuses them. You take no contact damage while tackling. **Facemask:** 50% chance to block enemy shots that hit you from the direction you're facing. |
| **Shoulder Pads** | Passive (Q2) | Treasure, Shop | 25% chance to **deflect** enemy shots back so they hit enemies. Taking damage sets off a **shockwave** that shoves enemies away and destroys nearby shots. With the Helmet, every tackle also sets off a smaller shockwave. |
| **Team Jersey** | Passive (Q2) | Treasure, Golden Chest | You get a **jersey number** (1–99) for the run. Every N shots (N = 3–9, set by your number) you throw a **football**: 2× damage, piercing, spectral. **Pre-snap:** enemies freeze briefly when you enter a room. |
| **Football Cleats** | Passive (Q2) | Treasure, Shop | +0.2 Speed. Running **10 yards** in an uncleared room earns a **First Down**: +0.5 Damage until you leave the room (max 4 per room). |
| **Eye Black** | Passive (Q2) | Treasure, Shop | +1 Luck. Tears do up to **+50% damage the farther they travel**. Makes you immune to **Curse of Darkness**. |
| **Padded Pants** | Trinket | Trinket pool | 25% chance to ignore damage from touching enemies (golden or Mom's Box raises it, up to 60%). |

### Set bonus: Suited Up
Hold **3 or more** of the five gear collectibles to get **Suited Up**: +1 Damage, and the Helmet's tackle winds up twice as fast.

## Installing (local)
1. Copy this folder into your Isaac `mods` directory, e.g.
   `…/Steam/steamapps/common/The Binding of Isaac Rebirth/mods/gridiron`
2. Launch the game with mods enabled and turn on **Gridiron** in the Mods menu.
3. To test, spawn the items from the debug console (`~`), for example `giveitem Football Helmet` or `giveitem t Padded Pants`.

If **External Item Descriptions** is installed, every item shows its description.

## Layout
```
metadata.xml                  mod manifest
main.lua                      all item logic (tuning values in the Cfg table at the top)
content/items.xml             item definitions
content/itempools.xml         pool placement
resources/gfx/items/...       item and trinket sprites (32x32)
tools/make_sprites.py         regenerates the placeholder sprites (needs Pillow)
```

## Roadmap
- Worn costumes (helmet with facemask, pads, eye-black stripes) via `costumes2.xml` and `.anm2`
- Hand-drawn sprites to replace the generated placeholders
- Football tears with their own sprite and a spiral animation
- A transformation-style costume for Suited Up
- Balance pass after playtesting
