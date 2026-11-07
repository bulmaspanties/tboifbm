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

    -- Football Helmet tackles --------------------------------------------------------
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
        if mod.isJuiced(player) then dmg, knock = dmg * Cfg.JUICED_DAMAGE, knock * Cfg.JUICED_KNOCKBACK end
        return windup, dmg, knock
    end

    -- Juiced: steroids and football. Tackles hit far harder and send enemies flying into
    -- each other (pinball), and referees take notice (drug tests; see monsters.lua / foes.lua).
    local JUICE = { C.COLLECTIBLE_ROID_RAGE, C.COLLECTIBLE_GROWTH_HORMONES, C.COLLECTIBLE_SYNTHOIL,
        C.COLLECTIBLE_EXPERIMENTAL_TREATMENT }
    function mod.isJuiced(player)
        return hasAny(player, JUICE)
    end

    function mod.drugTestOn()
        if not mod.Settings.drugTests then return false end
        local juiced = false
        mod.forEachPlayer(function(p) if mod.isJuiced(p) then juiced = true end end)
        return juiced
    end

    -- Pinball: a juiced tackle's victim crashes through anything in its way, then the stun lands.
    function mod:OnNpcUpdatePinball(npc)
        local launch = npc:GetData().GridironLaunched
        if not launch then return end
        launch.frames = launch.frames - 1
        for _, other in ipairs(Isaac.FindInRadius(npc.Position, npc.Size + 18, EntityPartition.ENEMY)) do
            if GetPtrHash(other) ~= GetPtrHash(npc) and other:IsVulnerableEnemy() and other:IsActiveEnemy(false)
                and not other:GetData().GridironPinballed then
                other:GetData().GridironPinballed = true
                other:TakeDamage(launch.dmg, 0, EntityRef(launch.player), 0)
                other:AddVelocity((other.Position - npc.Position):Resized(8))
                mod.popOn(other, "PINBALL!", mod.Colors.red, 0.9)
                mod.playSound("CLACK", 0.8)
            end
        end
        if launch.frames <= 0 then
            npc:GetData().GridironLaunched = nil
            npc:AddFreeze(EntityRef(launch.player), launch.stun)
        end
    end
    mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, mod.OnNpcUpdatePinball)

    -- Knockout Drops: tackled enemies stay down much longer.
    function mod.tackleStunMult(player)
        return player:HasCollectible(C.COLLECTIBLE_KNOCKOUT_DROPS) and Cfg.KNOCKOUT_STUN_MULT or 1
    end

    -- Mom's Bracelet: kicks and fumbles go much farther.
    function mod.throwRangeMult(player)
        return player:HasCollectible(C.COLLECTIBLE_MOMS_BRACELET) and Cfg.BRACELET_RANGE or 1
    end

    -- Ball of Bandages: the Water Boy is a real trainer now: more often, and whole hearts.
    function mod.waterBoyBoost(player)
        if player:HasCollectible(C.COLLECTIBLE_BALL_OF_BANDAGES) then return 1.5, HeartSubType.HEART_FULL end
        return 1, HeartSubType.HEART_HALF
    end

    -- Gnawed Leaf: the Tackling Dummy digs in: wider and much stronger pull.
    function mod.dummyPullMult(player)
        return player:HasCollectible(C.COLLECTIBLE_GNAWED_LEAF) and 2 or 1
    end

    -- Number One + Foam Finger: "We're #1": the marked enemy drops a nickel instead of a penny.
    function mod.fingerDrop(player)
        return player:HasCollectible(C.COLLECTIBLE_NUMBER_ONE) and CoinSubType.COIN_NICKEL or CoinSubType.COIN_PENNY
    end

    -- Pills: playing through the pain, and speed.
    function mod:OnUsePillSynergy(effect, player)
        local d = pdata(player)
        if effect == PillEffect.PILLEFFECT_PERCS or effect == PillEffect.PILLEFFECT_ADDICTED then
            if player:HasCollectible(Items.MOUTHGUARD) then
                d.playingHurt = true                         -- the Mouthguard works on every hit this room
                mod.popOn(player, "PLAYING THROUGH THE PAIN", mod.Colors.blue, 0.9)
            end
        elseif effect == PillEffect.PILLEFFECT_SPEED_UP then
            d.speedUpRoom = true                             -- first downs come twice as fast this room
        end
    end
    mod:AddCallback(ModCallbacks.MC_USE_PILL, mod.OnUsePillSynergy)

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
        if player:HasCollectible(C.COLLECTIBLE_ADRENALINE) then
            local d = pdata(player)                          -- Adrenaline: the shower is a rush
            d.adrenalineRush = true
            mod.refreshCache(player, CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SPEED)
            mod.popOn(player, "ADRENALINE!", mod.Colors.red, 1.0)
        end
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

    -- Football Cleats: Pony, White Pony and Taurus cover ground: first downs need half the yards.
    function mod.yardMult(player)
        if pdata(player).speedUpRoom then return 0.5 end
        return hasAny(player, { C.COLLECTIBLE_PONY, C.COLLECTIBLE_WHITE_PONY, C.COLLECTIBLE_TAURUS,
            C.COLLECTIBLE_SPEED_BALL }) and 0.5 or 1
    end

    -- Super Bowl Ring: Money = Power / Greed's Gullet: the hardware is worth twice as much.
    function mod.ringMult(player)
        local mult = hasAny(player, { C.COLLECTIBLE_MONEY_EQUALS_POWER, C.COLLECTIBLE_GREEDS_GULLET }) and 2 or 1
        if player:HasCollectible(Items.CHAMP_RING) then mult = mult * 2 end   -- back-to-back rings
        if player:HasCollectible(C.COLLECTIBLE_CHAMPION_BELT) then mult = mult * 2 end   -- title belt and ring
        return mult
    end

    -- Foam Finger: Marked / Eye of the Occult: the #1 enemy takes double the bonus.
    function mod.fingerMult(player)
        return hasAny(player, { C.COLLECTIBLE_MARKED, C.COLLECTIBLE_EYE_OF_THE_OCCULT, C.COLLECTIBLE_NUMBER_ONE }) and 2 or 1
    end

    -- Padded Pants: big legs shrug off more.
    function mod.pantsBonus(player)
        return hasAny(player, { C.COLLECTIBLE_THUNDER_THIGHS, C.COLLECTIBLE_LEO }) and Cfg.BIG_PANTS_BONUS or 0
    end

    -- QB Wristband: with a homing item every football is a dime.
    function mod.wristbandMult(player)
        return hasAny(player, { C.COLLECTIBLE_SPOON_BENDER, C.COLLECTIBLE_GODHEAD, C.COLLECTIBLE_SACRED_HEART })
            and Cfg.WRISTBAND_HOMING_DMG or 1
    end

    -- Turf Burn: cleats dig in, so the scorch marks last twice as long.
    function mod.turfBurnFrames(player)
        return player:HasCollectible(Items.CLEATS) and 2 or 1
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
            icon(C.COLLECTIBLE_LEO) .. icon(C.COLLECTIBLE_THUNDER_THIGHS) .. " Size-up items: harder, longer tackles#" ..
            icon(C.COLLECTIBLE_ROID_RAGE) .. icon(C.COLLECTIBLE_GROWTH_HORMONES) .. icon(C.COLLECTIBLE_SYNTHOIL) ..
            " Juiced: tackles hit 50% harder and send enemies pinballing into each other (referees notice)#" ..
            icon(C.COLLECTIBLE_KNOCKOUT_DROPS) .. " Knockout Drops: tackled enemies stay down 3x longer",
        [Items.MOUTHGUARD] = "{{Pill}} Percs! / Addicted!: works on every hit for the room",
        [Items.GLOVES] = icon(C.COLLECTIBLE_MAGNETO) .. icon(C.COLLECTIBLE_TELEKINESIS) .. " Magneto / Telekinesis: +20% catch chance",
        [Items.PADS] = icon(C.COLLECTIBLE_INFAMY) .. " Infamy: +15% deflect chance",
        [Items.JERSEY] = icon(C.COLLECTIBLE_BRIMSTONE) .. " Brimstone, Technology, Mom's Knife, etc.: still throw footballs#" ..
            "Footballs take on your tear effects' colours (fire, poison, holy, ice...)",
        [Items.CLEATS] = icon(C.COLLECTIBLE_PONY) .. icon(C.COLLECTIBLE_WHITE_PONY) .. icon(C.COLLECTIBLE_TAURUS) ..
            icon(C.COLLECTIBLE_SPEED_BALL) .. " Pony / White Pony / Taurus / Speed Ball: first downs need half the yards#" ..
            "{{Pill}} Speed Up: the same, for the room",
        [Items.PANTS] = icon(C.COLLECTIBLE_THUNDER_THIGHS) .. icon(C.COLLECTIBLE_LEO) .. " Thunder Thighs / Leo: +15% shrug-off chance",
        [Items.RING] = icon(C.COLLECTIBLE_MONEY_EQUALS_POWER) .. icon(C.COLLECTIBLE_GREEDS_GULLET) ..
            " Money = Power / Greed's Gullet: rings give double damage#" ..
            icon(C.COLLECTIBLE_CHAMPION_BELT) .. " Champion Belt: title belt and ring, double again#" ..
            icon(Items.CHAMP_RING) .. " Championship Ring: rings give double damage (stacks)",
        [Items.CHAMP_RING] = icon(Items.RING) .. " Super Bowl Ring: its rings give double damage",
        [Items.GOLDEN_ARM] = icon(Items.WRISTBAND) .. " QB Wristband: every golden football homes in#" ..
            icon(C.COLLECTIBLE_BRIMSTONE) .. " Works with non-tear weapons too (every few attacks)",
        [Items.HAIL_MARY] = icon(C.COLLECTIBLE_CAR_BATTERY) .. " Car Battery: two Hail Marys",
        [Items.FOAM_FINGER] = icon(C.COLLECTIBLE_MARKED) .. icon(C.COLLECTIBLE_EYE_OF_THE_OCCULT) ..
            " Marked / Eye of the Occult: +100% damage to the #1 enemy#" ..
            icon(C.COLLECTIBLE_NUMBER_ONE) .. " Number One: we're #1! Double damage, and it drops a nickel",
        [Items.WRISTBAND] = icon(C.COLLECTIBLE_SPOON_BENDER) .. icon(C.COLLECTIBLE_GODHEAD) .. icon(C.COLLECTIBLE_SACRED_HEART) ..
            " Homing items: footballs deal another +25%#" .. icon(Items.JERSEY) .. icon(Items.GLOVES) .. icon(Items.PLAYBOOK) ..
            " Works on every football: Jersey, Gloves, Trick Play, the Quarterback",
        [Items.END_ZONE] = icon(Items.PIGSKIN) .. " Pigskin: a touchdown scored in the end zone counts double",
        [Items.KICKING_TEE] = icon(C.COLLECTIBLE_IPECAC) .. icon(C.COLLECTIBLE_DR_FETUS) .. " Explosive items: +50% blast radius#" ..
            icon(C.COLLECTIBLE_MOMS_BRACELET) .. " Mom's Bracelet: kicks go 50% farther",
        [Items.PIGSKIN] = icon(C.COLLECTIBLE_STRANGE_ATTRACTOR) .. icon(C.COLLECTIBLE_MAGNETO) .. " Magnets: pulls enemies twice as hard and far#" ..
            icon(C.COLLECTIBLE_MOMS_BRACELET) .. " Mom's Bracelet: fumbles go 50% farther#" ..
            icon(Items.END_ZONE) .. " End Zone: touchdowns in it count double",
        [Items.GATORADE] = icon(C.COLLECTIBLE_HOLY_WATER) .. icon(C.COLLECTIBLE_FREE_LEMONADE) .. icon(C.COLLECTIBLE_BALL_OF_TAR) ..
            " Holy Water, lemons, Ball of Tar, Juicy Sack: the shower leaves matching creep#" ..
            icon(C.COLLECTIBLE_ADRENALINE) .. " Adrenaline: the shower is a rush (+1 damage, +0.2 speed for the room)",
        [Items.CHEERLEADER] = icon(C.COLLECTIBLE_BFFS) .. " BFFS!: stronger routines#" ..
            icon(C.COLLECTIBLE_JUMPER_CABLES) .. " Jumper Cables: every routine charges your active item",
        [Items.WATER_BOY] = icon(C.COLLECTIBLE_BFFS) .. " BFFS!: drops hearts more often#" ..
            icon(C.COLLECTIBLE_BALL_OF_BANDAGES) .. " Ball of Bandages: a real trainer: more often, and whole hearts",
        [Items.DUMMY] = icon(C.COLLECTIBLE_BFFS) .. " BFFS!: pulls enemies from farther away#" ..
            icon(C.COLLECTIBLE_GNAWED_LEAF) .. " Gnawed Leaf: digs in: much wider, twice as strong pull",
    }
    mod.RegisterEID()
end
