# Changelog

## 0.9.1
- **Tainted Quarterback's art** now matches how he plays and starts: bare shoulder pads (no jersey) and a cracked, bloodied helmet, so he's clearly not the regular Quarterback.
- A new-look GitHub page, and release notes that include what changed.

## 0.9.0
- **The Franchise**: a two-phase final boss for floors 7-8. Phase 1 runs a route tree (slants, the go route, screen pass, Hail Mary, audibles); phase 2, the Stadium, brings the crowd wave, the Kiss Cam and falling goalposts.
- **The Kicker** and **Tainted Kicker**: Special Teams field goals that refund Tee charges and put points on the board; Tainted shanks heavy lobbed tears, every 4th one explodes.
- **Tainted Quarterback reworked: One Ball.** A single heavy boomerang football; no throwing again until it's back. Birthright: two balls.
- **Completion notes** for all four Gridiron characters (every vanilla mark, normal or hard), with callouts and menu pages.
- **Team Captains**: 15% of football enemies are gold champions with 50% more health and a twist each.
- **All-Pro transformation**: any 3 Gridiron items: +0.5 damage, every 4th shot a homing golden spiral, gold war paint.
- **Halftime show**: a rare room-clear event: pick a new Gridiron item or a soul heart.
- **Character fit**: horned characters get a helmet with reinforced horn holes so the horns come up through it.
- **Uniform colours** now also recolour Helmet and Team Jersey pedestals.

