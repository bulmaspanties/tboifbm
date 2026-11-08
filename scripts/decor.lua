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
        Num10 = true, Num20 = true, Num30 = true, Num40 = true, Num50 = true,
        Drain = true, Puddle = true, Towel = true, JerseyFloor = true, Ladder = true, Turf = true, TurfSmall = true }
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

    -- keep wall props out of doorways
    local function nearDoor(room, pos)
        for slot = 0, 7 do
            local door = room:GetDoor(slot)
            if door and (door.Position - pos):Length() < 70 then return true end
        end
        return false
    end

    local function randomTile(rng, tiles)
        if #tiles == 0 then return nil end
        return table.remove(tiles, rng:RandomInt(#tiles) + 1)
    end

    -- Themed rooms: these dress the whole room and replace the random junk scatter.
    local function gamefield(room, rng, tiles)          -- a real field: goalposts at both ends
        local tl, br, c = room:GetTopLeftPos(), room:GetBottomRightPos(), room:GetCenterPos()
        for _, left in ipairs({ true, false }) do
            local x = left and tl.X + 52 or br.X - 52
            prop("EndStripes", Vector(x, c.Y), not left)
            prop("Goalpost", Vector(left and tl.X + 24 or br.X - 24, c.Y + 34), not left)
        end
        local span = br.X - tl.X - 220
        local lines = math.max(1, math.floor(span / 100))
        local nums = { "Num10", "Num20", "Num30", "Num40", "Num50" }
        for k = 0, lines do
            local x = tl.X + 110 + span * k / math.max(1, lines)
            prop("Yardline", Vector(x, c.Y))
            local n = nums[math.min(k + 1, lines - k + 1, 5)]
            if n then
                prop(n, Vector(x, tl.Y + 34))
                prop(n, Vector(x, br.Y - 34))
            end
        end
        for _ = 1, 1 + rng:RandomInt(2) do
            local t = randomTile(rng, tiles)
            if t then prop("TurfSmall", t) end
        end
        return true
    end

    local function turffield(room, rng, tiles)          -- torn turf laid over the floor
        for _ = 1, 3 + rng:RandomInt(4) do
            local t = randomTile(rng, tiles)
            if t then prop(rng:RandomInt(3) == 0 and "Turf" or "TurfSmall", t, rng:RandomInt(2) == 0) end
        end
        local c = room:GetCenterPos()
        if rng:RandomInt(2) == 0 then prop("Yardline", c + Vector(rng:RandomFloat() * 160 - 80, 0)) end
        for _ = 1, 1 + rng:RandomInt(2) do
            local t = randomTile(rng, tiles)
            if t then prop(({ "Pylon", "Cups", "Helmet", "Tape" })[rng:RandomInt(4) + 1], t) end
        end
        return true
    end

    local function lockerroom(room, rng, tiles)         -- lockers, benches, showers, a whiteboard
        local tl, br, c = room:GetTopLeftPos(), room:GetBottomRightPos(), room:GetCenterPos()
        local x = tl.X + 36
        local placedBoard = false
        while x < br.X - 30 do
            local pos = Vector(x, tl.Y + 46)
            if not nearDoor(room, pos) then
                if not placedBoard and x > c.X - 40 and rng:RandomInt(3) == 0 then
                    prop("Whiteboard", Vector(x + 12, tl.Y + 40))
                    placedBoard, x = true, x + 50
                else
                    prop(rng:RandomInt(5) == 0 and "LockerOpen" or "Locker", pos)
                    x = x + 21
                end
            else
                x = x + 30
            end
        end
        prop("Bench", Vector(c.X + rng:RandomFloat() * 120 - 60, tl.Y + 96))
        prop("Drain", c)
        for _ = 1, 2 + rng:RandomInt(2) do
            prop("Puddle", c + Vector(rng:RandomFloat() * 120 - 60, rng:RandomFloat() * 70 - 35), rng:RandomInt(2) == 0)
        end
        for _ = 1, 3 + rng:RandomInt(3) do
            local t = randomTile(rng, tiles)
            if t then
                prop(({ "Towel", "JerseyFloor", "Tape", "Helmet", "Mouthguard", "Cups" })[rng:RandomInt(6) + 1], t,
                    rng:RandomInt(2) == 0)
            end
        end
        local corner = Vector(rng:RandomInt(2) == 0 and tl.X + 30 or br.X - 30, br.Y - 30)
        if not nearDoor(room, corner) then prop("Trash", corner) end
        return true
    end

    local function practice(room, rng, tiles)           -- drills: cones, the ladder, tires
        local tl, br, c = room:GetTopLeftPos(), room:GetBottomRightPos(), room:GetCenterPos()
        local y = tl.Y + 60 + rng:RandomFloat() * (br.Y - tl.Y - 120)
        local n = 4 + rng:RandomInt(4)
        for i = 0, n - 1 do
            prop("Cone", Vector(c.X - (n - 1) * 18 + i * 36, y))
        end
        prop("Ladder", Vector(rng:RandomInt(2) == 0 and tl.X + 90 or br.X - 90, c.Y))
        local tx, ty = c.X + rng:RandomFloat() * 100 - 50, (y < c.Y) and c.Y + 50 or c.Y - 60
        for row = 0, 1 do
            for col = 0, 2 do prop("Tire", Vector(tx + col * 26 + row * 13, ty + row * 18)) end
        end
        for _, name in ipairs({ "BallBag", "Sled" }) do
            local t = randomTile(rng, tiles)
            if t and rng:RandomInt(2) == 0 then prop(name, t) end
        end
        return true
    end

    local LAYOUTS = {   -- weight, painter (nil = sideline junk only)
        { 24, nil }, { 10, sideline }, { 8, midfield }, { 8, numbers }, { 6, endzone },
        { 12, gamefield }, { 10, turffield }, { 12, lockerroom }, { 10, practice },
    }
    mod.DECOR_LAYOUTS = { sideline = sideline, midfield = midfield, numbers = numbers, endzone = endzone,
        gamefield = gamefield, turffield = turffield, lockerroom = lockerroom, practice = practice }
    local function paint(room, rng, tiles)
        local total = 0
        for _, layout in ipairs(LAYOUTS) do total = total + layout[1] end
        local roll, acc = rng:RandomInt(total), 0
        for _, layout in ipairs(LAYOUTS) do
            acc = acc + layout[1]
            if roll < acc then
                return layout[2] and layout[2](room, rng, tiles)
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
        if paint(room, rng, tiles) then return end         -- a themed room is already fully dressed
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
