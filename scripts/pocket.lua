-- Pocket items, batch two (Coin Toss and Timeout! live in extras.lua):
--   Audible               card: every regular enemy in the room is swapped for a football enemy
--   Fair Catch            card: every enemy shot in the air drops dead, and you're briefly safe
--   Two-Point Conversion  pill: +2 of whatever you're lowest on (coins, bombs or keys)
return function(mod)
    local game, sfx = mod.game, mod.sfx
    local Cards, Pills, Cfg = mod.Cards, mod.Pills, mod.Cfg

    -- Audible: change the play at the line ------------------------------------------------
    function mod:OnUseAudible(_, player)
        local swaps, T = mod.FoeSwaps or {}, mod.MonsterType
        local rng = player:GetCardRNG(Cards.AUDIBLE)
        local changed = 0
        for _, e in ipairs(Isaac.GetRoomEntities()) do
            local list = swaps[e.Type]
            if list and e.Variant == 0 and e:IsActiveEnemy(false) and not e:IsBoss() then
                local variant = list[rng:RandomInt(#list) + 1]
                local foe = Isaac.Spawn(T, variant, 0, e.Position, Vector.Zero, nil)
                foe:AddConfusion(EntityRef(player), Cfg.AUDIBLE_CONFUSE, false)
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, e.Position, Vector.Zero, nil)
                e:Remove()
                changed = changed + 1
            end
        end
        mod.playWhistle(0.8)
        if changed > 0 then
            game:GetHUD():ShowItemText("Audible!", changed .. " changed at the line")
            mod.popOn(player, "AUDIBLE! OMAHA!", mod.Colors.gold, 1.1)
        else
            mod.popOn(player, "NOBODY TO CHANGE", mod.Colors.grey)
        end
    end
    mod:AddCallback(ModCallbacks.MC_USE_CARD, mod.OnUseAudible, Cards.AUDIBLE)

    -- Fair Catch: wave it off -------------------------------------------------------------
    function mod:OnUseFairCatch(_, player)
        local caught = 0
        for _, e in ipairs(Isaac.GetRoomEntities()) do
            local proj = e:ToProjectile()
            if proj and not proj:HasProjectileFlags(ProjectileFlags.CANT_HIT_PLAYER) then
                proj:Remove()
                caught = caught + 1
            end
        end
        player:SetMinDamageCooldown(Cfg.FAIR_CATCH_FRAMES)
        -- with Receiver Gloves you actually catch them
        if player:HasCollectible(mod.Items.GLOVES) and caught > 0 then
            local d = mod.pdata(player)
            d.caught = math.min(Cfg.GLOVES_MAX_HELD, (d.caught or 0) + caught)
        end
        sfx:Play(SoundEffect.SOUND_HOLY, 0.6)
        game:GetHUD():ShowItemText("Fair catch!", "Nobody touches the returner")
        mod.popOn(player, "FAIR CATCH!", mod.Colors.white, 1.1)
    end
    mod:AddCallback(ModCallbacks.MC_USE_CARD, mod.OnUseFairCatch, Cards.FAIR_CATCH)

    -- Two-Point Conversion: go for two ---------------------------------------------------------
    function mod:OnUseTwoPoint(_, player)
        local have = { coins = player:GetNumCoins(), bombs = player:GetNumBombs(), keys = player:GetNumKeys() }
        local low = "coins"
        for _, k in ipairs({ "bombs", "keys" }) do if have[k] < have[low] then low = k end end
        if low == "coins" then player:AddCoins(2) elseif low == "bombs" then player:AddBombs(2) else player:AddKeys(2) end
        game:GetHUD():ShowItemText("Two-point conversion!", "+2 " .. low)
        mod.popOn(player, "IT'S GOOD! +2", mod.Colors.gold)
        mod.playSound("CHEER", 0.5)
    end
    mod:AddCallback(ModCallbacks.MC_USE_PILL, mod.OnUseTwoPoint, Pills.TWO_POINT)
end
