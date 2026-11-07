-- External Item Descriptions. Rebuilt whenever settings change so numbers stay true.
return function(mod)
    local Items, Trinkets = mod.Items, mod.Trinkets

    local function pct(x) return math.floor(x * 100 + 0.5) .. "%" end

    function mod.RegisterEID()
        if not EID then return end
        local Cfg = mod.Cfg
        -- every description gets its base-game synergies appended (scripts/synergies.lua)
        local function addCollectible(id, text)
            local note = mod.SynergyNotes and mod.SynergyNotes[id]
            EID:addCollectible(id, note and (text .. "#" .. note) or text)
        end
        local secs = string.format("%.2g", Cfg.TACKLE_WINDUP / 30)
        addCollectible(Items.HELMET,
            "Run in a straight line for " .. secs .. "s to start a tackle (Isaac glows)#" ..
            "Tackling an enemy deals 3x damage +5, knocks it back, confuses and stuns it#" ..
            "No contact damage while tackling#" ..
            "Facemask: " .. pct(Cfg.FACEMASK_BLOCK_CHANCE) .. " chance to block shots that hit you from the direction you're facing")
        addCollectible(Items.PADS,
            pct(Cfg.PADS_DEFLECT_CHANCE) .. " chance to deflect enemy shots back at enemies#" ..
            "Taking damage releases a shockwave that shoves enemies and destroys nearby shots#" ..
            "Tackles (Football Helmet) also cause a smaller shockwave")
        addCollectible(Items.JERSEY,
            "You get a jersey number for the run#" ..
            "Every 3-9 shots (based on your number) you throw a football: 2x damage, piercing, spectral#" ..
            "Enemies freeze for a moment when you enter a room (pre-snap)")
        addCollectible(Items.CLEATS,
            "↑ +0.2 Speed#" ..
            "Running " .. Cfg.FIRST_DOWN_YARDS .. " yards in an uncleared room earns a First Down: +0.5 Damage for the room (up to 4)")
        addCollectible(Items.EYE_BLACK,
            "↑ +1 Luck#" ..
            "Tears deal up to +50% damage the farther they travel#" ..
            "Immune to Curse of Darkness")
        addCollectible(Items.GLOVES,
            "While not shooting, " .. pct(Cfg.GLOVES_CATCH_CHANCE) .. " chance to catch enemy shots instead of getting hit (hold up to 3)#" ..
            "Each shot you fire throws one caught ball back as a football: 1.5x damage, piercing, spectral")
        addCollectible(Items.MOUTHGUARD,
            "The first hit each room that deals a full heart or more deals half a heart less#" ..
            "Immune to fear and confusion")
        addCollectible(Items.KICKING_TEE,
            "Punt a football in the direction you're aiming; it sails over obstacles#" ..
            "Explodes on landing for " .. Cfg.KICK_DAMAGE .. " + 4x your damage (doesn't hurt you)#" ..
            "If the blast kills an enemy: Field goal! Spawns 3 pennies")
        addCollectible(Items.PIGSKIN,
            "Throw a fumble that sits on the ground for 5 seconds#" ..
            "Non-boss enemies scramble toward it and get confused#" ..
            "Recover it for a Touchdown: +1 Damage for the room")
        addCollectible(Items.PLAYBOOK,
            "Calls a play for the current room, cycling through the book:#" ..
            "Blitz: ↑ tears and +0.3 speed#" ..
            "Hail Mary: ↑ range and shot speed, piercing tears#" ..
            "Trick Play: your next 6 shots are footballs")
        addCollectible(Items.WHISTLE,
            "Offsides! Shoves every enemy away from you and slows them for 5 seconds#" ..
            "Destroys all enemy shots#" ..
            "Bosses take damage instead of being shoved")
        addCollectible(Items.GATORADE,
            "Clearing a room without getting hit fills the bucket#" ..
            "Every " .. Cfg.GATORADE_FILLS .. " fills (or one no-hit boss): heals a full red heart, or half a soul heart if you're full")
        addCollectible(Items.PANTS,
            pct(Cfg.PANTS_IGNORE_CHANCE) .. " chance to ignore damage from touching an enemy, and stiff-arm it away#" ..
            "Extra copies stack (up to " .. pct(Cfg.PANTS_MAX_CHANCE) .. ")#Counts toward Suited Up")
        addCollectible(Items.WRISTBAND,
            "↑ +0.16 Shot speed#" ..
            "Every football you throw homes in and deals +25% damage#Counts toward Suited Up")
        addCollectible(Items.CHAMP_RING,
            "↑ x" .. Cfg.CHAMP_RING_DMG_MULT .. " Damage multiplier#" ..
            "Beating each floor's boss spawns a trophy: an extra boss item")
        addCollectible(Items.HOF_JACKET,
            "Counts as " .. Cfg.HOF_JACKET_PIECES .. " gear pieces: instantly Suited Up#" ..
            "Suited Up gives double damage (+" .. Cfg.SUITED_UP_DAMAGE * 2 .. ")#Tackles go live 4x faster")
        addCollectible(Items.GOLDEN_ARM,
            "Every shot is a golden football: x" .. Cfg.GOLDEN_ARM_DMG_MULT .. " damage, piercing, spectral#" ..
            "↑ +" .. Cfg.GOLDEN_ARM_SHOT_SPEED .. " Shot speed")
        addCollectible(Items.HAIL_MARY,
            "Throws a giant golden football across the room: 8x damage +30, piercing#" ..
            "Where it lands: a beam of holy light and a ring of " .. Cfg.HAIL_MARY_BURST .. " footballs")
        addCollectible(Items.END_ZONE,
            "Paints an end zone under you for the rest of the room#" ..
            "Standing in it: +" .. Cfg.END_ZONE_DAMAGE .. " Damage#Enemies inside it are slowed")
        addCollectible(Items.FOAM_FINGER,
            "The toughest enemy in each room is marked #1#" ..
            "You deal +50% damage to it#It drops a penny when it dies")
        addCollectible(Items.RING,
            "↑ +1 Luck#Every boss room you clear adds a ring: +0.35 Damage for the rest of the run")
        addCollectible(Items.CHEERLEADER,
            "Follows you and cheers on every kill#Every 6 kills: a routine gives +33% fire rate for 5 seconds")
        addCollectible(Items.WATER_BOY,
            "Follows you; 33% chance to drop half a red heart after a cleared room (always after a boss)#" ..
            "With Gatorade Bucket: clean rooms fill it twice as fast")
        addCollectible(Items.DUMMY,
            "Orbits you and blocks enemy shots#Pulls nearby enemies toward itself")
        EID:addTrinket(Trinkets.TURF_BURN,
            "Sprinting scorches the turf behind you: the burn damages enemies#Tackled enemies get a big scorch mark")
        EID:addTrinket(Trinkets.PROTOCOL,
            "Taking damage confuses every enemy in the room for 2 seconds")
        if mod.Cards.COIN_TOSS and mod.Cards.COIN_TOSS > 0 then
            EID:addCard(mod.Cards.COIN_TOSS,
                "Flip a coin:#Heads: +1.5 Damage for the room#Tails: fully recharges your active item and slows all enemies")
        end
        if mod.Pills.TIMEOUT and mod.Pills.TIMEOUT >= 0 then
            EID:addPill(mod.Pills.TIMEOUT, "Freezes all enemies for 3 seconds, clears enemy shots and heals half a heart")
        end
        EID:addTrinket(Trinkets.FLAG,
            "When an enemy or its shot hits you, it gets flagged:#" ..
            "takes 10 + 3x floor number damage and is slowed")
    end

    mod.RegisterEID()
end
