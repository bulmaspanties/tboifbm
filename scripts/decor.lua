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
        Clipboard = true, Mouthguard = true, Blood = true }
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

    local function fieldPaint(room, rng)
        local tl, br, c = room:GetTopLeftPos(), room:GetBottomRightPos(), room:GetCenterPos()
        for k = -3, 3 do
            local x = c.X + k * 120
            if x > tl.X + 20 and x < br.X - 20 then
                prop("Yardline", Vector(x, c.Y))
                for _, y in ipairs({ c.Y - 60, c.Y + 60 }) do prop("Hash", Vector(x + 60, y)) end
            end
        end
        if br.X - tl.X > 360 and rng:RandomFloat() < 0.6 then prop("Logo", c) end
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
        if rng:RandomFloat() < 0.5 then fieldPaint(room, rng) end
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
