-- Feedback: short floating callouts ("TACKLE!", "IT'S GOOD!") so every item's effect
-- is readable in the middle of a fight. Toggle with the "popup text" menu setting.
return function(mod)
    local popups = {}
    local MAX_POPUPS = 16
    local LIFE = 40

    mod.Colors = {
        white  = KColor(1, 1, 1, 1),
        gold   = KColor(1, 0.85, 0.25, 1),
        green  = KColor(0.45, 1, 0.45, 1),
        blue   = KColor(0.55, 0.75, 1, 1),
        red    = KColor(1, 0.4, 0.35, 1),
        orange = KColor(1, 0.6, 0.2, 1),
        grey   = KColor(0.85, 0.85, 0.9, 1),
        yellow = KColor(1, 1, 0.3, 1),
    }

    local function add(entity, pos, text, color, scale)
        if not mod.Settings.popups then return end
        if #popups >= MAX_POPUPS then table.remove(popups, 1) end
        popups[#popups + 1] = {
            entity = entity, pos = pos, text = text,
            color = color or mod.Colors.white, scale = scale or 1, life = LIFE,
        }
    end

    -- Callout that follows an entity (player, enemy).
    function mod.popOn(entity, text, color, scale)
        add(entity, entity.Position, text, color, scale)
    end

    -- Callout fixed to a spot on the floor.
    function mod.popAt(pos, text, color, scale)
        add(nil, pos, text, color, scale)
    end

    function mod:OnUpdateFx()
        for i = #popups, 1, -1 do
            local p = popups[i]
            p.life = p.life - 1
            if p.entity then
                if p.entity:Exists() then p.pos = p.entity.Position else p.entity = nil end
            end
            if p.life <= 0 then table.remove(popups, i) end
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.OnUpdateFx)

    local font = Font()
    local function ensureFont()
        if not font:IsLoaded() then font:Load("font/luaminioutlined.fnt") end
        if not font:IsLoaded() then font:Load("font/terminus.fnt") end
        return font:IsLoaded()
    end

    function mod:OnRenderFx()
        if #popups == 0 or not ensureFont() then return end
        for _, p in ipairs(popups) do
            local screen = Isaac.WorldToScreen(p.pos)
            local rise = (LIFE - p.life) * 0.6
            local c = p.color
            local alpha = math.min(1, p.life / 12)
            font:DrawStringScaled(p.text, screen.X - 60, screen.Y - 38 - rise, p.scale, p.scale,
                KColor(c.Red, c.Green, c.Blue, alpha), 120, true)
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.OnRenderFx)

    function mod:OnNewRoomFx()
        popups = {}
    end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoomFx)

    -- Small burst of tinted puffs, used for impacts and splashes.
    function mod.burst(pos, variant, count, color, spread)
        for i = 1, count do
            local offset = Vector.FromAngle(i * 360 / count) * (spread or 12)
            local e = Isaac.Spawn(EntityType.ENTITY_EFFECT, variant, 0, pos + offset, offset * 0.15, nil)
            if color then e.Color = color end
        end
    end
end
