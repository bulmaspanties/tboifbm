-- Debug console commands, handy for playtesting:
--   gridiron give            give every passive; drop the actives and trinkets nearby
--   gridiron hide <slot>     hide a costume piece for your current character
--   gridiron show <slot>     show it again          (slots: helmet eyeblack torso legs)
--   gridiron reset           reset all settings to defaults
return function(mod)
    local HELP = "gridiron give | hide <slot> | show <slot> | reset   (slots: helmet eyeblack torso legs)"

    local function setSlot(slot, visible)
        local valid = false
        for _, s in ipairs(mod.COSTUME_SLOTS) do if s == slot then valid = true end end
        if not valid then return "unknown slot '" .. tostring(slot) .. "'. " .. HELP end
        local ptype = tostring(Isaac.GetPlayer(0):GetPlayerType())
        local all = mod.GetSaveData().settings.charRules or {}
        all[ptype] = all[ptype] or {}
        if visible then all[ptype][slot] = nil else all[ptype][slot] = false end
        if next(all[ptype]) == nil then all[ptype] = nil end
        mod.SetSetting("charRules", all)
        mod.StoreSaveData()
        mod.refreshAllCostumes()
        return (visible and "showing " or "hiding ") .. slot .. " for this character"
    end

    function mod:OnExecuteCmd(cmd, params)
        if cmd ~= "gridiron" then return end
        local args = {}
        for word in (params or ""):gmatch("%S+") do args[#args + 1] = word:lower() end

        if args[1] == "give" then
            -- Passives go straight in; actives and trinkets drop around you so you can swap.
            local player = Isaac.GetPlayer(0)
            local room = Game():GetRoom()
            local function drop(variant, id)
                local pos = room:FindFreePickupSpawnPosition(player.Position, 40, true)
                Isaac.Spawn(EntityType.ENTITY_PICKUP, variant, id, pos, Vector.Zero, nil)
            end
            for _, id in pairs(mod.Items) do
                if id > 0 then
                    if mod.ACTIVE_ITEMS[id] then
                        drop(PickupVariant.PICKUP_COLLECTIBLE, id)
                    elseif not player:HasCollectible(id) then
                        player:AddCollectible(id)
                    end
                end
            end
            for _, id in pairs(mod.Trinkets) do
                if id > 0 then drop(PickupVariant.PICKUP_TRINKET, id) end
            end
            return "gave all Gridiron passives; actives and trinkets are on the floor"
        elseif args[1] == "hide" or args[1] == "show" then
            return setSlot(args[2], args[1] == "show")
        elseif args[1] == "reset" then
            mod.ResetSettings()
            mod.refreshAllCostumes()
            return "settings reset"
        end
        return HELP
    end
    mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, mod.OnExecuteCmd)
end
