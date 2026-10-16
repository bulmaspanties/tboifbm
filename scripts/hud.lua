-- Feedback: Suited Up glow, held footballs, and small readouts under the player.
return function(mod)
    local game = mod.game
    local Items, Cfg = mod.Items, mod.Cfg
    local pdata = mod.pdata

    -- Suited Up: burst of sparkles when it kicks in, then a slow gold pulse.
    local GOLD_PULSE_PERIOD = 75

    function mod.OnSuitedUp(player)
        if not mod.Settings.suitedGlow then return end
        for i = 0, 5 do
            local offset = Vector.FromAngle(i * 60) * 24
            Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.ULTRA_GREED_BLING, 0,
                player.Position + offset, Vector.Zero, player)
        end
    end

    function mod:OnPeffectHud(player)
        if mod.Settings.suitedGlow and mod.isSuitedUp(player)
            and game:GetFrameCount() % GOLD_PULSE_PERIOD == 0 then
            player:SetColor(Color(1, 1, 1, 1, 0.22, 0.17, 0), 20, 1, true, false)
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, mod.OnPeffectHud)

    -- Text readouts ----------------------------------------------------------------
    local font = Font()
    local function ensureFont()
        if not font:IsLoaded() then font:Load("font/luaminioutlined.fnt") end
        if not font:IsLoaded() then font:Load("font/terminus.fnt") end
        return font:IsLoaded()
    end

    local ORDINALS = { "1st", "2nd", "3rd", "4th" }

    local function readouts(player, d)
        local lines = {}
        if player:HasCollectible(Items.CLEATS) and not game:GetRoom():IsClear() then
            local yards = math.floor(d.yardDist / Cfg.YARD_UNITS)
            local togo = Cfg.FIRST_DOWN_YARDS - yards
            if d.firstDowns >= Cfg.MAX_FIRST_DOWNS then
                lines[#lines + 1] = "Max downs!"
            else
                lines[#lines + 1] = (ORDINALS[d.firstDowns + 1] or "") .. " & " .. togo
            end
        end
        if d.play then
            local name = mod.playName(d.play) or d.play
            if d.play == "trick" then name = name .. " " .. d.trickShots end
            lines[#lines + 1] = name
        end
        if player:HasCollectible(Items.GATORADE) and d.bucket > 0 then
            lines[#lines + 1] = "Bucket " .. d.bucket .. "/" .. Cfg.GATORADE_FILLS
        end
        return lines
    end

    local heldBall
    local WHITE = KColor(1, 1, 1, 0.85)

    function mod:OnPlayerRenderHud(player, renderOffset)
        if mod.isReflectionPass() then return end
        local d = pdata(player)
        local base = Isaac.WorldToScreen(player.Position) + renderOffset

        -- Receiver Gloves: caught balls above your head.
        if d.caught > 0 then
            if not heldBall then
                heldBall = mod.newFootballSprite()
                heldBall:SetFrame("Spiral", 0)
                heldBall.Scale = Vector(0.6, 0.6)
            end
            for i = 1, d.caught do
                heldBall:Render(base + Vector((i - (d.caught + 1) / 2) * 9, -44))
            end
        end

        if not mod.Settings.hud or not ensureFont() then return end
        local y = base.Y + 6
        for _, line in ipairs(readouts(player, d)) do
            font:DrawString(line, base.X - 50, y, WHITE, 100, true)
            y = y + font:GetLineHeight()
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, mod.OnPlayerRenderHud)
end
