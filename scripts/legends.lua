-- Q4 "legend" items. Their stat hooks live with the rest of the gear (gear.lua / core.lua):
--   Championship Ring    x1.25 damage, plus a trophy (extra boss item) per floor
--   Hall of Fame Jacket  counts as three gear pieces: instantly Suited Up, double bonus, fast tackles
--   Golden Arm           every shot is a golden football
--   Hail Mary            (active) a giant golden football that bursts in holy light
return function(mod)
    local game, sfx = mod.game, mod.sfx
    local Items, Cfg = mod.Items, mod.Cfg

    -- Championship Ring: beat the floor's boss, take home a trophy ----------------------
    function mod:OnRoomClearTrophy()
        local room = game:GetRoom()
        if room:GetType() ~= RoomType.ROOM_BOSS or not mod.anyPlayerHas(Items.CHAMP_RING) then return end
        local stage = game:GetLevel():GetStage()
        mod.RunState.trophies = mod.RunState.trophies or {}
        if mod.RunState.trophies[tostring(stage)] then return end
        mod.RunState.trophies[tostring(stage)] = true
        local player = Isaac.GetPlayer(0)
        local pos = room:FindFreePickupSpawnPosition(room:GetCenterPos() + Vector(0, 80), 40, true)
        -- subtype 0: the game rolls it from the room's pool, i.e. the boss pool
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, 0, pos, Vector.Zero, player)
        game:GetHUD():ShowItemText("Trophy!", "Champions get the hardware")
        mod.popAt(pos, "TROPHY!", mod.Colors.gold, 1.4)
        mod.playSound("FANFARE", 0.9)
        mod.playSound("CHEER", 0.8)
    end
    mod:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, mod.OnRoomClearTrophy)

    -- Hail Mary: heave it deep, then pray -----------------------------------------------
    local GOLD = Color(1, 0.9, 0.45, 1, 0.5, 0.4, 0.05)
    local hailMarys = {}   -- in-flight balls: { tear, player, pos }

    local function burst(entry)
        local player, pos = entry.player, entry.pos
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.CRACK_THE_SKY, 0, pos, Vector.Zero, player)
        for i = 0, Cfg.HAIL_MARY_BURST - 1 do
            mod.firingExtra = true
            local t = player:FireTear(pos, Vector.FromAngle(i * 360 / Cfg.HAIL_MARY_BURST) * 9, false, true, false, player, 2)
            mod.firingExtra = false
            if t then mod.makeFootball(t, 1) end
        end
        game:ShakeScreen(10)
        mod.popAt(pos, "ANSWERED!", mod.Colors.gold, 1.4)
        mod.playSound("CHEER", 0.9)
    end

    function mod:OnUseHailMary(_, _, player)
        local dir = mod.aimDirection(player)
        mod.firingExtra = true
        local tear = player:FireTear(player.Position, dir * Cfg.HAIL_MARY_SPEED, false, true, false, player, 1)
        mod.firingExtra = false
        if tear then
            tear.CollisionDamage = player.Damage * Cfg.HAIL_MARY_DMG_MULT + 30
            tear:AddTearFlags(TearFlags.TEAR_PIERCING | TearFlags.TEAR_SPECTRAL)
            tear.FallingAcceleration = -0.08          -- floats the length of the room
            tear.Scale = 2.6
            local ball = mod.newFootballSprite()
            ball.Color = GOLD
            tear:GetData().GridironFootball = ball
            tear:GetSprite().Color = Color(1, 1, 1, 0)
            hailMarys[#hailMarys + 1] = { tear = tear, player = player, pos = tear.Position }
        end
        game:GetHUD():ShowItemText("Hail Mary!", "Throw it up and pray")
        mod.popOn(player, "HAIL MARY!", mod.Colors.gold, 1.3)
        mod.playSound("HORN", 0.7)
        return true
    end
    mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.OnUseHailMary, Items.HAIL_MARY)

    function mod:OnUpdateHailMary()
        for i = #hailMarys, 1, -1 do
            local entry = hailMarys[i]
            if entry.tear:Exists() and not entry.tear:IsDead() then
                entry.pos = entry.tear.Position
            else
                table.remove(hailMarys, i)
                burst(entry)
            end
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.OnUpdateHailMary)

    function mod:OnNewRoomHailMary() hailMarys = {} end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoomHailMary)
end
