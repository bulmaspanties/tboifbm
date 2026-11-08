-- Field decor: some rooms look like somebody played football in them. Faded yard lines and a
-- scrubbed logo on the floor, sideline junk (cups, a tipped cooler, a ball bag, a busted pylon,
-- a bloody mouthguard...), now and then a goalpost, a bench or a tackling sled, and banners in
-- the football bosses' rooms. Every prop is an effect with no collision, so nothing is ever in
-- the way. Placement is seeded per room, so a room looks the same each time you come back.
return function(mod)
    local game = mod.game
    local Cfg = mod.Cfg

    local VARIANT = Isaac.GetEntityVariantByName("Gridiron Decor")
    mod.DecorVariant = VARIANT

    local FLOOR = { Yardline = true, Hash = true, Logo = true, Cups = true, Stain = true, Tape = true,
        Clipboard = true, Mouthguard = true, Blood = true, Sideline = true, EndStripes = true,
        Num10 = true, Num20 = true, Num30 = true, Num40 = true, Num50 = true }
    local SCATTER = { "Cups", "Stain", "Cooler", "BallBag", "Pylon", "Helmet", "Tape", "Clipboard",
        "Mouthguard", "Blood", "Cups", "Stain" }
    local DENSITY = {
        light = { chance = Cfg.DECOR_CHANCE_LIGHT, props = { 1, 3 } },
        full  = { chance = Cfg.DECOR_CHANCE_FULL, props = { 3, 7 } },
    }

    local function prop(name, pos, flip)
        local e = Isaac.Spawn(EntityType.ENTITY_EFFECT, VARIANT, 0, pos, Vector.Zero, nil)
        local s = e:GetSprite()
        s:Play(name, true)
        s.FlipX = flip or false
        if FLOOR[name] then e:AddEntityFlags(EntityFlag.FLAG_RENDER_FLOOR) end
        e:GetData().GridironDecor = name
        return e
    end
    mod.spawnDecor = prop

    -- open floor tiles, away from the walls (so nothing sits in a doorway)
    local function openTiles(room)
        local tiles = {}
        local tl, br = room:GetTopLeftPos(), room:GetBottomRightPos()
        for i = 0, room:GetGridSize() - 1 do
            local pos = room:GetGridPosition(i)
            if pos.X > tl.X + 30 and pos.X < br.X - 30 and pos.Y > tl.Y + 30 and pos.Y < br.Y - 30
                and room:GetGridCollision(i) == GridCollisionClass.COLLISION_NONE then
                tiles[#tiles + 1] = pos
            end
        end
        return tiles
    end

    -- Layouts: each dressed room picks one, with random offsets, so no two look alike.
    local function midfield(room, rng)                  -- a few yard lines and maybe the logo
        local tl, br, c = room:GetTopLeftPos(), room:GetBottomRightPos(), room:GetCenterPos()
        local offset = rng:RandomFloat() * 120 - 60
        local lines = 2 + rng:RandomInt(3)
        for k = 0, lines - 1 do
            local x = c.X + offset + (k - (lines - 1) / 2) * 120
            if x > tl.X + 20 and x < br.X - 20 then
                prop("Yardline", Vector(x, c.Y + rng:RandomFloat() * 30 - 15))
                prop("Hash", Vector(x + 60, c.Y - 60))
                prop("Hash", Vector(x + 60, c.Y + 60))
            end
        end
        if br.X - tl.X > 360 and rng:RandomFloat() < 0.4 then prop("Logo", c + Vector(offset, 0)) end
    end

    local function numbers(room, rng)                   -- yard lines with their numbers painted on
        local tl, br, c = room:GetTopLeftPos(), room:GetBottomRightPos(), room:GetCenterPos()
        local start = rng:RandomInt(4)
        local nums = { "Num10", "Num20", "Num30", "Num40", "Num50" }
        local x = tl.X + 80 + rng:RandomFloat() * 60
        local i = 0
        while x < br.X - 40 do
            prop("Yardline", Vector(x, c.Y))
            local num = nums[math.min(5, start + 1 + i)]
            prop(num, Vector(x, br.Y - 40))
            prop(num, Vector(x, tl.Y + 40))
            x, i = x + 120 + rng:RandomFloat() * 20, i + 1
        end
    end

    local function sideline(room, rng)                  -- a sideline down one wall, junk piled along it
        local tl, br, c = room:GetTopLeftPos(), room:GetBottomRightPos(), room:GetCenterPos()
        local top = rng:RandomInt(2) == 0
        local y = top and tl.Y + 34 or br.Y - 34
        for x = tl.X + 75, br.X - 75, 150 do prop("Sideline", Vector(x, y)) end
        for _ = 1, 2 + rng:RandomInt(3) do
            local name = ({ "Cups", "Cooler", "Stain", "Tape", "BallBag" })[rng:RandomInt(5) + 1]
            prop(name, Vector(tl.X + 50 + rng:RandomFloat() * (br.X - tl.X - 100), y + (top and 22 or -22)),
                rng:RandomInt(2) == 0)
        end
        return c
    end

    local function endzone(room, rng)                   -- end zone stripes in a corner, a pylon on the line
        local tl, br = room:GetTopLeftPos(), room:GetBottomRightPos()
        local left, top = rng:RandomInt(2) == 0, rng:RandomInt(2) == 0
        local x, y = left and tl.X + 44 or br.X - 44, top and tl.Y + 34 or br.Y - 34
        prop("EndStripes", Vector(x, y), not left)
        prop("Pylon", Vector(x + (left and 40 or -40), y), rng:RandomInt(2) == 0)
    end

    local LAYOUTS = {   -- weight, painter (nil = sideline junk only)
        { 40, nil }, { 20, sideline }, { 15, midfield }, { 15, numbers }, { 10, endzone },
    }
    local function paint(room, rng)
        local roll, acc = rng:RandomInt(100), 0
        for _, layout in ipairs(LAYOUTS) do
            acc = acc + layout[1]
            if roll < acc then
                if layout[2] then layout[2](room, rng) end
                return
            end
        end
    end

    local function setPiece(room, rng, tiles)
        local tl, br = room:GetTopLeftPos(), room:GetBottomRightPos()
        local roll = rng:RandomInt(3)
        if roll == 0 then                                -- a goalpost in a top corner
            local left = rng:RandomInt(2) == 0
            prop("Goalpost", Vector(left and tl.X + 40 or br.X - 40, tl.Y + 70), not left)
        elseif roll == 1 then                            -- a bench along the bottom wall
            prop("Bench", Vector(tl.X + 90 + rng:RandomFloat() * (br.X - tl.X - 180), br.Y - 24))
        elseif #tiles > 0 then
            prop("Sled", tiles[rng:RandomInt(#tiles) + 1])
        end
    end

    local function decorate(room)
        local level = DENSITY[mod.Settings.decor]
        if not level then return end
        local rng = RNG()
        rng:SetSeed(math.max(1, room:GetDecorationSeed()), 35)
        if rng:RandomFloat() >= level.chance then return end
        local tiles = openTiles(room)
        paint(room, rng)
        local n = level.props[1] + rng:RandomInt(level.props[2] - level.props[1] + 1)
        for _ = 1, math.min(n, #tiles) do
            local i = rng:RandomInt(#tiles) + 1
            local pos = table.remove(tiles, i) + Vector(rng:RandomFloat() * 16 - 8, rng:RandomFloat() * 16 - 8)
            prop(SCATTER[rng:RandomInt(#SCATTER) + 1], pos, rng:RandomInt(2) == 0)
        end
        if mod.Settings.decor == "full" and rng:RandomFloat() < 0.3 then setPiece(room, rng, tiles) end
    end

    -- The football bosses' rooms get banners along the top wall.
    local function bossBanners(room)
        local V, T = mod.MonsterVariants, mod.MonsterType
        if #Isaac.FindByType(T, V.LINEBACKER) + #Isaac.FindByType(T, V.FRANCHISE) == 0 then return end
        local tl, br = room:GetTopLeftPos(), room:GetBottomRightPos()
        for x = tl.X + 80, br.X - 80, 160 do prop("Banner", Vector(x, tl.Y + 14)) end
        for _, x in ipairs({ tl.X + 40, br.X - 40 }) do prop("Goalpost", Vector(x, tl.Y + 70), x > tl.X + 40) end
    end

    function mod:OnNewRoomDecor()
        if VARIANT <= 0 or mod.Settings.decor == "off" then return end
        local room = game:GetRoom()
        local rtype = room:GetType()
        if rtype == RoomType.ROOM_DEFAULT then
            decorate(room)
        elseif rtype == RoomType.ROOM_BOSS then
            bossBanners(room)
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoomDecor)
end
