-- Batch 3: Foam Finger, Super Bowl Ring, Coin Toss (card), Timeout! (pill).
-- Chin Strap and Concussion Protocol hook into gear.lua directly.
return function(mod)
    local game, sfx = mod.game, mod.sfx
    local Items, Cards, Pills, Cfg = mod.Items, mod.Cards, mod.Pills, mod.Cfg
    local pdata, forEachPlayer = mod.pdata, mod.forEachPlayer

    -- Foam Finger: "We're #1!" The toughest enemy in the room is marked ----------
    local marked          -- the marked entity
    local markedHash

    function mod.isMarked(entity)
        return markedHash ~= nil and GetPtrHash(entity) == markedHash
    end

    local function pickTarget()
        local best
        for _, e in ipairs(Isaac.GetRoomEntities()) do
            if e:IsVulnerableEnemy() and e:IsActiveEnemy(false) and not e:IsDead() then
                if not best or e.MaxHitPoints > best.MaxHitPoints then best = e end
            end
        end
        marked = best
        markedHash = best and GetPtrHash(best) or nil
        if best then mod.popOn(best, "#1", mod.Colors.gold) end
    end

    function mod:OnUpdateFinger()
        if not mod.anyPlayerHas(Items.FOAM_FINGER) then
            marked, markedHash = nil, nil
            return
        end
        if game:GetFrameCount() % 15 ~= 0 then return end
        if not marked or not marked:Exists() or marked:IsDead() then pickTarget() end
    end
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.OnUpdateFinger)

    function mod:OnEntityKillFinger(entity)
        if not mod.isMarked(entity) then return end
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_PENNY,
            entity.Position, Vector.Zero, nil)
        mod.popAt(entity.Position, "FAN FAVORITE!", mod.Colors.gold)
        marked, markedHash = nil, nil
    end
    mod:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, mod.OnEntityKillFinger)

    local font = Font()
    function mod:OnRenderFinger()
        if not marked or not marked:Exists() or mod.isReflectionPass() then return end
        if not font:IsLoaded() then font:Load("font/luaminioutlined.fnt") end
        if not font:IsLoaded() then return end
        local pos = Isaac.WorldToScreen(marked.Position)
        local bob = math.sin(game:GetFrameCount() * 0.2) * 2
        font:DrawString("#1", pos.X - 20, pos.Y - marked.Size * 2 - 24 + bob, mod.Colors.gold, 40, true)
    end
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.OnRenderFinger)

    function mod:OnNewRoomFinger()
        marked, markedHash = nil, nil
    end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoomFinger)

    -- Super Bowl Ring: every boss room cleared adds a ring -------------------------
    function mod:OnRoomClearRing()
        if game:GetRoom():GetType() ~= RoomType.ROOM_BOSS then return end
        forEachPlayer(function(player)
            if not player:HasCollectible(Items.RING) then return end
            local d = pdata(player)
            d.rings = d.rings + 1
            mod.refreshCache(player)
            mod.popOn(player, "RING #" .. d.rings .. "!", mod.Colors.gold, 1.2)
            sfx:Play(SoundEffect.SOUND_THUMBSUP)
        end)
    end
    mod:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, mod.OnRoomClearRing)

    -- Coin Toss card: heads you receive (damage), tails you defer (recharge) -----
    function mod:OnUseCoinToss(_, player)
        local heads = player:GetCardRNG(Cards.COIN_TOSS):RandomInt(2) == 0
        local d = pdata(player)
        if heads then
            d.coinHeads = true
            mod.refreshCache(player)
            game:GetHUD():ShowItemText("Heads!", "You receive: damage up for the room")
            mod.popOn(player, "HEADS!", mod.Colors.gold, 1.2)
        else
            player:FullCharge(ActiveSlot.SLOT_PRIMARY, true)
            for _, e in ipairs(Isaac.GetRoomEntities()) do
                if e:IsVulnerableEnemy() and e:IsActiveEnemy(false) then
                    e:AddSlowing(EntityRef(player), Cfg.COIN_TAILS_SLOW, 0.5, Color(0.8, 0.8, 1, 1))
                end
            end
            game:GetHUD():ShowItemText("Tails!", "You defer: active recharged, enemies slowed")
            mod.popOn(player, "TAILS!", mod.Colors.grey, 1.2)
        end
        sfx:Play(SoundEffect.SOUND_PENNYPICKUP)
    end
    mod:AddCallback(ModCallbacks.MC_USE_CARD, mod.OnUseCoinToss, Cards.COIN_TOSS)

    -- Timeout! pill: everything stops, and you catch your breath --------------------
    function mod:OnUseTimeout(_, player)
        for _, e in ipairs(Isaac.GetRoomEntities()) do
            if e:IsVulnerableEnemy() and e:IsActiveEnemy(false) then
                e:AddFreeze(EntityRef(player), Cfg.TIMEOUT_FREEZE)
            elseif e.Type == EntityType.ENTITY_PROJECTILE then
                e:Remove()
            end
        end
        player:AddHearts(1)
        mod.playWhistle(1)
        mod.popOn(player, "TIMEOUT!", mod.Colors.yellow, 1.2)
    end
    mod:AddCallback(ModCallbacks.MC_USE_PILL, mod.OnUseTimeout, Pills.TIMEOUT)
end
