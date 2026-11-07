-- Interactions with base-game items.
--
-- Other scripts ask the hooks below (defaults live in core.lua) so each synergy
-- sits next to the others instead of being scattered through the gear code.
return function(mod)
    local Items, Cfg = mod.Items, mod.Cfg
    local pdata = mod.pdata
    local C = CollectibleType

    local function hasAny(player, list)
        for _, id in ipairs(list) do
            if id and player:HasCollectible(id) then return true end
        end
        return false
    end

    -- Football Helmet / Chin Strap tackles -------------------------------------------
    -- Charging items make a tackle go live sooner; Mars's dash is a tackle on its own.
    -- Big bodies (Leo, Thunder Thighs, Magic Mushroom, Bucket of Lard) hit harder.
    local CHARGERS = { C.COLLECTIBLE_ARIES, C.COLLECTIBLE_TAURUS }
    local BIG = { C.COLLECTIBLE_LEO, C.COLLECTIBLE_THUNDER_THIGHS, C.COLLECTIBLE_MAGIC_MUSHROOM,
        C.COLLECTIBLE_BUCKET_OF_LARD }

    function mod.tackleSynergy(player)
        local windup, dmg, knock = 1, 1, 1
        if hasAny(player, CHARGERS) then windup = 0.5 end
        if player:HasCollectible(C.COLLECTIBLE_MARS) and player.Velocity:Length() > Cfg.MARS_DASH_SPEED then
            windup = 0
        end
        if hasAny(player, BIG) then dmg, knock = Cfg.BIG_TACKLE_DAMAGE, Cfg.BIG_TACKLE_KNOCKBACK end
        return windup, dmg, knock
    end

    -- Receiver Gloves: Magneto / Telekinesis pull shots into your hands.
    function mod.catchBonus(player)
        return hasAny(player, { C.COLLECTIBLE_MAGNETO, C.COLLECTIBLE_TELEKINESIS }) and Cfg.MAGNET_CATCH_BONUS or 0
    end

    -- Shoulder Pads: Infamy is a riot shield on top of the pads.
    function mod.deflectBonus(player)
        return player:HasCollectible(C.COLLECTIBLE_INFAMY) and Cfg.INFAMY_DEFLECT_BONUS or 0
    end

    -- Kicking Tee: explosive builds turn the field goal into a bigger blast.
    local BOOM = { C.COLLECTIBLE_IPECAC, C.COLLECTIBLE_DR_FETUS, C.COLLECTIBLE_EPIC_FETUS,
        C.COLLECTIBLE_BOMBER_BOY, C.COLLECTIBLE_MR_MEGA }
    function mod.kickRadiusMult(player)
        return hasAny(player, BOOM) and Cfg.BOOM_KICK_RADIUS or 1
    end

    -- Pigskin: magnets pull enemies to the fumble from twice as far, twice as hard.
    function mod.fumblePullMult(player)
        return hasAny(player, { C.COLLECTIBLE_STRANGE_ATTRACTOR, C.COLLECTIBLE_MAGNETO }) and 2 or 1
    end

    -- Familiars: BFFS! makes the sideline crew better at their jobs.
    function mod.familiarBoost(player)
        return player:HasCollectible(C.COLLECTIBLE_BFFS) and Cfg.BFFS_FAMILIAR_BOOST or 1
    end

    -- Gatorade Bucket: what's in the bucket ends up on the floor.
    local SHOWER_CREEP = {
        { C.COLLECTIBLE_HOLY_WATER,    "PLAYER_CREEP_HOLYWATER" },
        { C.COLLECTIBLE_FREE_LEMONADE, "PLAYER_CREEP_LEMON_PARTY" },
        { C.COLLECTIBLE_LEMON_MISHAP,  "PLAYER_CREEP_LEMON_MISHAP" },
        { C.COLLECTIBLE_BALL_OF_TAR,   "PLAYER_CREEP_BLACK" },
        { C.COLLECTIBLE_JUICY_SACK,    "PLAYER_CREEP_WHITE" },
    }
    function mod.onGatoradeShower(player)
        for _, entry in ipairs(SHOWER_CREEP) do
            local variant = EffectVariant[entry[2]]
            if entry[1] and variant and player:HasCollectible(entry[1]) then
                local creep = Isaac.Spawn(EntityType.ENTITY_EFFECT, variant, 0, player.Position, Vector.Zero, player)
                creep.SpriteScale = Vector(Cfg.SHOWER_CREEP_SCALE, Cfg.SHOWER_CREEP_SCALE)
                local fx = creep:ToEffect()
                if fx then
                    fx.Scale = Cfg.SHOWER_CREEP_SCALE
                    fx.Timeout = Cfg.SHOWER_CREEP_FRAMES
                end
                return
            end
        end
    end

    -- Footballs without tears ----------------------------------------------------------
    -- Brimstone, Technology, Mom's Knife, Epic Fetus, the Forgotten's bone... none of them
    -- fire tears, so Team Jersey and the Quarterback would never throw a football. Count
    -- attacks instead (the fire delay resets on every attack) and throw one alongside.
    local function footballEvery(player)
        local qb = mod.quarterbackKind(player)
        if qb == "tainted" then return 2 end
        if qb == "normal" then
            return player:HasCollectible(C.COLLECTIBLE_BIRTHRIGHT) and 2 or Cfg.QB_EVERY_NTH
        end
        if player:HasCollectible(Items.JERSEY) then
            return mod.footballInterval(mod.jerseyNumber(player))
        end
    end

    function mod:OnPeffectSynergies(player)
        local d = pdata(player)
        local every = footballEvery(player)
        if not every or player:HasWeaponType(WeaponType.WEAPON_TEARS) then
            d.lastFireDelay = nil
            return
        end
        local fd = player.FireDelay
        local attacked = d.lastFireDelay ~= nil and fd > d.lastFireDelay + 0.5
        d.lastFireDelay = fd
        if not attacked then return end

        d.altShots = (d.altShots or 0) + 1
        if d.altShots % every ~= 0 then return end
        local dir = mod.aimDirection(player)
        mod.firingExtra = true
        local tear = player:FireTear(player.Position, dir * (10 * player.ShotSpeed), false, true, false, player, 1)
        mod.firingExtra = false
        if tear then
            mod.makeFootball(tear, Cfg.JERSEY_BALL_DMG_MULT)
            if mod.quarterbackKind(player) then
                tear.Velocity = tear.Velocity * Cfg.QB_ARM_SPEED
                tear.CollisionDamage = tear.CollisionDamage * Cfg.QB_ARM_DAMAGE
            end
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, mod.OnPeffectSynergies)

    -- External Item Descriptions: list each item's synergies under it.
    local function icon(id) return "{{Collectible" .. id .. "}}" end
    mod.SynergyNotes = {
        [Items.HELMET] = icon(C.COLLECTIBLE_MARS) .. " Mars: every dash is a tackle#" ..
            icon(C.COLLECTIBLE_ARIES) .. icon(C.COLLECTIBLE_TAURUS) .. " Aries / Taurus: tackles go live twice as fast#" ..
            icon(C.COLLECTIBLE_LEO) .. icon(C.COLLECTIBLE_THUNDER_THIGHS) .. " Size-up items: harder, longer tackles",
        [Items.CHIN_STRAP] = icon(C.COLLECTIBLE_MARS) .. " Mars: every dash is a tackle",
        [Items.GLOVES] = icon(C.COLLECTIBLE_MAGNETO) .. icon(C.COLLECTIBLE_TELEKINESIS) .. " Magneto / Telekinesis: +20% catch chance",
        [Items.PADS] = icon(C.COLLECTIBLE_INFAMY) .. " Infamy: +15% deflect chance",
        [Items.JERSEY] = icon(C.COLLECTIBLE_BRIMSTONE) .. " Brimstone, Technology, Mom's Knife, etc.: still throw footballs",
        [Items.KICKING_TEE] = icon(C.COLLECTIBLE_IPECAC) .. icon(C.COLLECTIBLE_DR_FETUS) .. " Explosive items: +50% blast radius",
        [Items.PIGSKIN] = icon(C.COLLECTIBLE_STRANGE_ATTRACTOR) .. icon(C.COLLECTIBLE_MAGNETO) .. " Magnets: pulls enemies twice as hard and far",
        [Items.GATORADE] = icon(C.COLLECTIBLE_HOLY_WATER) .. icon(C.COLLECTIBLE_FREE_LEMONADE) .. icon(C.COLLECTIBLE_BALL_OF_TAR) ..
            " Holy Water, lemons, Ball of Tar, Juicy Sack: the shower leaves matching creep",
        [Items.CHEERLEADER] = icon(C.COLLECTIBLE_BFFS) .. " BFFS!: stronger routines",
        [Items.WATER_BOY] = icon(C.COLLECTIBLE_BFFS) .. " BFFS!: drops hearts more often",
        [Items.DUMMY] = icon(C.COLLECTIBLE_BFFS) .. " BFFS!: pulls enemies from farther away",
    }
    mod.RegisterEID()
end
