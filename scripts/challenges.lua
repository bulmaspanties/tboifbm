-- Custom challenges. challenges.xml declares them; the gear and the rules live here.
return function(mod)
    local game, sfx = mod.game, mod.sfx
    local Items = mod.Items

    local CHALLENGES = {
        fourthandlong = {
            name = "Fourth and Long",
            items = { Items.HELMET, Items.PADS, Items.JERSEY, Items.GATORADE },
            intro = { "Fourth and long", "No red hearts - only Gatorade heals" },
        },
        twominute = {
            name = "Two-Minute Drill",
            items = { Items.PLAYBOOK, Items.CLEATS, Items.EYE_BLACK },
            intro = { "Two-minute drill", "Beat the clock - clears add time" },
        },
        groundgame = {
            name = "Ground Game",
            items = { Items.HELMET, Items.PADS, Items.CLEATS, Items.PANTS, Items.CHIN_STRAP, Items.KICKING_TEE },
            intro = { "Ground game", "No passing - run them over" },
        },
    }
    mod.CHALLENGES = CHALLENGES

    local idToKey = {}
    for key, c in pairs(CHALLENGES) do
        c.id = Isaac.GetChallengeIdByName(c.name)
        if c.id and c.id > 0 then idToKey[c.id] = key end
    end

    -- Which Gridiron challenge is running (nil when none).
    function mod.currentChallenge()
        return idToKey[Isaac.GetChallenge()]
    end

    local TWO_MINUTES = 2 * 60 * 30          -- update frames
    local CLEAR_BONUS = 10 * 30
    local OVERTIME_TICK = 15 * 30

    function mod:OnGameStartedChallenge(isContinued)
        local key = mod.currentChallenge()
        if not key or isContinued then return end
        local c = CHALLENGES[key]
        mod.forEachPlayer(function(player)
            for _, id in ipairs(c.items) do
                if id > 0 then player:AddCollectible(id, 99) end
            end
        end)
        mod.RunState.clock = TWO_MINUTES
        game:GetHUD():ShowItemText(c.intro[1], c.intro[2])
        mod.playWhistle(0.8)
    end
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.OnGameStartedChallenge)

    -- Fourth and Long: red hearts become pennies.
    local RED_HEARTS = {
        [HeartSubType.HEART_FULL] = true, [HeartSubType.HEART_HALF] = true,
        [HeartSubType.HEART_DOUBLEPACK] = true, [HeartSubType.HEART_SCARED] = true,
    }
    function mod:OnPickupInitChallenge(pickup)
        if mod.currentChallenge() ~= "fourthandlong" then return end
        if RED_HEARTS[pickup.SubType] then
            pickup:Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_PENNY, true, true)
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, mod.OnPickupInitChallenge, PickupVariant.PICKUP_HEART)

    -- Two-Minute Drill: a game clock per floor ------------------------------------
    function mod:OnNewLevelChallenge()
        if mod.currentChallenge() == "twominute" then
            mod.RunState.clock = TWO_MINUTES
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.OnNewLevelChallenge)

    function mod:OnUpdateChallenge()
        if mod.currentChallenge() ~= "twominute" then return end
        local clock = (mod.RunState.clock or TWO_MINUTES) - 1
        mod.RunState.clock = clock
        if clock == 0 then
            game:GetHUD():ShowItemText("Overtime!", "Every 15 seconds costs half a heart")
            mod.playWhistle(1)
        end
        if clock < 0 and (-clock) % OVERTIME_TICK == 0 then
            mod.forEachPlayer(function(player)
                player:TakeDamage(1, DamageFlag.DAMAGE_NO_PENALTIES, EntityRef(player), 30)
            end)
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.OnUpdateChallenge)

    function mod:OnRoomClearChallenge()
        if mod.currentChallenge() ~= "twominute" then return end
        mod.RunState.clock = math.max(0, mod.RunState.clock or 0) + CLEAR_BONUS
        mod.forEachPlayer(function(player)
            if player:GetActiveItem() == Items.PLAYBOOK then player:FullCharge() end
            mod.popOn(player, "+0:10", mod.Colors.green)
        end)
    end
    mod:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, mod.OnRoomClearChallenge)

    local font = Font()
    function mod:OnRenderChallenge()
        if mod.currentChallenge() ~= "twominute" then return end
        if not font:IsLoaded() then font:Load("font/terminus.fnt") end
        if not font:IsLoaded() then return end
        local clock = mod.RunState.clock or TWO_MINUTES
        local text, color
        if clock >= 0 then
            local secs = math.ceil(clock / 30)
            text = string.format("%d:%02d", secs // 60, secs % 60)
            color = clock < 20 * 30 and KColor(1, 0.4, 0.35, 1) or KColor(1, 1, 1, 1)
        else
            text = "OVERTIME"
            color = KColor(1, 0.3, 0.3, 1)
        end
        font:DrawString(text, Isaac.GetScreenWidth() / 2 - 40, 12, color, 80, true)
    end
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.OnRenderChallenge)

    -- Ground Game hooks used by gear.lua
    function mod.tackleWindupMult()
        return mod.currentChallenge() == "groundgame" and 0.5 or 1
    end
    function mod.tackleDamageMult()
        return mod.currentChallenge() == "groundgame" and 2 or 1
    end
end
