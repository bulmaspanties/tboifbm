-- Familiars: Cheerleader, Water Boy, Tackling Dummy.
return function(mod)
    local game, sfx = mod.game, mod.sfx
    local Items, Cfg = mod.Items, mod.Cfg
    local pdata, forEachPlayer = mod.pdata, mod.forEachPlayer

    local Variants = {
        CHEERLEADER = Isaac.GetEntityVariantByName("Gridiron Cheerleader"),
        WATER_BOY   = Isaac.GetEntityVariantByName("Gridiron Water Boy"),
        DUMMY       = Isaac.GetEntityVariantByName("Gridiron Tackling Dummy"),
    }
    mod.FamiliarVariants = Variants

    local FAMILIAR_ITEMS = {
        { variant = Variants.CHEERLEADER, item = Items.CHEERLEADER },
        { variant = Variants.WATER_BOY,   item = Items.WATER_BOY },
        { variant = Variants.DUMMY,       item = Items.DUMMY },
    }

    local DUMMY_ORBIT_LAYER = 2

    -- Spawn / despawn to match how many of each item (and Box of Friends copies) you have.
    function mod:OnCacheFamiliars(player, flag)
        if flag ~= CacheFlag.CACHE_FAMILIARS then return end
        for _, f in ipairs(FAMILIAR_ITEMS) do
            if f.variant > 0 and f.item > 0 then
                local count = player:GetCollectibleNum(f.item) + player:GetEffects():GetCollectibleEffectNum(f.item)
                player:CheckFamiliar(f.variant, count, player:GetCollectibleRNG(f.item),
                    Isaac.GetItemConfig():GetCollectible(f.item))
            end
        end
    end
    mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, mod.OnCacheFamiliars)

    local function familiarsOf(player, variant)
        local list = {}
        local owner = GetPtrHash(player)
        for _, e in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, variant)) do
            local fam = e:ToFamiliar()
            if fam and fam.Player and GetPtrHash(fam.Player) == owner then list[#list + 1] = fam end
        end
        return list
    end

    local function backToIdle(fam)
        local s = fam:GetSprite()
        if not s:IsPlaying("Idle") and s:IsFinished() then s:Play("Idle", true) end
    end

    -- Followers ---------------------------------------------------------------------
    function mod:OnFollowerInit(fam)
        fam:AddToFollowers()
        fam:GetSprite():Play("Idle", true)
    end
    mod:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, mod.OnFollowerInit, Variants.CHEERLEADER)
    mod:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, mod.OnFollowerInit, Variants.WATER_BOY)

    function mod:OnFollowerUpdate(fam)
        fam:FollowParent()
        backToIdle(fam)
    end
    mod:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, mod.OnFollowerUpdate, Variants.CHEERLEADER)
    mod:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, mod.OnFollowerUpdate, Variants.WATER_BOY)

    -- Cheerleader: kills build hype; a full routine is a fire-rate boost --------------
    function mod:OnNpcDeathCheer(npc)
        if not npc:IsEnemy() then return end
        forEachPlayer(function(player)
            if not player:HasCollectible(Items.CHEERLEADER) then return end
            local d = pdata(player)
            d.hype = (d.hype or 0) + 1
            if d.hype < Cfg.CHEER_HYPE then return end
            d.hype = 0
            d.cheerTimer = Cfg.CHEER_FRAMES
            mod.refreshCache(player, CacheFlag.CACHE_FIREDELAY)
            for _, fam in ipairs(familiarsOf(player, Variants.CHEERLEADER)) do
                fam:GetSprite():Play("Cheer", true)
                mod.popOn(fam, "GO TEAM!", mod.Colors.gold)
            end
            sfx:Play(SoundEffect.SOUND_POWERUP1, 0.6, 0, false, 1.2)
        end)
    end
    mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, mod.OnNpcDeathCheer)

    function mod:OnPeffectCheer(player)
        local d = pdata(player)
        if (d.cheerTimer or 0) > 0 then
            d.cheerTimer = d.cheerTimer - 1
            if d.cheerTimer == 0 then mod.refreshCache(player, CacheFlag.CACHE_FIREDELAY) end
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, mod.OnPeffectCheer)

    function mod:OnCacheCheer(player, flag)
        if flag == CacheFlag.CACHE_FIREDELAY and (pdata(player).cheerTimer or 0) > 0 then
            player.MaxFireDelay = player.MaxFireDelay * Cfg.CHEER_FIRE_DELAY_MULT
        end
    end
    mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, mod.OnCacheCheer)

    -- Water Boy: drops half hearts after cleared rooms --------------------------------
    function mod:OnRoomClearWaterBoy()
        local boss = game:GetRoom():GetType() == RoomType.ROOM_BOSS
        forEachPlayer(function(player)
            for _, fam in ipairs(familiarsOf(player, Variants.WATER_BOY)) do
                local chance = Cfg.WATER_BOY_CHANCE + player.Luck * 0.02
                if boss or player:GetCollectibleRNG(Items.WATER_BOY):RandomFloat() < chance then
                    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, HeartSubType.HEART_HALF,
                        fam.Position, Vector(0, 2), fam)
                    fam:GetSprite():Play("Drop", true)
                    mod.popOn(fam, "HYDRATE!", mod.Colors.blue)
                end
            end
        end)
    end
    mod:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, mod.OnRoomClearWaterBoy)

    -- Tackling Dummy: an orbital that eats shots and draws enemies in ----------------
    function mod:OnDummyInit(fam)
        fam:AddToOrbit(DUMMY_ORBIT_LAYER)
        fam.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
        fam:GetSprite():Play("Idle", true)
    end
    mod:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, mod.OnDummyInit, Variants.DUMMY)

    function mod:OnDummyUpdate(fam)
        local player = fam.Player
        fam.OrbitDistance = EntityFamiliar.GetOrbitDistance(DUMMY_ORBIT_LAYER)
        fam.OrbitSpeed = 0.02
        fam.Velocity = fam:GetOrbitPosition(player.Position + player.Velocity) - fam.Position
        for _, e in ipairs(Isaac.FindInRadius(fam.Position, Cfg.DUMMY_TAUNT_RADIUS, EntityPartition.ENEMY)) do
            if e:IsVulnerableEnemy() and e:IsActiveEnemy(false) and not e:IsBoss() then
                e:AddVelocity((fam.Position - e.Position):Resized(Cfg.DUMMY_TAUNT_PULL))
            end
        end
        backToIdle(fam)
    end
    mod:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, mod.OnDummyUpdate, Variants.DUMMY)

    function mod:OnDummyCollision(fam, collider)
        local proj = collider:ToProjectile()
        if proj and not proj:HasProjectileFlags(ProjectileFlags.CANT_HIT_PLAYER) then
            proj:Die()
            fam:GetSprite():Play("Hit", true)
            sfx:Play(SoundEffect.SOUND_PUNCH, 0.4, 0, false, 1.3)
        end
    end
    mod:AddCallback(ModCallbacks.MC_PRE_FAMILIAR_COLLISION, mod.OnDummyCollision, Variants.DUMMY)
end
