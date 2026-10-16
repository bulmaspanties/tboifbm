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
    }
    mod.Trinkets = {
        PANTS = Isaac.GetTrinketIdByName("Padded Pants"),
        FLAG  = Isaac.GetTrinketIdByName("Referee Flag"),
    }
    mod.Sounds = {
        WHISTLE = Isaac.GetSoundIdByName("Gridiron Whistle"),
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
        FACEMASK_BLOCK_CHANCE = 0.5,   -- (menu)
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
        PANTS_IGNORE_CHANCE   = 0.25,  -- per trinket multiplier (golden / Mom's Box stack)
        PANTS_MAX_CHANCE      = 0.6,

        -- Set bonus
        SUITED_UP_PIECES      = 3,
        SUITED_UP_DAMAGE      = 1.0,
    }
    mod.Config = mod.Cfg -- older name

    mod.Defaults = {}
    for k, v in pairs(mod.Cfg) do mod.Defaults[k] = v end

    -- Display/cosmetic toggles, also persisted by the menu.
    mod.Settings = {
        costumes = true,       -- show worn gear on the character
        suitedGlow = true,     -- gold pulse while Suited Up
        hud = true,            -- small text readouts under the player
    }

    mod.FOOTBALL_ANM2 = "gfx/gridiron_football_tear.anm2"

    -- Wearable gear counts toward Suited Up; actives and the bucket don't.
    mod.GEAR = {
        mod.Items.HELMET, mod.Items.PADS, mod.Items.JERSEY, mod.Items.CLEATS,
        mod.Items.EYE_BLACK, mod.Items.GLOVES, mod.Items.MOUTHGUARD,
    }

    mod.ACTIVE_ITEMS = {
        [mod.Items.KICKING_TEE] = true, [mod.Items.PIGSKIN] = true,
        [mod.Items.PLAYBOOK] = true, [mod.Items.WHISTLE] = true,
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
            playIndex = 0, trickShots = 0, bucket = 0,
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
    function mod.makeFootball(tear, dmgMult)
        tear.CollisionDamage = tear.CollisionDamage * dmgMult
        tear.Scale = tear.Scale * mod.Cfg.JERSEY_BALL_SCALE
        tear:AddTearFlags(TearFlags.TEAR_PIERCING | TearFlags.TEAR_SPECTRAL)
        tear.Color = Color(0.55, 0.3, 0.15, 1, 0.1, 0.05, 0) -- tints the splash on impact
        tear:GetData().GridironFootball = mod.newFootballSprite()
        tear:GetSprite().Color = Color(1, 1, 1, 0)
        sfx:Play(SoundEffect.SOUND_SHELLGAME, 0.6, 0, false, 1.3)
    end

    function mod.playWhistle(volume)
        if mod.Sounds.WHISTLE and mod.Sounds.WHISTLE > 0 then
            sfx:Play(mod.Sounds.WHISTLE, volume or 1)
        end
    end
end
