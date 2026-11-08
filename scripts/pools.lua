-- Content switches: keep Gridiron items (or just the Q4 legends) out of new runs.
return function(mod)
    local Items = mod.Items
    local Q4 = { [Items.CHAMP_RING] = true, [Items.HOF_JACKET] = true, [Items.GOLDEN_ARM] = true,
        [Items.HAIL_MARY] = true }

    function mod:OnGameStartedPools(isContinued)
        if isContinued then return end
        local pool = mod.game:GetItemPool()
        for _, id in pairs(Items) do
            if id > 0 and (not mod.Settings.gridironItems or (Q4[id] and not mod.Settings.q4Items)) then
                pool:RemoveCollectible(id)
            end
        end
        if not mod.Settings.gridironItems then
            for _, id in pairs(mod.Trinkets) do
                if id > 0 then pool:RemoveTrinket(id) end
            end
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.OnGameStartedPools)
end
