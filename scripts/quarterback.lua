-- The Quarterback and Tainted Quarterback (playable characters).
return function(mod)
    local Items, Cfg = mod.Items, mod.Cfg

    local QB = Isaac.GetPlayerTypeByName("Quarterback", false)
    local QB_B = Isaac.GetPlayerTypeByName("Quarterback", true)
    mod.PlayerTypes = { QUARTERBACK = QB, QUARTERBACK_B = QB_B }

    -- "normal", "tainted" or nil
    function mod.quarterbackKind(player)
        local t = player:GetPlayerType()
        if QB >= 0 and t == QB then return "normal" end
        if QB_B >= 0 and t == QB_B then return "tainted" end
        return nil
    end

    local START = {
        normal  = { items = { Items.HELMET, Items.JERSEY }, pocket = Items.PLAYBOOK },
        tainted = { items = { Items.CHIN_STRAP, Items.PADS }, pocket = Items.KICKING_TEE },
    }

    function mod:OnGameStartedQuarterback(isContinued)
        if isContinued then return end
        mod.forEachPlayer(function(player)
            local kind = mod.quarterbackKind(player)
            if not kind then return end
            for _, id in ipairs(START[kind].items) do player:AddCollectible(id) end
            player:SetPocketActiveItem(START[kind].pocket, ActiveSlot.SLOT_POCKET, false)
        end)
    end
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.OnGameStartedQuarterback)

    function mod:OnCacheQuarterback(player, flag)
        local kind = mod.quarterbackKind(player)
        if not kind then return end
        if flag == CacheFlag.CACHE_SHOTSPEED then
            player.ShotSpeed = player.ShotSpeed + Cfg.QB_SHOT_SPEED
        elseif kind == "tainted" and flag == CacheFlag.CACHE_FIREDELAY then
            player.MaxFireDelay = player.MaxFireDelay * Cfg.TQB_FIRE_DELAY_MULT
        elseif kind == "tainted" and flag == CacheFlag.CACHE_DAMAGE then
            player.Damage = player.Damage + Cfg.TQB_DAMAGE
        end
    end
    mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, mod.OnCacheQuarterback)

    if EID and EID.addBirthright then
        if QB >= 0 then EID:addBirthright(QB, "Every other shot is a football") end
        if QB_B >= 0 then EID:addBirthright(QB_B, "Footballs home in on enemies") end
    end
end
