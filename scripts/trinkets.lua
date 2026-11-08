-- Trinket batch two (Turf Burn, the Flag and Concussion Protocol live in gear.lua):
--   Lucky Patch        +1 luck, +2 more while Suited Up
--   Chin Strap Buckle  tackles go live faster, and they shove bosses at full force
--   Pylon              a pylon at the far end of each fresh room; touch it before it's clear: +1 damage
--   Game Coin          flips every floor: heads +0.5 damage, tails +0.2 speed, for the floor
--   Mouth Tape         immune to fear and confusion, slightly faster tears
--   Hand Warmer        stand still a moment: your next shot is a warmed-up football, double damage
-- Golden versions / Mom's Box scale the numbers through GetTrinketMultiplier.
return function(mod)
    local game, sfx = mod.game, mod.sfx
    local Trinkets, Cfg = mod.Trinkets, mod.Cfg
    local pdata = mod.pdata

    local function mult(player, id)
        if not id or id <= 0 or not player:HasTrinket(id) then return 0 end
        return player:GetTrinketMultiplier(id)
    end

    -- Chin Strap Buckle -----------------------------------------------------------------
    function mod.buckleWindup(player)
        return mult(player, Trinkets.BUCKLE) > 0 and Cfg.BUCKLE_WINDUP or 1
    end
    function mod.bossPushMult(player)
        return mult(player, Trinkets.BUCKLE) > 0 and 1 or 0.25
    end

    -- Stats: Lucky Patch, Game Coin, Mouth Tape ----------------------------------------------
    function mod:OnCacheTrinkets(player, flag)
        local d = pdata(player)
        if flag == CacheFlag.CACHE_LUCK then
            local m = mult(player, Trinkets.LUCKY_PATCH)
            if m > 0 then
                player.Luck = player.Luck + m * (Cfg.PATCH_LUCK + (mod.isSuitedUp(player) and Cfg.PATCH_SUITED_LUCK or 0))
            end
        elseif flag == CacheFlag.CACHE_DAMAGE then
            if d.gameCoin == "heads" and mult(player, Trinkets.GAME_COIN) > 0 then
                player.Damage = player.Damage + Cfg.COIN_TRINKET_DAMAGE * mult(player, Trinkets.GAME_COIN)
            end
            if d.pylonScored then player.Damage = player.Damage + Cfg.PYLON_DAMAGE end
        elseif flag == CacheFlag.CACHE_SPEED then
            if d.gameCoin == "tails" and mult(player, Trinkets.GAME_COIN) > 0 then
                player.MoveSpeed = player.MoveSpeed + Cfg.COIN_TRINKET_SPEED * mult(player, Trinkets.GAME_COIN)
            end
        elseif flag == CacheFlag.CACHE_FIREDELAY then
            local m = mult(player, Trinkets.MOUTH_TAPE)
            if m > 0 then player.MaxFireDelay = player.MaxFireDelay * Cfg.TAPE_FIRE_DELAY_MULT ^ m end
        end
    end
    mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, mod.OnCacheTrinkets)

    local ALL_STATS = CacheFlag.CACHE_LUCK | CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SPEED | CacheFlag.CACHE_FIREDELAY

    -- Game Coin: a fresh toss every floor
    local function tossFor(player)
        local d = pdata(player)
        if mult(player, Trinkets.GAME_COIN) <= 0 then
            d.gameCoin = nil
            return
        end
        local rng = player:GetTrinketRNG(Trinkets.GAME_COIN)
        d.gameCoin = rng:RandomInt(2) == 0 and "heads" or "tails"
        mod.popOn(player, d.gameCoin == "heads" and "HEADS: DAMAGE UP" or "TAILS: SPEED UP", mod.Colors.gold)
        sfx:Play(SoundEffect.SOUND_PENNYPICKUP, 0.8)
        mod.refreshCache(player, ALL_STATS)
    end
    function mod:OnNewLevelTrinkets()
        mod.forEachPlayer(tossFor)
    end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.OnNewLevelTrinkets)

    -- Pylon: plant it at the far end of a fresh room -------------------------------------------
    function mod:OnNewRoomTrinkets()
        local room = game:GetRoom()
        mod.forEachPlayer(function(player)
            local d = pdata(player)
            if d.pylonScored then
                d.pylonScored = false
                mod.refreshCache(player, CacheFlag.CACHE_DAMAGE)
            end
            d.pylonPos, d.warmFrames = nil, 0
            if room:IsClear() or mult(player, Trinkets.PYLON) <= 0 then return end
            local best, far = nil, -1
            for i = 0, room:GetGridSize() - 1 do
                local pos = room:GetGridPosition(i)
                if room:IsPositionInRoom(pos, 0) and room:GetGridCollision(i) == GridCollisionClass.COLLISION_NONE then
                    local dist = (pos - player.Position):Length()
                    if dist > far then best, far = pos, dist end
                end
            end
            if best then
                d.pylonPos = best
                if mod.spawnDecor then mod.spawnDecor("Pylon", best) end
            end
        end)
    end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoomTrinkets)

    function mod:OnPeffectTrinkets(player)
        local d = pdata(player)
        -- Pylon: break the plane
        if d.pylonPos and (player.Position - d.pylonPos):Length() < player.Size + 16 then
            d.pylonPos = nil
            if not game:GetRoom():IsClear() then
                d.pylonScored = true
                mod.refreshCache(player, CacheFlag.CACHE_DAMAGE)
                mod.popOn(player, "PYLON! +1 DAMAGE", mod.Colors.gold)
                mod.playSound("CHEER", 0.5)
            end
        end
        -- Mouth Tape: nobody rattles you
        if mult(player, Trinkets.MOUTH_TAPE) > 0 then
            local dazed = EntityFlag.FLAG_FEAR | EntityFlag.FLAG_CONFUSION
            if player:HasEntityFlags(dazed) then player:ClearEntityFlags(dazed) end
        end
        -- Hand Warmer: stand still and your hands warm up
        if mult(player, Trinkets.HAND_WARMER) > 0 then
            if player.Velocity:Length() < 0.5 then
                d.warmFrames = (d.warmFrames or 0) + 1
                if d.warmFrames == Cfg.WARMER_FRAMES then
                    mod.popOn(player, "WARMED UP", mod.Colors.orange, 0.8)
                    player:SetColor(Color(1, 1, 1, 1, 0.4, 0.2, 0), 10, 1, true, false)
                end
            else
                d.warmFrames = 0
            end
        end
        -- Lucky Patch reads Suited Up, which can change at any time
        local suited = mod.isSuitedUp(player)
        if mult(player, Trinkets.LUCKY_PATCH) > 0 and suited ~= d.patchSuited then
            d.patchSuited = suited
            mod.refreshCache(player, CacheFlag.CACHE_LUCK)
        end
        -- picking up / dropping the Game Coin mid-floor
        local hasCoin = mult(player, Trinkets.GAME_COIN) > 0
        if hasCoin and not d.gameCoin then tossFor(player) elseif not hasCoin and d.gameCoin then
            d.gameCoin = nil
            mod.refreshCache(player, ALL_STATS)
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, mod.OnPeffectTrinkets)

    -- Hand Warmer: the warm shot
    function mod:OnFireTearWarmer(tear)
        local player = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
        if not player or mod.firingExtra then return end
        local d = pdata(player)
        local m = mult(player, Trinkets.HAND_WARMER)
        if m > 0 and (d.warmFrames or 0) >= Cfg.WARMER_FRAMES then
            d.warmFrames = 0
            if not tear:GetData().GridironFootball then mod.makeFootball(tear, 1) end
            tear.CollisionDamage = tear.CollisionDamage * Cfg.WARMER_DAMAGE * m
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, mod.OnFireTearWarmer)
end
