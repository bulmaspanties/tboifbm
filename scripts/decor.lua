-- Pro Shop, and the one field prop that's a gameplay cue (the Pylon trinket's marker).
-- Rooms are not dressed with football props: scattered lockers and yard lines in a basement
-- don't fit Isaac, so the floors stay the game's own.
return function(mod)
    local game = mod.game
    local Cfg = mod.Cfg

    local VARIANT = Isaac.GetEntityVariantByName("Gridiron Decor")
    mod.DecorVariant = VARIANT

    -- A floor marker (used by the Pylon trinket). Effects never collide with anything.
    function mod.spawnDecor(name, pos)
        if VARIANT <= 0 then return nil end
        local e = Isaac.Spawn(EntityType.ENTITY_EFFECT, VARIANT, 0, pos, Vector.Zero, nil)
        e:GetSprite():Play(name, true)
        e:AddEntityFlags(EntityFlag.FLAG_RENDER_FLOOR)
        e:GetData().GridironDecor = name
        return e
    end

    -- Pro Shop: some shops are team stores. The first time in, one item for sale becomes a
    -- Gridiron item you don't have yet, at the same price.
    local Q4 = { [mod.Items.CHAMP_RING] = true, [mod.Items.HOF_JACKET] = true, [mod.Items.GOLDEN_ARM] = true,
        [mod.Items.HAIL_MARY] = true }
    local function proShopItem(rng)
        local choices = {}
        for _, id in pairs(mod.Items) do
            if id > 0 and not Q4[id] and not mod.anyPlayerHas(id) then choices[#choices + 1] = id end
        end
        table.sort(choices)
        if #choices == 0 then return nil end
        return choices[rng:RandomInt(#choices) + 1]
    end

    function mod.isProShop(room)
        local rng = RNG()
        rng:SetSeed(math.max(1, room:GetDecorationSeed()) + 7, 35)
        return rng:RandomFloat() < Cfg.PROSHOP_CHANCE, rng
    end

    local function proShop(room)
        local yes, rng = mod.isProShop(room)
        if not yes then return end
        local key = game:GetLevel():GetStage() .. ":" .. game:GetLevel():GetCurrentRoomIndex()
        mod.RunState.proShops = mod.RunState.proShops or {}
        if mod.RunState.proShops[key] then return end
        mod.RunState.proShops[key] = true
        local item = proShopItem(rng)
        if not item then return end
        for _, e in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)) do
            local pickup = e:ToPickup()
            if pickup and pickup.Price ~= 0 then
                pickup:Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, item, true, true, false)
                game:GetHUD():ShowItemText("Pro Shop!", "Official team gear in stock")
                mod.popAt(pickup.Position + Vector(0, -40), "PRO SHOP!", mod.Colors.gold, 1.1)
                return
            end
        end
    end

    function mod:OnNewRoomProShop()
        local room = game:GetRoom()
        if room:GetType() == RoomType.ROOM_SHOP then proShop(room) end
    end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoomProShop)
end
