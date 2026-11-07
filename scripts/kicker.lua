-- The Kicker and Tainted Kicker (playable characters).
--   The Kicker: Kicking Tee in the pocket. Special Teams: a field goal refunds Tee charges and puts
--     points on the board (+damage for the floor). Birthright: every kick is good, bigger blast.
--   Tainted Kicker: shanks. His tears are slow, heavy lobs that clear rocks, and every 4th one
--     blows up like a mini field goal. Birthright: every other one does.
return function(mod)
    local game = mod.game
    local Items, Cfg = mod.Items, mod.Cfg
    local pdata = mod.pdata

    local PK = Isaac.GetPlayerTypeByName("Kicker", false)
    local PK_B = Isaac.GetPlayerTypeByName("Kicker", true)
    mod.PlayerTypes = mod.PlayerTypes or {}
    mod.PlayerTypes.KICKER, mod.PlayerTypes.KICKER_B = PK, PK_B

    local HEADBAND = Isaac.GetCostumeIdByPath("gfx/characters/gridiron_kicker_headband.anm2")
    local HEADBAND_B = Isaac.GetCostumeIdByPath("gfx/characters/gridiron_kicker_headband_b.anm2")

    -- "normal", "tainted" or nil
    function mod.kickerKind(player)
        local t = player:GetPlayerType()
        if PK >= 0 and t == PK then return "normal" end
        if PK_B >= 0 and t == PK_B then return "tainted" end
        return nil
    end

    local function hasBirthright(player)
        return player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT)
    end

    local START = {
        normal  = { items = { Items.CLEATS }, pocket = Items.KICKING_TEE },
        tainted = { items = { Items.PANTS }, pocket = Items.PIGSKIN },
    }

    function mod:OnGameStartedKicker(isContinued)
        mod.forEachPlayer(function(player)
            local kind = mod.kickerKind(player)
            if not kind then return end
            if not isContinued then
                for _, id in ipairs(START[kind].items) do player:AddCollectible(id) end
                player:SetPocketActiveItem(START[kind].pocket, ActiveSlot.SLOT_POCKET, false)
            end
            mod.updateKickerLook(player)
        end)
    end
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.OnGameStartedKicker)

    -- The headband is part of who he is (not an item), so it's kept on here.
    function mod.updateKickerLook(player)
        local kind = mod.kickerKind(player)
        if not kind or not mod.Settings.costumes then return end
        local id = kind == "tainted" and HEADBAND_B or HEADBAND
        if id > 0 then player:AddNullCostume(id) end
    end
    function mod:OnNewRoomKicker()
        mod.forEachPlayer(function(p) mod.updateKickerLook(p) end)
    end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoomKicker)

    -- Special Teams ----------------------------------------------------------------------
    function mod.kickAlwaysGood(player)
        return mod.kickerKind(player) == "normal" and hasBirthright(player)
    end

    function mod.kickerRadiusMult(player)
        return mod.kickAlwaysGood(player) and Cfg.KICKER_BR_RADIUS or 1
    end

    function mod.onFieldGoal(player)
        if mod.kickerKind(player) ~= "normal" then return end
        for _, slot in ipairs({ ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_SECONDARY, ActiveSlot.SLOT_POCKET }) do
            if player:GetActiveItem(slot) == Items.KICKING_TEE then
                local max = Isaac.GetItemConfig():GetCollectible(Items.KICKING_TEE).MaxCharges or 4
                player:SetActiveCharge(math.min(max, player:GetActiveCharge(slot) + Cfg.KICKER_REFUND), slot)
            end
        end
        local d = pdata(player)
        if (d.fieldGoals or 0) < Cfg.KICKER_FG_MAX then
            d.fieldGoals = (d.fieldGoals or 0) + 1
            mod.refreshCache(player)
            mod.popOn(player, "+3 ON THE BOARD", mod.Colors.gold)
        end
    end

    function mod:OnNewLevelKicker()
        mod.forEachPlayer(function(player)
            local d = pdata(player)
            if (d.fieldGoals or 0) > 0 then
                d.fieldGoals = 0
                mod.refreshCache(player)
            end
        end)
    end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.OnNewLevelKicker)

    function mod:OnCacheKicker(player, flag)
        local kind = mod.kickerKind(player)
        if not kind then return end
        if kind == "normal" then
            if flag == CacheFlag.CACHE_SPEED then
                player.MoveSpeed = player.MoveSpeed + Cfg.KICKER_SPEED
            elseif flag == CacheFlag.CACHE_RANGE then
                player.TearRange = player.TearRange + Cfg.KICKER_RANGE
            elseif flag == CacheFlag.CACHE_DAMAGE then
                player.Damage = player.Damage * Cfg.KICKER_DAMAGE_MULT
                    + (pdata(player).fieldGoals or 0) * Cfg.KICKER_FG_DAMAGE
            end
        else
            if flag == CacheFlag.CACHE_FIREDELAY then
                player.MaxFireDelay = player.MaxFireDelay * Cfg.TKICK_FIRE_DELAY_MULT
            elseif flag == CacheFlag.CACHE_DAMAGE then
                player.Damage = player.Damage + Cfg.TKICK_DAMAGE
            end
        end
    end
    mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, mod.OnCacheKicker)

    -- Tainted Kicker: shanks ------------------------------------------------------------------
    function mod:OnFireTearKicker(tear)
        local player = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
        if not player or mod.kickerKind(player) ~= "tainted" or mod.firingExtra then return end
        tear.FallingSpeed = -14                       -- a high, heavy lob over the rocks
        tear.FallingAcceleration = 1.1
        tear.Scale = tear.Scale * 1.25
        tear:AddTearFlags(TearFlags.TEAR_SPECTRAL)
        local d = pdata(player)
        d.shanks = (d.shanks or 0) + 1
        local every = hasBirthright(player) and 2 or Cfg.TKICK_EVERY
        if d.shanks % every == 0 then
            tear:GetData().GridironShankBoom = true
            tear.Color = Color(1, 0.7, 0.4, 1, 0.3, 0.15, 0)
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, mod.OnFireTearKicker)

    function mod:OnTearRemovedKicker(entity)
        if not entity:GetData().GridironShankBoom then return end
        local player = entity.SpawnerEntity and entity.SpawnerEntity:ToPlayer()
        if not player then return end
        mod.kickExploding = true                      -- his own shanks never hurt him
        mod.kickBlastFrame = game:GetFrameCount()
        game:BombExplosionEffects(entity.Position, player.Damage * Cfg.TKICK_BLAST_MULT, TearFlags.TEAR_NORMAL,
            Color.Default, player, 0.6, true, false, DamageFlag.DAMAGE_EXPLOSION)
        mod.kickExploding = false
    end
    mod:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, mod.OnTearRemovedKicker, EntityType.ENTITY_TEAR)

    if EID and EID.addBirthright then
        if PK >= 0 then EID:addBirthright(PK, "Every kick is good, and the blast is 50% bigger") end
        if PK_B >= 0 then EID:addBirthright(PK_B, "Every other shank explodes") end
    end
end
