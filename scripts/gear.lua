-- Passive gear, trinkets and stats.
return function(mod)
    local game, sfx = mod.game, mod.sfx
    local Items, Trinkets, Cfg = mod.Items, mod.Trinkets, mod.Cfg
    local pdata, forEachPlayer, rngFor = mod.pdata, mod.forEachPlayer, mod.rngFor

    -- Shoulder Pads shockwave: shove enemies away and swat nearby shots.
    local function padPop(player, origin, scale)
        scale = scale or 1
        local radius = Cfg.PADS_POP_RADIUS * scale
        for _, e in ipairs(Isaac.FindInRadius(origin, radius, EntityPartition.ENEMY)) do
            if e:IsVulnerableEnemy() and e:IsActiveEnemy(false) then
                local away = (e.Position - origin):Resized(Cfg.PADS_POP_KNOCKBACK * scale)
                if e:IsBoss() then away = away * 0.3 end
                e:AddVelocity(away)
                e:TakeDamage(player.Damage * scale, 0, EntityRef(player), 0)
            end
        end
        for _, b in ipairs(Isaac.FindInRadius(origin, radius * 0.8, EntityPartition.BULLET)) do
            local proj = b:ToProjectile()
            if proj and not proj:HasProjectileFlags(ProjectileFlags.CANT_HIT_PLAYER) then
                proj:Die()
            end
        end
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF02, 0, origin, Vector.Zero, player)
        sfx:Play(SoundEffect.SOUND_FORESTBOSS_STOMPS, 0.6 * scale + 0.2)
        game:ShakeScreen(math.floor(6 * scale))
    end
    mod.padPop = padPop

    -- Football Helmet: tackle ----------------------------------------------------
    local function updateTackle(player, d)
        local vel = player.Velocity
        if vel:Length() > Cfg.TACKLE_MIN_SPEED then
            local dir = vel:Normalized()
            if d.runDir and d.runDir:Dot(dir) > Cfg.TACKLE_STRAIGHTNESS then
                d.runFrames = d.runFrames + 1
            else
                d.runFrames = 0
            end
            d.runDir = dir
        else
            d.runFrames = 0
            d.runDir = nil
        end

        local windup = Cfg.TACKLE_WINDUP * mod.tackleWindupMult()
        if not player:HasCollectible(Items.HELMET) then windup = windup * Cfg.CHIN_STRAP_SOLO_WINDUP end
        if mod.isSuitedUp(player) then windup = windup / 2 end
        windup = math.floor(windup)
        local wasTackling = d.tackling
        d.tackling = d.runDir ~= nil and d.runFrames >= windup
        if not d.tackling then return end

        -- Tells: a whoosh when the tackle goes live, then a glow and a dust trail.
        if not wasTackling then
            sfx:Play(SoundEffect.SOUND_FETUS_JUMP, 0.6, 0, false, 0.8)
        end
        player:SetColor(Color(1, 1, 1, 1, 0.3, 0.18, 0), 2, 1, false, false)
        if d.runFrames % 5 == 0 then
            local dust = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.DUST_CLOUD, 0,
                player.Position - d.runDir * 10, Vector.Zero, player)
            dust:ToEffect().Timeout = 12
            dust.SpriteScale = Vector(0.5, 0.5)
        end

        local now = game:GetFrameCount()
        local reach = player.Size + Cfg.TACKLE_REACH
        for _, e in ipairs(Isaac.FindInRadius(player.Position, reach, EntityPartition.ENEMY)) do
            if e:IsVulnerableEnemy() and e:IsActiveEnemy(false) then
                local ed = e:GetData()
                if (ed.GridironTackleCD or 0) <= now then
                    ed.GridironTackleCD = now + Cfg.TACKLE_HIT_COOLDOWN
                    local dmg = (player.Damage * Cfg.TACKLE_DMG_MULT + Cfg.TACKLE_DMG_FLAT) * mod.tackleDamageMult()
                    local strapped = player:HasCollectible(Items.CHIN_STRAP)
                    if strapped then dmg = dmg * Cfg.CHIN_STRAP_DMG_MULT end
                    e:TakeDamage(dmg, 0, EntityRef(player), 0)
                    local push = d.runDir * Cfg.TACKLE_KNOCKBACK
                    if e:IsBoss() then push = push * 0.25 end
                    e:AddVelocity(push)
                    e:AddConfusion(EntityRef(player), Cfg.TACKLE_CONFUSE, true)
                    if strapped then
                        e:AddFreeze(EntityRef(player), e:IsBoss() and 10 or Cfg.CHIN_STRAP_STUN)
                    end
                    sfx:Play(SoundEffect.SOUND_PUNCH)
                    sfx:Play(SoundEffect.SOUND_MEAT_IMPACTS, 0.6)
                    game:ShakeScreen(5)
                    Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.IMPACT, 0, e.Position, Vector.Zero, player)
                    mod.popOn(e, "TACKLE!", mod.Colors.orange)
                    if player:HasCollectible(Items.PADS) then
                        padPop(player, e.Position, 0.6)
                    end
                end
            end
        end
    end

    -- Football Cleats: yards and first downs -------------------------------------
    local function updateCleats(player, d)
        local room = game:GetRoom()
        if room:IsClear() or d.firstDowns >= Cfg.MAX_FIRST_DOWNS then return end
        d.yardDist = d.yardDist + player.Velocity:Length()
        local needed = Cfg.YARD_UNITS * Cfg.FIRST_DOWN_YARDS
        if d.yardDist >= needed then
            d.yardDist = d.yardDist - needed
            d.firstDowns = d.firstDowns + 1
            mod.refreshCache(player)
            player:SetColor(Color(1, 1, 1, 1, 0.1, 0.4, 0.1), 10, 1, true, false)
            sfx:Play(SoundEffect.SOUND_THUMBSUP, 0.7)
            local ord = ({ "1ST", "2ND", "3RD", "4TH" })[d.firstDowns] or ""
            mod.popOn(player, ord .. " DOWN!", mod.Colors.green)
        end
    end

    -- Per-player update ----------------------------------------------------------
    function mod:OnPeffectUpdate(player)
        local d = pdata(player)

        -- Re-evaluate damage when the number of gear pieces changes (set bonus).
        local count = mod.gearCount(player)
        if count ~= d.lastGearCount then
            if d.lastGearCount and count >= Cfg.SUITED_UP_PIECES and d.lastGearCount < Cfg.SUITED_UP_PIECES then
                game:GetHUD():ShowItemText("Suited Up!", "Ready for kickoff")
                sfx:Play(SoundEffect.SOUND_POWERUP_SPEWER)
                if mod.OnSuitedUp then mod.OnSuitedUp(player) end
            end
            d.lastGearCount = count
            mod.refreshCache(player)
        end

        -- Announce the jersey number the first time it's picked up.
        if player:HasCollectible(Items.JERSEY) and not d.jerseyShown then
            d.jerseyShown = true
            local num = mod.jerseyNumber(player)
            game:GetHUD():ShowItemText("#" .. num, "Every " .. mod.footballInterval(num) .. " shots: go long")
        end

        if player:HasCollectible(Items.HELMET) or player:HasCollectible(Items.CHIN_STRAP) then
            updateTackle(player, d)
        else
            d.tackling = false
        end

        if player:HasCollectible(Items.CLEATS) then
            updateCleats(player, d)
        end

        -- Mouthguard: keep your head straight.
        if player:HasCollectible(Items.MOUTHGUARD) then
            local dazed = EntityFlag.FLAG_FEAR | EntityFlag.FLAG_CONFUSION
            if player:HasEntityFlags(dazed) then player:ClearEntityFlags(dazed) end
        end

        if not player:HasCollectible(Items.GLOVES) then
            d.caught = 0
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, mod.OnPeffectUpdate)

    -- Stats ----------------------------------------------------------------------
    function mod:OnEvaluateCache(player, flag)
        local d = pdata(player)
        if flag == CacheFlag.CACHE_DAMAGE then
            local bonus = 0
            if player:HasCollectible(Items.CLEATS) then
                bonus = bonus + d.firstDowns * Cfg.FIRST_DOWN_DAMAGE
            end
            if player:HasCollectible(Items.RING) then
                bonus = bonus + d.rings * Cfg.RING_DAMAGE
            end
            if d.coinHeads then
                bonus = bonus + Cfg.COIN_HEADS_DAMAGE
            end
            if mod.isSuitedUp(player) then
                bonus = bonus + Cfg.SUITED_UP_DAMAGE
            end
            if d.touchdown then
                bonus = bonus + Cfg.TOUCHDOWN_DAMAGE
            end
            player.Damage = player.Damage + bonus
        elseif flag == CacheFlag.CACHE_SPEED then
            player.MoveSpeed = player.MoveSpeed + player:GetCollectibleNum(Items.CLEATS) * Cfg.CLEATS_SPEED
            if d.play == "blitz" then player.MoveSpeed = player.MoveSpeed + Cfg.BLITZ_SPEED end
        elseif flag == CacheFlag.CACHE_LUCK then
            player.Luck = player.Luck + player:GetCollectibleNum(Items.EYE_BLACK) * Cfg.EYE_BLACK_LUCK
                + player:GetCollectibleNum(Items.RING) * Cfg.RING_LUCK
        elseif flag == CacheFlag.CACHE_FIREDELAY then
            if d.play == "blitz" then player.MaxFireDelay = player.MaxFireDelay * Cfg.BLITZ_FIRE_DELAY_MULT end
        elseif flag == CacheFlag.CACHE_RANGE then
            if d.play == "hailmary" then player.TearRange = player.TearRange + Cfg.HAIL_MARY_RANGE end
        elseif flag == CacheFlag.CACHE_SHOTSPEED then
            if d.play == "hailmary" then player.ShotSpeed = player.ShotSpeed + Cfg.HAIL_MARY_SHOT_SPEED end
        elseif flag == CacheFlag.CACHE_TEARFLAG then
            if d.play == "hailmary" then player.TearFlags = player.TearFlags | TearFlags.TEAR_PIERCING end
        end
    end
    mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, mod.OnEvaluateCache)

    -- New room: reset per-room bonuses, Team Jersey pre-snap freeze --------------
    function mod:OnNewRoomGear()
        forEachPlayer(function(player)
            local d = pdata(player)
            d.runFrames = 0
            d.runDir = nil
            d.tackling = false
            d.guardUsed = false
            d.hitThisRoom = false
            if d.firstDowns > 0 or d.yardDist > 0 or d.touchdown or d.coinHeads then
                d.firstDowns = 0
                d.yardDist = 0
                d.touchdown = false
                d.coinHeads = false
                mod.refreshCache(player)
            end
        end)

        local room = game:GetRoom()
        if room:IsClear() then return end
        local snapper
        forEachPlayer(function(p) if not snapper and p:HasCollectible(Items.JERSEY) then snapper = p end end)
        if not snapper then return end

        local froze = false
        for _, e in ipairs(Isaac.GetRoomEntities()) do
            if e:IsActiveEnemy(false) and e:IsVulnerableEnemy() then
                local duration = e:IsBoss() and math.floor(Cfg.JERSEY_SNAP_FREEZE / 2) or Cfg.JERSEY_SNAP_FREEZE
                e:AddFreeze(EntityRef(snapper), duration)
                froze = true
            end
        end
        if froze then
            sfx:Play(SoundEffect.SOUND_BUTTON_PRESS, 0.8)
            mod.popOn(snapper, "SET... HUT!", mod.Colors.yellow)
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoomGear)

    -- Gatorade Bucket: clean rooms fill the bucket, a full bucket is a shower.
    local function gatoradeShower(player)
        local d = pdata(player)
        d.bucket = 0
        if player:GetHearts() < player:GetEffectiveMaxHearts() then
            player:AddHearts(2)
        else
            player:AddSoulHearts(1)
        end
        player:SetColor(Color(1, 1, 1, 1, 0.5, 0.25, 0), 30, 1, true, false)
        local orange = Color(1, 0.6, 0.1, 1, 0.4, 0.15, 0)
        local splash = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF02, 0, player.Position, Vector.Zero, player)
        splash.Color = orange
        mod.burst(player.Position, EffectVariant.TEAR_POOF_A, 8, orange, 18)
        sfx:Play(SoundEffect.SOUND_SPLATTER, 1.2)
        mod.popOn(player, "GATORADE SHOWER!", mod.Colors.orange)
        game:GetHUD():ShowItemText("Gatorade shower!", "Victory tastes like orange")
    end

    function mod:OnRoomClearAward()
        local bossRoom = game:GetRoom():GetType() == RoomType.ROOM_BOSS
        forEachPlayer(function(player)
            if not player:HasCollectible(Items.GATORADE) then return end
            local d = pdata(player)
            if d.hitThisRoom then return end
            d.bucket = bossRoom and Cfg.GATORADE_FILLS or d.bucket + 1
            if d.bucket >= Cfg.GATORADE_FILLS then
                gatoradeShower(player)
            else
                sfx:Play(SoundEffect.SOUND_PLOP, 0.8, 0, false, 0.8)
                mod.popOn(player, "SHUTOUT! " .. d.bucket .. "/" .. Cfg.GATORADE_FILLS, mod.Colors.orange)
            end
        end)
    end
    mod:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, mod.OnRoomClearAward)

    -- Tears: footballs (Team Jersey, Receiver Gloves, Trick Play), Eye Black ----
    local throwingCaught = false

    function mod:OnFireTear(tear)
        if throwingCaught then return end
        local player = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
        if not player then return end
        local d = pdata(player)

        if player:HasCollectible(Items.EYE_BLACK) then
            tear:GetData().GridironOrigin = tear.Position
        end

        local football = false
        if player:HasCollectible(Items.JERSEY) then
            d.shots = d.shots + 1
            if d.shots % mod.footballInterval(mod.jerseyNumber(player)) == 0 then
                football = true
            end
        end
        if d.play == "trick" and d.trickShots > 0 then
            d.trickShots = d.trickShots - 1
            football = true
        end
        if football then
            mod.makeFootball(tear, Cfg.JERSEY_BALL_DMG_MULT)
        end

        -- Receiver Gloves: throw back one caught shot alongside this tear.
        if d.caught > 0 and player:HasCollectible(Items.GLOVES) then
            d.caught = d.caught - 1
            local spread = rngFor(player, Items.GLOVES):RandomInt(21) - 10
            throwingCaught = true
            local extra = player:FireTear(player.Position, tear.Velocity:Rotated(spread) * 1.1,
                false, true, false, player, Cfg.GLOVES_THROW_DMG)
            throwingCaught = false
            if extra then
                if player:HasCollectible(Items.EYE_BLACK) then
                    extra:GetData().GridironOrigin = extra.Position
                end
                mod.makeFootball(extra, 1)
            end
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, mod.OnFireTear)

    -- Football tears: hide the vanilla tear and draw a spiraling ball instead.
    function mod:OnTearUpdate(tear)
        local ball = tear:GetData().GridironFootball
        if not ball then return end
        tear:GetSprite().Color = Color(1, 1, 1, 0)
        ball:Update()
        if tear.Velocity:Length() > 0.1 then
            ball.Rotation = tear.Velocity:GetAngleDegrees()
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, mod.OnTearUpdate)

    function mod:OnTearRender(tear, renderOffset)
        local ball = tear:GetData().GridironFootball
        if not ball or mod.isReflectionPass() then return end
        local s = math.max(tear.Scale, 0.6)
        ball.Scale = Vector(s, s)
        ball:Render(Isaac.WorldToScreen(tear.Position + tear.PositionOffset) + renderOffset)
    end
    mod:AddCallback(ModCallbacks.MC_POST_TEAR_RENDER, mod.OnTearRender)

    -- Projectiles: glove catches, facemask blocks, shoulder pad deflections ------
    function mod:OnProjectileCollision(proj, collider)
        local player = collider and collider:ToPlayer()
        if not player then return end
        if proj:HasProjectileFlags(ProjectileFlags.CANT_HIT_PLAYER) then return end
        local d = pdata(player)

        -- Hands are free only when you're not shooting.
        if player:HasCollectible(Items.GLOVES) and d.caught < Cfg.GLOVES_MAX_HELD
            and player:GetAimDirection():Length() < 0.1 then
            if rngFor(player, Items.GLOVES):RandomFloat() < Cfg.GLOVES_CATCH_CHANCE then
                proj:Remove()
                d.caught = d.caught + 1
                sfx:Play(SoundEffect.SOUND_PLOP, 1.2)
                player:SetColor(Color(1, 1, 1, 1, 0.3, 0.3, 0.3), 6, 1, true, false)
                mod.popOn(player, "CATCH!", mod.Colors.white)
                return true
            end
        end

        if player:HasCollectible(Items.HELMET) then
            local face = mod.DIR_VECTORS[player:GetHeadDirection()]
            local toProj = proj.Position - player.Position
            if face and toProj:Length() > 0.01 and face:Dot(toProj:Normalized()) > Cfg.FACEMASK_ARC then
                if rngFor(player, Items.HELMET):RandomFloat() < Cfg.FACEMASK_BLOCK_CHANCE then
                    proj:Die()
                    sfx:Play(SoundEffect.SOUND_METAL_BLOCKBREAK, 0.5, 0, false, 1.4)
                    mod.popOn(player, "BLOCKED", mod.Colors.grey, 0.8)
                    return true
                end
            end
        end

        if player:HasCollectible(Items.PADS) then
            if rngFor(player, Items.PADS):RandomFloat() < Cfg.PADS_DEFLECT_CHANCE then
                proj.Velocity = proj.Velocity * -1.3
                proj:AddProjectileFlags(ProjectileFlags.HIT_ENEMIES | ProjectileFlags.CANT_HIT_PLAYER)
                proj.Color = Color(0.5, 0.7, 1, 1, 0, 0, 0.2)
                sfx:Play(SoundEffect.SOUND_PUNCH, 0.6)
                mod.popOn(player, "DEFLECT", mod.Colors.blue, 0.8)
                return true
            end
        end
    end
    mod:AddCallback(ModCallbacks.MC_PRE_PROJECTILE_COLLISION, mod.OnProjectileCollision)

    -- Damage ---------------------------------------------------------------------
    local reapplyingEnemy = false
    local reapplyingPlayer = false

    -- Referee Flag: whoever hit you gets penalized.
    local function throwFlag(player, source)
        local offender = source and source.Entity
        if offender and offender.Type == EntityType.ENTITY_PROJECTILE then
            offender = offender.SpawnerEntity
        end
        if not offender or not offender:IsVulnerableEnemy() then return end
        local stage = game:GetLevel():GetStage()
        local dmg = (Cfg.FLAG_DAMAGE + Cfg.FLAG_DAMAGE_PER_STAGE * stage) * player:GetTrinketMultiplier(Trinkets.FLAG)
        offender:TakeDamage(dmg, 0, EntityRef(player), 0)
        offender:AddSlowing(EntityRef(player), Cfg.FLAG_SLOW_FRAMES, 0.6, Color(1, 1, 0.3, 1, 0.2, 0.2, 0))
        offender:SetColor(Color(1, 1, 1, 1, 0.6, 0.5, 0), 20, 1, true, false)
        mod.playWhistle(0.7)
        mod.popOn(offender, "FLAG!", mod.Colors.yellow)
    end

    function mod:OnPlayerDamage(entity, amount, flags, source, countdown)
        local player = entity:ToPlayer()
        if not player then return end
        local d = pdata(player)
        local contact = mod.isContactDamage(source)

        -- Your own field goal doesn't blow you up (even if the blast lands a frame late).
        if mod.kickExploding or (mod.kickBlastFrame and flags & DamageFlag.DAMAGE_EXPLOSION ~= 0
            and game:GetFrameCount() - mod.kickBlastFrame <= 2) then
            return false
        end

        -- Mid-tackle you are the one doing the hitting.
        if contact and d.tackling then
            return false
        end

        -- Padded Pants: shrug off some contact hits and stiff-arm the enemy away.
        if contact and player:HasCollectible(Items.PANTS) then
            local chance = math.min(Cfg.PANTS_MAX_CHANCE,
                Cfg.PANTS_IGNORE_CHANCE * player:GetCollectibleNum(Items.PANTS))
            if rngFor(player, Items.PANTS):RandomFloat() < chance then
                player:SetMinDamageCooldown(30)
                sfx:Play(SoundEffect.SOUND_PUNCH, 0.7)
                local enemy = source.Entity
                local away = enemy.Position - player.Position
                if away:Length() > 0.1 and not enemy:IsBoss() then
                    enemy:AddVelocity(away:Resized(Cfg.PANTS_STIFF_ARM))
                end
                mod.popOn(player, "STIFF ARM!", mod.Colors.white)
                return false
            end
        end

        -- Mouthguard: the first big hit each room only takes half a heart less.
        if not reapplyingPlayer and not d.guardUsed and amount >= Cfg.MOUTHGUARD_MIN_HIT
            and player:HasCollectible(Items.MOUTHGUARD) then
            d.guardUsed = true
            reapplyingPlayer = true
            player:TakeDamage(amount - Cfg.MOUTHGUARD_REDUCTION, flags, source, countdown)
            reapplyingPlayer = false
            sfx:Play(SoundEffect.SOUND_TEARIMPACTS, 0.8, 0, false, 0.7)
            mod.popOn(player, "BITE DOWN!", mod.Colors.blue)
            return false
        end

        -- The hit is landing from here on.
        d.hitThisRoom = true

        if Trinkets.FLAG > 0 and player:HasTrinket(Trinkets.FLAG) then
            throwFlag(player, source)
        end

        -- Concussion Protocol: everyone in the room gets their bell rung.
        if Trinkets.PROTOCOL > 0 and player:HasTrinket(Trinkets.PROTOCOL) then
            local frames = Cfg.PROTOCOL_DAZE * player:GetTrinketMultiplier(Trinkets.PROTOCOL)
            for _, e in ipairs(Isaac.GetRoomEntities()) do
                if e:IsVulnerableEnemy() and e:IsActiveEnemy(false) then
                    e:AddConfusion(EntityRef(player), frames, false)
                end
            end
            mod.popOn(player, "PROTOCOL!", mod.Colors.blue)
        end

        -- Shoulder Pads: the hit lands, but you pop everything around you.
        if player:HasCollectible(Items.PADS) then
            padPop(player, player.Position, 1)
        end
    end
    mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.OnPlayerDamage, EntityType.ENTITY_PLAYER)

    local function playerFromSource(source)
        local e = source and source.Entity
        if not e then return nil end
        local p = e:ToPlayer()
        if p then return p end
        local spawner = e.SpawnerEntity
        return spawner and spawner:ToPlayer()
    end

    -- Damage bonuses on enemies, combined so the hit is re-applied only once:
    -- Eye Black (long-range tears) and Foam Finger (the marked #1 enemy).
    function mod:OnEnemyDamage(entity, amount, flags, source, countdown)
        if reapplyingEnemy then return end
        if not entity:IsVulnerableEnemy() or not source or not source.Entity then return end

        local mult = 1
        if source.Type == EntityType.ENTITY_TEAR then
            local origin = source.Entity:GetData().GridironOrigin
            if origin then
                local dist = (source.Entity.Position - origin):Length()
                mult = mult + math.min(dist / Cfg.EYE_BLACK_RANGE_FULL, 1) * Cfg.EYE_BLACK_MAX_BONUS
            end
        end
        if mod.isMarked and mod.isMarked(entity) then
            local player = playerFromSource(source)
            if player and player:HasCollectible(Items.FOAM_FINGER) then
                mult = mult + Cfg.FINGER_BONUS
            end
        end
        if mult < 1.05 then return end

        reapplyingEnemy = true
        entity:TakeDamage(amount * mult, flags, source, countdown)
        reapplyingEnemy = false
        return false
    end
    mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.OnEnemyDamage)

    -- Eye Black: no Curse of Darkness.
    function mod:OnCurseEval(curses)
        if mod.anyPlayerHas(Items.EYE_BLACK) and curses & LevelCurse.CURSE_OF_DARKNESS ~= 0 then
            return curses & ~LevelCurse.CURSE_OF_DARKNESS
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_CURSE_EVAL, mod.OnCurseEval)
end