## 0.8.0
- **Fix: `gridiron give` could crash the game.** It placed ~30 pickups in one frame with the game's free-spot search, which could lock up once the floor filled. It now picks open floor tiles itself and drops one pickup every couple of frames.
- **4 Q4 items:** Championship Ring (x1.25 damage, a trophy item from every floor's boss), Hall of Fame Jacket (counts as 3 gear pieces: instantly Suited Up with a double bonus and 4x faster tackles), Golden Arm (every shot is a golden football), Hail Mary (6-charge active: a giant golden football that lands in a beam of holy light and a ring of footballs).
- **Character fit:** a roomy helmet for big-haired characters (Magdalene, Eve, Samson, Bethany, Lilith, Lazarus, Eden and tainted versions, Tainted Judas and Cain); no pants or cleats on The Lost, The Soul and Azazel.
- **Sounds:** crowd cheers and boos, a helmet clack on tackles and facemask blocks, the stadium horn and a scoring fanfare. Turn the crowd off in *visuals*.
- **Balance:** items also appear in Greed mode, the library (Playbook, which now counts toward Book Worm), beggars, crane games and golden chests; every passive works with Lemegeton; Mouthguard is Q1; facemask block 40%; Turf Burn toned down; the Coach's blitz can't snowball.
- The Linebacker introduces himself with a banner (a modded boss can't have its own VS screen without StageAPI).

## 0.7.0
- **8 new football enemies**: Lineman (digs in and charges), Blitzer (a fly that circles and dives), Punter (lobs spiked footballs), Huddle (four of them; hit one and they all break and rush you), Gatorade Cooler (bursts into slowing creep), Chain Gang (two refs on a chain that hurts), Sacker (tunnels and bursts up under you) and **The Coach** miniboss (calls Blitz, Prevent D and Pep Talk plays for the other enemies, and subs in Linemen). Each replaces the vanilla enemy it fights like.
- Monster art now follows Isaac's rules: giant black eyes with a glint, dark coloured interior lines instead of black, and something gross on everyone (blood, drool, torn seams, a hanging googly eye). The Mascot and Referee got the same treatment.
- **Pink** uniform colour for the helmet, jersey and pants.
- New `gridiron spawn <name>` console command.

## 0.6.1
- **Uniform colours:** a new *uniform* page in the settings menu lets you pick the helmet, jersey and pants colours (10 each). The jersey trim and stripes match each colour. Saved between runs, and reset with *team defaults*.

## 0.6.0
- **Chin Strap is now part of the Football Helmet**: every tackle stuns (bosses briefly). Tainted Quarterback starts with the Helmet instead, and Ground Game drops the strap.
- New **QB Wristband** (passive, counts toward Suited Up): +0.16 shot speed; every football you throw homes in and deals +25% damage.
- New **End Zone** (active, 4 charges): paints an end zone on the floor. +1.5 Damage while you stand in it, enemies inside are slowed, and Pigskin touchdowns in it count double.
- New **Turf Burn** (trinket): sprinting leaves burning scorch marks; tackled enemies get a big one.
- More synergies: Pony, White Pony and Taurus with Cleats; Thunder Thighs and Leo with Padded Pants; Money = Power and Greed's Gullet with the Super Bowl Ring; Marked and Eye of the Occult with the Foam Finger; homing items with the QB Wristband; Tarot Cloth with Coin Toss; Cleats with Turf Burn.
- **Footballs show your synergies**: they take on the colour of your tear effects (fire, poison, Ipecac, holy light, ice, charm, Dark Matter, Midas, homing).
- Workshop: refreshed description and preview, and step-by-step upload/update instructions in the README.

## 0.5.0
- **Base-game synergies:** Mars, Aries, Taurus and size-up items with tackles; Magneto and Telekinesis with Receiver Gloves; Infamy with Shoulder Pads; explosive items with the Kicking Tee; magnets with the Pigskin; Holy Water, lemons, Ball of Tar and Juicy Sack with the Gatorade Bucket; BFFS! with the familiars. Team Jersey and the Quarterback now throw footballs with Brimstone, Technology, Mom's Knife and other weapons that don't fire tears. EID lists each item's synergies.
- **Helmet:** sleeker, modern shell. Longer and lower crown, a visor shelf over the face, a forward-swept jaw guard, a flared back, and a squared brow. The facemask is unchanged.
- **Art pass:** every item, trinket and card icon gets the vanilla treatment: one heavy outline, slightly muted colours and rounded rim lighting. Eye Black is redrawn as an open tin of grease.
- `gridiron give` now drops real pedestals, so the items count for your collection and show in the pause screen's *My Stuff* list. `gridiron give quick` keeps the old instant behaviour.

## 0.4.3
- Fix: the Quarterback character-select pages no longer draw a big figure in the middle of the page, where it piled up under the character wheel.

## 0.4.2
- Fix: running with a live tackle (fast when Suited Up) spawned screen-filling smoke clouds that flashed on every move. The trail is now a small, faint turf puff.

## 0.4.1
- Cleaner helmet side view: smooth shell, simple ear hole, and a thin cage facemask that protrudes past the face (no more stacked bars across the brow).

## 0.4.0
- **The Quarterback** and **Tainted Quarterback** playable characters, with full menu art.
- **The Linebacker** boss (charge, spiked footballs, enraged pile-up) plus **Mascot** and **Referee** enemies.
- Familiars: **Cheerleader**, **Water Boy**, **Tackling Dummy**.
- Items: **Chin Strap**, **Foam Finger**, **Super Bowl Ring**; trinket **Concussion Protocol**; **Coin Toss** card; **Timeout!** pill.
- Challenges: **Fourth and Long**, **Two-Minute Drill**, **Ground Game**.
- Menu: Linebacker and football-enemy spawn chances; `gridiron boss` / `gridiron enemies` commands.
- Workshop thumbnail and description.

## 0.3.0
- Open-face facemask modeled on a modern helmet, raised to sit across the face.
- Padded Pants is now a passive item (stiff-arm on shrugged-off hits).
- Floating callouts for every effect, landing markers for kicks and fumbles, clearer effects and sounds.

## 0.2.1
- Modern helmet redesign; jersey now drapes over the shoulder pads.

## 0.2.0
- Dead Sea Scrolls settings menu, save & continue support, Suited Up glow, HUD readouts.
- Playbook, Coach's Whistle, Gatorade Bucket, Referee Flag.
- Costumes can be hidden per character; `gridiron` console commands.

## 0.1.0
- First release: Football Helmet, Shoulder Pads, Team Jersey, Football Cleats, Eye Black, Receiver Gloves,
  Mouthguard, Kicking Tee, Pigskin, Padded Pants; worn costumes; football tears.
