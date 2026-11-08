-- Football fields, Pro Shop, and the Pylon trinket's marker.
-- Now and then a plain rectangular room has a faded football field painted on its floor: yard
-- lines with their numbers, end zone stripes at both ends and a torn patch of turf or two.
-- Paint only (no props standing in the room), and never in L-shaped or narrow rooms.
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

    -- Football fields -------------------------------------------------------------------
    local FIELD_SHAPES = {}
    for _, name in ipairs({ "ROOMSHAPE_1x1", "ROOMSHAPE_2x1" }) do
        if RoomShape and RoomShape[name] then FIELD_SHAPES[RoomShape[name]] = true end
    end
    local NUMS = { "Num10", "Num20", "Num30", "Num40", "Num50" }

    local function paintAt(room, name, pos, flip)
        if not room:IsPositionInRoom(pos, 0) then return end
        local e = mod.spawnDecor(name, pos)
        if e then e:GetSprite().FlipX = flip or false end
    end

    function mod.isFieldRoom(room)
        if not mod.Settings.fields or VARIANT <= 0 then return false end
        if room:GetType() ~= RoomType.ROOM_DEFAULT or not FIELD_SHAPES[room:GetRoomShape()] then return false end
        local rng = RNG()
        rng:SetSeed(math.max(1, room:GetDecorationSeed()), 35)
        return rng:RandomFloat() < Cfg.FIELD_CHANCE, rng
    end

    local function paintField(room, rng)
        local tl, br, c = room:GetTopLeftPos(), room:GetBottomRightPos(), room:GetCenterPos()
        for _, left in ipairs({ true, false }) do                   -- end zones at both ends
            paintAt(room, "EndStripes", Vector(left and tl.X + 52 or br.X - 52, c.Y), not left)
        end
        local span = br.X - tl.X - 220
        local lines = math.max(1, math.floor(span / 100))
        for k = 0, lines do
            local x = tl.X + 110 + span * k / lines
            paintAt(room, "Yardline", Vector(x, c.Y))
            local n = NUMS[math.min(k + 1, lines - k + 1, 5)]       -- counts up to midfield and back down
            paintAt(room, n, Vector(x, tl.Y + 34))
            paintAt(room, n, Vector(x, br.Y - 34))
        end
        local open = {}                                             -- a torn patch of turf or two
        for i = 0, room:GetGridSize() - 1 do
            local pos = room:GetGridPosition(i)
            if pos.X > tl.X + 60 and pos.X < br.X - 60 and pos.Y > tl.Y + 40 and pos.Y < br.Y - 40
                and room:GetGridCollision(i) == GridCollisionClass.COLLISION_NONE then
                open[#open + 1] = pos
            end
        end
        for _ = 1, math.min(#open, 1 + rng:RandomInt(2)) do
            paintAt(room, "TurfSmall", table.remove(open, rng:RandomInt(#open) + 1), rng:RandomInt(2) == 0)
        end
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
        if room:GetType() == RoomType.ROOM_SHOP then
            proShop(room)
            return
        end
        local yes, rng = mod.isFieldRoom(room)
        if yes then paintField(room, rng) end
    end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoomProShop)
end
