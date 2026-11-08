-- Shared state for every Gridiron script: item ids, tuning, settings, helpers.
return function(mod)
    local game = Game()
    local sfx = SFXManager()
    mod.game, mod.sfx = game, sfx

    mod.Items = {
        HELMET      = Isaac.GetItemIdByName("Football Helmet"),
        PADS        = Isaac.GetItemIdByName("Shoulder Pads"),
        JERSEY      = Isaac.GetItemIdByName("Team Jersey"),
        CLEATS      = Isaac.GetItemIdByName("Football Cleats"),
        EYE_BLACK   = Isaac.GetItemIdByName("Eye Black"),
        GLOVES      = Isaac.GetItemIdByName("Receiver Gloves"),
        MOUTHGUARD  = Isaac.GetItemIdByName("Mouthguard"),
        KICKING_TEE = Isaac.GetItemIdByName("Kicking Tee"),
        PIGSKIN     = Isaac.GetItemIdByName("Pigskin"),
        PLAYBOOK    = Isaac.GetItemIdByName("Playbook"),
        WHISTLE     = Isaac.GetItemIdByName("Coach's Whistle"),
        GATORADE    = Isaac.GetItemIdByName("Gatorade Bucket"),
        PANTS       = Isaac.GetItemIdByName("Padded Pants"),
        WRISTBAND   = Isaac.GetItemIdByName("QB Wristband"),
        END_ZONE    = Isaac.GetItemIdByName("End Zone"),
        CHAMP_RING  = Isaac.GetItemIdByName("Championship Ring"),
        HOF_JACKET  = Isaac.GetItemIdByName("Hall of Fame Jacket"),
        GOLDEN_ARM  = Isaac.GetItemIdByName("Golden Arm"),
        HAIL_MARY   = Isaac.GetItemIdByName("Hail Mary"),
        FOAM_FINGER = Isaac.GetItemIdByName("Foam Finger"),
        RING        = Isaac.GetItemIdByName("Super Bowl Ring"),
        CHEERLEADER = Isaac.GetItemIdByName("Cheerleader"),
        WATER_BOY   = Isaac.GetItemIdByName("Water Boy"),
        DUMMY       = Isaac.GetItemIdByName("Tackling Dummy"),
    }
    mod.Trinkets = {
        FLAG  = Isaac.GetTrinketIdByName("Referee Flag"),
        PROTOCOL = Isaac.GetTrinketIdByName("Concussion Protocol"),
        TURF_BURN = Isaac.GetTrinketIdByName("Turf Burn"),
        LUCKY_PATCH = Isaac.GetTrinketIdByName("Lucky Patch"),
        BUCKLE = Isaac.GetTrinketIdByName("Chin Strap Buckle"),
        PYLON = Isaac.GetTrinketIdByName("Pylon"),
        GAME_COIN = Isaac.GetTrinketIdByName("Game Coin"),
        MOUTH_TAPE = Isaac.GetTrinketIdByName("Mouth Tape"),
        HAND_WARMER = Isaac.GetTrinketIdByName("Hand Warmer"),
    }
    mod.Cards = {
        COIN_TOSS = Isaac.GetCardIdByName("Coin Toss"),
        AUDIBLE = Isaac.GetCardIdByName("Audible"),
        FAIR_CATCH = Isaac.GetCardIdByName("Fair Catch"),
    }
    mod.Pills = {
        TIMEOUT = Isaac.GetPillEffectByName("Timeout!"),
        TWO_POINT = Isaac.GetPillEffectByName("Two-Point Conversion"),
    }
    mod.Sounds = {
        WHISTLE = Isaac.GetSoundIdByName("Gridiron Whistle"),
        CHEER   = Isaac.GetSoundIdByName("Gridiron Cheer"),
        BOO     = Isaac.GetSoundIdByName("Gridiron Boo"),
        CLACK   = Isaac.GetSoundIdByName("Gridiron Clack"),
        HORN    = Isaac.GetSoundIdByName("Gridiron Horn"),
        FANFARE = Isaac.GetSoundIdByName("Gridiron Fanfare"),
    }

    -- Tuning -----------------------------------------------------------------
    -- Values marked (menu) can be changed in-game from the Dead Sea Scrolls menu.
    mod.Cfg = {
        -- Football Helmet
        TACKLE_MIN_SPEED      = 2.5,   -- velocity needed to count as "running"
        TACKLE_STRAIGHTNESS   = 0.94,  -- dot product between frames to count as a straight line
        TACKLE_WINDUP         = 30,    -- (menu) frames of straight running before a tackle is live
        TACKLE_REACH          = 28,    -- extra radius beyond the player's size
        TACKLE_DMG_MULT       = 3.0,
        TACKLE_DMG_FLAT       = 5.0,
        TACKLE_KNOCKBACK      = 14,
        TACKLE_CONFUSE        = 60,
        TACKLE_HIT_COOLDOWN   = 20,    -- frames before the same enemy can be tackled again
        TACKLE_STUN           = 30,    -- the buckled chin strap: tackled enemies are stunned (bosses: 10)
        FACEMASK_BLOCK_CHANCE = 0.4,   -- (menu)
        FACEMASK_ARC          = 0.6,   -- dot product threshold for "in front of the face"

        -- Shoulder Pads
        PADS_DEFLECT_CHANCE   = 0.25,  -- (menu)
        PADS_POP_RADIUS       = 120,
        PADS_POP_KNOCKBACK    = 12,

        -- Team Jersey
        JERSEY_SNAP_FREEZE    = 30,    -- "set" freeze on room entry
        JERSEY_BALL_DMG_MULT  = 2.0,
        JERSEY_BALL_SCALE     = 1.6,

        -- Football Cleats
        CLEATS_SPEED          = 0.2,
        YARD_UNITS            = 40,    -- world units per "yard"
        FIRST_DOWN_YARDS      = 10,    -- (menu)
        MAX_FIRST_DOWNS       = 4,
        FIRST_DOWN_DAMAGE     = 0.5,

        -- Eye Black
        EYE_BLACK_LUCK        = 1,
        EYE_BLACK_RANGE_FULL  = 500,   -- tear travel distance for the full bonus
        EYE_BLACK_MAX_BONUS   = 0.5,

        -- Receiver Gloves
        GLOVES_CATCH_CHANCE   = 0.35,  -- (menu)
        GLOVES_MAX_HELD       = 3,
        GLOVES_THROW_DMG      = 1.5,

        -- Mouthguard
        MOUTHGUARD_MIN_HIT    = 2,     -- hits of at least a full heart get reduced
        MOUTHGUARD_REDUCTION  = 1,     -- by half a heart

        -- Kicking Tee
        KICK_RANGE            = 300,
        KICK_FLIGHT           = 26,    -- frames in the air
        KICK_PEAK             = 70,    -- screen pixels at the top of the arc
        KICK_DAMAGE           = 40,    -- (menu)
        KICK_DAMAGE_MULT      = 4,     -- + player damage x this
        KICK_RADIUS           = 85,
        KICK_RADIUS_MULT      = 1.2,
        FIELD_GOAL_COINS      = 3,

        -- Pigskin
        FUMBLE_RANGE          = 180,
        FUMBLE_FLIGHT         = 16,
        FUMBLE_PEAK           = 40,
        FUMBLE_TIME           = 150,   -- frames the ball stays on the ground
        FUMBLE_PULL_RADIUS    = 260,
        FUMBLE_PULL           = 0.9,
        FUMBLE_PICKUP_GRACE   = 15,
        TOUCHDOWN_DAMAGE      = 1.0,

        -- Playbook
        BLITZ_FIRE_DELAY_MULT = 0.75,
        BLITZ_SPEED           = 0.3,
        HAIL_MARY_RANGE       = 100,   -- world units (2.5 range)
        HAIL_MARY_SHOT_SPEED  = 0.4,
        TRICK_PLAY_SHOTS      = 6,

        -- Coach's Whistle
        WHISTLE_KNOCKBACK     = 22,
        WHISTLE_SLOW_FRAMES   = 150,
        WHISTLE_SLOW_VALUE    = 0.5,
        WHISTLE_BOSS_DAMAGE   = 30,
        WHISTLE_BOSS_DMG_MULT = 3,

        -- Gatorade Bucket
        GATORADE_FILLS        = 3,     -- clean rooms needed for a shower

        -- Referee Flag
        FLAG_DAMAGE           = 10,
        FLAG_DAMAGE_PER_STAGE = 3,
        FLAG_SLOW_FRAMES      = 90,

        -- Padded Pants
        PANTS_IGNORE_CHANCE   = 0.3,   -- (menu) per copy
        PANTS_MAX_CHANCE      = 0.6,
        PANTS_STIFF_ARM       = 16,    -- knockback on the enemy you shrugged off

        -- QB Wristband
        WRISTBAND_SHOT_SPEED  = 0.16,
        WRISTBAND_BALL_DMG    = 1.25,  -- every football you throw
        WRISTBAND_HOMING_DMG  = 1.25,  -- on top, with a homing item

        -- End Zone
        END_ZONE_HALF_W       = 62,    -- world units from the centre to the sideline
        END_ZONE_HALF_H       = 30,
        END_ZONE_DAMAGE       = 1.5,   -- while you stand in it
        END_ZONE_SLOW         = 0.6,   -- enemies inside it

        -- Turf Burn
        TURF_BURN_SPEED       = 3.2,   -- velocity that counts as a sprint
        TURF_BURN_DMG_MULT    = 0.2,   -- creep damage per tick, x player damage
        TURF_BURN_FRAMES      = 45,    -- how long a scorch mark lasts

        -- Foam Finger
        FINGER_BONUS          = 0.5,

        -- Super Bowl Ring
        RING_DAMAGE           = 0.35,
        RING_LUCK             = 1,

        -- Trinket batch two (scripts/trinkets.lua)
        PATCH_LUCK            = 1,
        PATCH_SUITED_LUCK     = 2,
        BUCKLE_WINDUP         = 0.75,
        PYLON_DAMAGE          = 1,
        COIN_TRINKET_DAMAGE   = 0.5,
        COIN_TRINKET_SPEED    = 0.2,
        TAPE_FIRE_DELAY_MULT  = 0.92,
        WARMER_FRAMES         = 45,
        WARMER_DAMAGE         = 2,

        -- Concussion Protocol
        PROTOCOL_DAZE         = 60,

        -- Coin Toss
        COIN_HEADS_DAMAGE     = 1.5,
        COIN_TAILS_SLOW       = 150,

        -- Audible / Fair Catch
        AUDIBLE_CONFUSE       = 60,
        FAIR_CATCH_FRAMES     = 60,

        -- Timeout!
        TIMEOUT_FREEZE        = 90,

        -- Familiars
        CHEER_HYPE            = 6,     -- kills per routine
        CHEER_FRAMES          = 150,
        CHEER_FIRE_DELAY_MULT = 0.75,
        WATER_BOY_CHANCE      = 0.33,
        DUMMY_TAUNT_RADIUS    = 140,
        DUMMY_TAUNT_PULL      = 0.35,

        -- Boss / enemies
        LINEBACKER_CHANCE     = 0.25,  -- (menu) chance to replace an early boss
        FRANCHISE_CHANCE      = 0.2,   -- (menu) chance to replace a floor 7-8 boss
        FRANCHISE_MAX_LINEMEN = 4,     -- audibles stop calling Linemen past this
        FRANCHISE_CAM_DAMAGE  = 40,    -- Kiss Cam blast
        FOOTBALL_ENEMY_CHANCE = 0.1,   -- (menu) chance a matching vanilla enemy is a football enemy
        COACH_CHANCE_MULT     = 0.5,   -- the Coach (replacing a Fatty) is rarer
        COACH_PLAY_FRAMES     = 150,   -- how long a called play lasts
        COACH_BLITZ_SPEED     = 1.12,
        CAPTAIN_CHANCE        = 0.15,  -- a football enemy is a gold Team Captain
        CAPTAIN_HP_MULT       = 1.5,

        -- The Quarterback
        QB_EVERY_NTH          = 3,     -- every Nth shot is a football (2 with Birthright)
        QB_ARM_SPEED          = 1.25,  -- his footballs fly faster...
        QB_ARM_DAMAGE         = 1.25,  -- ...and hit harder
        QB_SHOT_SPEED         = 0.2,
        TQB_FIRE_DELAY_MULT   = 1.0,   -- Tainted: One Ball (the wait is getting it back)
        TQB_BALL_DMG_MULT     = 3.0,
        TQB_DAMAGE            = 0.5,

        -- Q4 items (scripts/legends.lua)
        CHAMP_RING_DMG_MULT   = 1.25,
        HOF_JACKET_PIECES     = 3,     -- the jacket counts as this many gear pieces
        GOLDEN_ARM_DMG_MULT   = 1.5,
        GOLDEN_ARM_SHOT_SPEED = 0.3,
        HAIL_MARY_SPEED       = 15,
        HAIL_MARY_DMG_MULT    = 8,     -- x player damage, plus a flat 30
        HAIL_MARY_BURST       = 10,

        -- Field decor
        DECOR_CHANCE_LIGHT    = 0.05,  -- share of normal rooms with football props
        DECOR_CHANCE_FULL     = 0.12,

        -- Pro Shop
        PROSHOP_CHANCE        = 0.25,  -- (menu) share of shops that are team stores

        -- Halftime show
        HALFTIME_CHANCE       = 0.06,  -- (menu) per cleared normal room, once per floor

        -- All-Pro transformation: any 3 Gridiron items
        ALLPRO_ITEMS          = 3,
        ALLPRO_EVERY          = 4,     -- every Nth shot is a golden spiral
        ALLPRO_DAMAGE         = 0.5,

        -- The Kicker
        KICKER_SPEED          = 0.15,
        KICKER_RANGE          = 60,
        KICKER_DAMAGE_MULT    = 0.9,
        KICKER_REFUND         = 2,     -- Tee charges back on a field goal
        KICKER_FG_DAMAGE      = 0.3,   -- per field goal this floor
        KICKER_FG_MAX         = 5,
        KICKER_BR_RADIUS      = 1.5,
        TKICK_FIRE_DELAY_MULT = 1.4,
        TKICK_DAMAGE          = 1.0,
        TKICK_EVERY           = 4,     -- every Nth shank explodes (2 with Birthright)
        TKICK_BLAST_MULT      = 2.5,   -- x player damage

        -- The Coach
        COACH_DAMAGE_MULT     = 0.75,
        COACH_FAMILIAR_BOOST  = 1.25,  -- on top of BFFS!
        TCOACH_SQUAD          = 2,     -- friendly Linemen at once (Birthright: 4)
        TCOACH_SQUAD_BR       = 4,
        TCOACH_ROOM_SUBS      = 2,
        TCOACH_WHISTLE_SUBS   = 2,

        -- Set bonus
        SUITED_UP_PIECES      = 3,
        SUITED_UP_DAMAGE      = 1.0,

        -- Base-game synergies (scripts/synergies.lua)
        MARS_DASH_SPEED       = 9,     -- velocity that counts as a Mars dash
        BIG_TACKLE_DAMAGE     = 1.25,  -- Leo / Thunder Thighs / Magic Mushroom / Bucket of Lard
        BIG_TACKLE_KNOCKBACK  = 1.5,
        MAGNET_CATCH_BONUS    = 0.2,   -- Magneto / Telekinesis + Receiver Gloves
        INFAMY_DEFLECT_BONUS  = 0.15,  -- Infamy + Shoulder Pads
        BOOM_KICK_RADIUS      = 1.5,   -- explosive items + Kicking Tee
        BFFS_FAMILIAR_BOOST   = 1.5,
        BIG_PANTS_BONUS       = 0.15,  -- Thunder Thighs / Leo + Padded Pants
        LUCKY_FOOT_LUCK       = 0.5,   -- Lucky Foot + Cleats, per first down
        JUICED_DAMAGE         = 1.5,   -- steroids + tackles
        JUICED_KNOCKBACK      = 2,
        PINBALL_FRAMES        = 14,    -- a juiced tackle sends the enemy flying this long
        PINBALL_DAMAGE        = 0.5,   -- x the tackle's damage to whatever it hits
        KNOCKOUT_STUN_MULT    = 3,     -- Knockout Drops + tackles
        BRACELET_RANGE        = 1.5,   -- Mom's Bracelet + kicks and fumbles
        ADRENALINE_DAMAGE     = 1,     -- Adrenaline + a Gatorade shower, for the room
        ADRENALINE_SPEED      = 0.2,
        SHOWER_CREEP_SCALE    = 2.5,   -- Gatorade shower creep
        SHOWER_CREEP_FRAMES   = 240,
    }
    mod.Config = mod.Cfg -- older name

    mod.Defaults = {}
    for k, v in pairs(mod.Cfg) do mod.Defaults[k] = v end

    -- Display/cosmetic toggles, also persisted by the menu.
    mod.Settings = {
        costumes = true,       -- show worn gear on the character
        suitedGlow = true,     -- gold pulse while Suited Up
        hud = true,            -- small text readouts under the player
        popups = true,         -- floating callouts ("TACKLE!", "IT'S GOOD!")
        crowd = true,          -- crowd cheers/boos, horn and fanfare
        decor = "full",        -- football props in rooms: "off", "light" or "full"
        drugTests = true,      -- referees and the coach go after juiced players
        bossMusic = true,      -- the Linebacker and The Franchise get their own themes
        gridironItems = true,  -- Gridiron items and trinkets can show up in runs
        q4Items = true,        -- ...including the Q4 legends
        helmetColor = "auto",  -- uniform colours (menu: uniform); "auto" = the character's own colours
        jerseyColor = "auto",
        pantsColor = "auto",
    }
    mod.SettingDefaults = {}
    for k, v in pairs(mod.Settings) do mod.SettingDefaults[k] = v end

    -- Must match the lists in tools/make_costumes.py (first entry = default, un-suffixed files).
    mod.UNIFORM_COLORS = {
        helmet = { "red", "blue", "navy", "green", "orange", "purple", "gold", "black", "silver", "white", "pink" },
        jersey = { "blue", "red", "navy", "green", "orange", "purple", "gold", "black", "silver", "white", "pink" },
        pants  = { "white", "silver", "gold", "black", "navy", "red", "blue", "green", "orange", "purple", "pink" },
    }

    mod.FOOTBALL_ANM2 = "gfx/gridiron_football_tear.anm2"

    -- Run-wide state that isn't tied to one player (saved with the run).
    mod.RunState = {}

    -- Defaults for hooks that later scripts (challenges.lua) override.
    function mod.tackleWindupMult() return 1 end
    function mod.tackleDamageMult() return 1 end
    function mod.currentChallenge() return nil end
    function mod.quarterbackKind() return nil end
    -- base-game synergy hooks (scripts/synergies.lua)
    function mod.tackleSynergy() return 1, 1, 1 end
    function mod.catchBonus() return 0 end
    function mod.deflectBonus() return 0 end
    function mod.kickRadiusMult() return 1 end
    function mod.fumblePullMult() return 1 end
    function mod.familiarBoost() return 1 end
    function mod.onGatoradeShower() end
    function mod.yardMult() return 1 end
    function mod.ringMult() return 1 end
    function mod.fingerMult() return 1 end
    function mod.pantsBonus() return 0 end
    function mod.wristbandMult() return 1 end
    function mod.turfBurnFrames() return 1 end
    function mod.inEndZone() return false end
    function mod.enemyDamageTakenMult() return 1 end
    -- Events other mods can listen to through the Gridiron API (scripts/api.lua).
    mod.Listeners = {}
    function mod.fire(event, ...)
        for _, fn in ipairs(mod.Listeners[event] or {}) do
            local ok, err = pcall(fn, ...)
            if not ok then Isaac.DebugString("Gridiron: a " .. event .. " listener failed: " .. tostring(err)) end
        end
    end

    function mod.kickAlwaysGood() return false end
    function mod.buckleWindup() return 1 end
    function mod.bossPushMult() return 0.25 end
    function mod.isJuiced() return false end
    function mod.coachFamiliarBoost() return 1 end
    function mod.eyeBlackMult() return 1 end
    function mod.tackleStunMult() return 1 end
    function mod.throwRangeMult() return 1 end
    function mod.waterBoyBoost() return 1, HeartSubType.HEART_HALF end
    function mod.dummyPullMult() return 1 end
    function mod.fingerDrop() return CoinSubType.COIN_PENNY end
    function mod.drugTestOn() return false end
    function mod.kickerRadiusMult() return 1 end
    function mod.onFieldGoal() end

    -- Wearable gear counts toward Suited Up; actives and the bucket don't.
    mod.GEAR = {
        mod.Items.HELMET, mod.Items.PADS, mod.Items.JERSEY, mod.Items.CLEATS,
        mod.Items.EYE_BLACK, mod.Items.GLOVES, mod.Items.MOUTHGUARD, mod.Items.PANTS,
        mod.Items.WRISTBAND,
    }

    mod.ACTIVE_ITEMS = {
        [mod.Items.KICKING_TEE] = true, [mod.Items.PIGSKIN] = true,
        [mod.Items.PLAYBOOK] = true, [mod.Items.WHISTLE] = true, [mod.Items.END_ZONE] = true,
        [mod.Items.HAIL_MARY] = true,
    }

    mod.DIR_VECTORS = {
        [Direction.LEFT]  = Vector(-1, 0),
        [Direction.UP]    = Vector(0, -1),
        [Direction.RIGHT] = Vector(1, 0),
        [Direction.DOWN]  = Vector(0, 1),
    }

    -- Helpers --------------------------------------------------------------------
    function mod.pdata(player)
        local d = player:GetData()
        d.Gridiron = d.Gridiron or {
            runFrames = 0, yardDist = 0, firstDowns = 0, shots = 0, caught = 0,
            playIndex = 0, trickShots = 0, bucket = 0, rings = 0,
        }
        return d.Gridiron
    end

    function mod.forEachPlayer(fn)
        for i = 0, game:GetNumPlayers() - 1 do
            fn(Isaac.GetPlayer(i), i)
        end
    end

    function mod.anyPlayerHas(item)
        local found = false
        mod.forEachPlayer(function(p) if p:HasCollectible(item) then found = true end end)
        return found
    end

    function mod.gearCount(player)
        local n = 0
        for _, item in ipairs(mod.GEAR) do
            if item > 0 and player:HasCollectible(item) then n = n + 1 end
        end
        if mod.Items.HOF_JACKET > 0 and player:HasCollectible(mod.Items.HOF_JACKET) then
            n = n + mod.Cfg.HOF_JACKET_PIECES   -- the Hall of Fame Jacket: suited up on its own
        end
        return n
    end

    -- How many different Gridiron collectibles the player holds (for All-Pro).
    function mod.gridironItemCount(player)
        local n = 0
        for _, id in pairs(mod.Items) do
            if id > 0 and player:HasCollectible(id) then n = n + 1 end
        end
        return n
    end

    function mod.isSuitedUp(player)
        return mod.gearCount(player) >= mod.Cfg.SUITED_UP_PIECES
    end

    function mod.rngFor(player, item)
        return player:GetCollectibleRNG(item)
    end

    function mod.isReflectionPass()
        return RenderMode ~= nil and game:GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT
    end

    function mod.refreshCache(player, flags)
        player:AddCacheFlags(flags or CacheFlag.CACHE_DAMAGE)
        player:EvaluateItems()
    end

    -- Where the player "wants" to throw: shooting direction, then movement, then facing.
    function mod.aimDirection(player)
        local aim = player:GetAimDirection()
        if aim:Length() > 0.1 then return aim:Normalized() end
        if player.Velocity:Length() > 1 then return player.Velocity:Normalized() end
        return mod.DIR_VECTORS[player:GetHeadDirection()] or Vector(0, 1)
    end

    function mod.newFootballSprite()
        local s = Sprite()
        s:Load(mod.FOOTBALL_ANM2, true)
        s:Play("Spiral", true)
        return s
    end

    -- Jersey number is fixed for the whole run (derived from the run seed).
    function mod.jerseyNumber(player)
        local seed = game:GetSeeds():GetStartSeed()
        return (seed + player.ControllerIndex * 17) % 99 + 1
    end

    -- Every Nth shot becomes a thrown football; N comes from the jersey number.
    function mod.footballInterval(number)
        return number % 7 + 3 -- 3..9
    end

    function mod.isContactDamage(source)
        if not source or not source.Entity then return false end
        if source.Type == EntityType.ENTITY_PROJECTILE then return false end
        local ent = source.Entity
        return ent:IsEnemy() and ent.Type < EntityType.ENTITY_EFFECT
    end

    -- Turn a tear into a thrown football (piercing, spectral, drawn as a spiral).
    -- Footballs pick up the look of your tear effects, so synergies read at a glance.
    -- First match wins; tint = sprite colour, offset = glow.
    mod.FOOTBALL_TINTS = {
        { "TEAR_BURN",             Color(1, 0.75, 0.45, 1, 0.45, 0.15, 0) },     -- fire: glowing orange
        { "TEAR_POISON",           Color(0.6, 1, 0.5, 1, 0.05, 0.25, 0) },       -- poison / Ipecac: green
        { "TEAR_EXPLOSIVE",        Color(0.7, 1, 0.45, 1, 0.15, 0.3, 0) },
        { "TEAR_GLOW",             Color(1, 1, 1, 1, 0.45, 0.4, 0.25) },         -- Godhead: shining
        { "TEAR_LIGHT_FROM_HEAVEN", Color(1, 0.95, 0.7, 1, 0.35, 0.3, 0.05) },   -- holy: gold
        { "TEAR_FREEZE",           Color(0.75, 0.9, 1, 1, 0.1, 0.25, 0.45) },    -- ice: frosted blue
        { "TEAR_ICE",              Color(0.75, 0.9, 1, 1, 0.1, 0.25, 0.45) },
        { "TEAR_CHARM",            Color(1, 0.7, 0.85, 1, 0.35, 0.05, 0.2) },    -- charm: pink
        { "TEAR_FEAR",             Color(0.45, 0.4, 0.45, 1, 0, 0, 0) },         -- Dark Matter: black
        { "TEAR_MIDAS",            Color(1, 0.9, 0.4, 1, 0.45, 0.35, 0) },       -- Midas: solid gold
        { "TEAR_HOMING",           Color(0.95, 0.75, 1, 1, 0.2, 0.05, 0.3) },    -- homing: purple
    }

    function mod.footballTint(tear)
        if not tear.HasTearFlags then return nil end
        for _, entry in ipairs(mod.FOOTBALL_TINTS) do
            local flag = TearFlags[entry[1]]
            if flag and tear:HasTearFlags(flag) then return entry[2] end
        end
    end

    function mod.makeFootball(tear, dmgMult)
        local thrower = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
        local golden = thrower and thrower:HasCollectible(mod.Items.GOLDEN_ARM)
        if golden then dmgMult = dmgMult * mod.Cfg.GOLDEN_ARM_DMG_MULT end
        if thrower and thrower:HasCollectible(mod.Items.WRISTBAND) then
            -- QB Wristband: read the defense, every football finds a target
            dmgMult = dmgMult * mod.Cfg.WRISTBAND_BALL_DMG * mod.wristbandMult(thrower)
            tear:AddTearFlags(TearFlags.TEAR_HOMING)
        end
        tear.CollisionDamage = tear.CollisionDamage * dmgMult
        tear.Scale = tear.Scale * mod.Cfg.JERSEY_BALL_SCALE
        tear:AddTearFlags(TearFlags.TEAR_PIERCING | TearFlags.TEAR_SPECTRAL)
        tear.Color = Color(0.55, 0.3, 0.15, 1, 0.1, 0.05, 0) -- tints the splash on impact
        local ball = mod.newFootballSprite()
        ball.Color = mod.footballTint(tear)
            or (golden and Color(1, 0.9, 0.45, 1, 0.45, 0.35, 0))   -- Golden Arm: solid gold balls
            or Color(1, 1, 1, 1)
        tear:GetData().GridironFootball = ball
        tear:GetSprite().Color = Color(1, 1, 1, 0)
        sfx:Play(SoundEffect.SOUND_SHELLGAME, 0.6, 0, false, 1.3)
    end

    -- Stadium sounds (crowd, horn, fanfare) can be turned off in the menu; the clack and
    -- whistle are gameplay feedback and always play.
    local STADIUM = { CHEER = true, BOO = true, HORN = true, FANFARE = true }
    function mod.playSound(key, volume)
        local id = mod.Sounds[key]
        if not id or id <= 0 or (STADIUM[key] and not mod.Settings.crowd) then return end
        sfx:Play(id, volume or 1)
    end

    function mod.playWhistle(volume)
        if mod.Sounds.WHISTLE and mod.Sounds.WHISTLE > 0 then
            sfx:Play(mod.Sounds.WHISTLE, volume or 1)
        end
    end
end
