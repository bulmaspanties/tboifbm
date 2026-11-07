-- Halftime: sometimes clearing a room starts a halftime show. The whistle blows, the
-- horn sounds, fireworks go up, and you pick one of two rewards: a Gridiron item you don't
-- have yet, or a soul heart (an option group, so taking one makes the other vanish).
return function(mod)
    local game, sfx = mod.game, mod.sfx
    local Items, Cfg = mod.Items, mod.Cfg

    local OPTION_INDEX = 6450   -- any non-zero number shared by the two rewards

    -- A Gridiron item nobody has yet (no Q4s: those stay rare).
    local Q4 = { [Items.CHAMP_RING] = true, [Items.HOF_JACKET] = true, [Items.GOLDEN_ARM] = true,
        [Items.HAIL_MARY] = true }
    local function pickItem(rng)
        local choices = {}
        for _, id in pairs(Items) do
            if id > 0 and not Q4[id] and not mod.anyPlayerHas(id) then choices[#choices + 1] = id end
        end
        table.sort(choices)   -- pairs() order isn't stable; the seed should pick the same item
        if #choices == 0 then return nil end
        return choices[rng:RandomInt(#choices) + 1]
    end

    function mod.startHalftime(rng)
        local room = game:GetRoom()
        local center = room:GetCenterPos()
        local stage = tostring(game:GetLevel():GetStage())
        mod.RunState.halftime = mod.RunState.halftime or {}
        mod.RunState.halftime[stage] = true

        local item = pickItem(rng)
        local left = room:FindFreePickupSpawnPosition(center + Vector(-60, 0), 0, true)
        local right = room:FindFreePickupSpawnPosition(center + Vector(60, 0), 0, true)
        if item then
            local ped = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, item, left, Vector.Zero, nil)
            ped:ToPickup().OptionsPickupIndex = OPTION_INDEX
        end
        local heart = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, HeartSubType.HEART_SOUL,
            item and right or center, Vector.Zero, nil)
        heart:ToPickup().OptionsPickupIndex = OPTION_INDEX

        for i = 0, 5 do
            Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.FIREWORKS, 0,
                center + Vector.FromAngle(i * 60) * 90, Vector.Zero, nil)
        end
        mod.playWhistle(1)
        mod.playSound("HORN", 0.8)
        mod.playSound("CHEER", 0.9)
        game:GetHUD():ShowItemText("Halftime!", "Pick one: new gear or a breather")
        mod.popAt(center + Vector(0, -40), "HALFTIME SHOW!", mod.Colors.gold, 1.4)
    end

    function mod:OnRoomClearHalftime(rng)
        local room = game:GetRoom()
        if room:GetType() ~= RoomType.ROOM_DEFAULT then return end
        local stage = tostring(game:GetLevel():GetStage())
        if mod.RunState.halftime and mod.RunState.halftime[stage] then return end   -- once per floor
        if rng:RandomFloat() < Cfg.HALFTIME_CHANCE then
            mod.startHalftime(rng)
        end
    end
    mod:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, mod.OnRoomClearHalftime)
end
