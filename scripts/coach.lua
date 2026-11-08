-- The Coach and Tainted Coach (playable characters).
--   The Coach: a familiar build. Starts with BFFS!, the Cheerleader, the Water Boy and Coach's Whistle
--     (pocket). He doesn't hit hard himself, but his sideline crew works overtime.
--     Birthright: the Tackling Dummy joins the staff.
--   Tainted Coach: can't shoot. He fields a team: friendly Linemen sub in whenever he enters a room
--     with enemies, and his Whistle calls in more. Birthright: a bigger squad, all gold Team Captains.
return function(mod)
    local game = mod.game
    local Items, Cfg = mod.Items, mod.Cfg
    local pdata = mod.pdata
    local C = CollectibleType

    local HC = Isaac.GetPlayerTypeByName("Coach", false)
    local HC_B = Isaac.GetPlayerTypeByName("Coach", true)
    mod.PlayerTypes.COACH, mod.PlayerTypes.COACH_B = HC, HC_B

    local CAP = Isaac.GetCostumeIdByPath("gfx/characters/gridiron_coach_cap.anm2")
    local CAP_B = Isaac.GetCostumeIdByPath("gfx/characters/gridiron_coach_cap_b.anm2")

    function mod.coachKind(player)
        local t = player:GetPlayerType()
        if HC >= 0 and t == HC then return "normal" end
        if HC_B >= 0 and t == HC_B then return "tainted" end
        return nil
    end

    local START = {
        normal  = { items = { C.COLLECTIBLE_BFFS, Items.CHEERLEADER, Items.WATER_BOY } },
        tainted = { items = { Items.DUMMY } },
    }

    function mod:OnGameStartedCoach(isContinued)
        mod.forEachPlayer(function(player)
            local kind = mod.coachKind(player)
            if not kind then return end
            if not isContinued then
                for _, id in ipairs(START[kind].items) do player:AddCollectible(id) end
                player:SetPocketActiveItem(Items.WHISTLE, ActiveSlot.SLOT_POCKET, false)
            end
            mod.updateCoachLook(player)
        end)
    end
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.OnGameStartedCoach)

    function mod.updateCoachLook(player)
        local kind = mod.coachKind(player)
        if not kind or not mod.Settings.costumes then return end
        local id = kind == "tainted" and CAP_B or CAP
        if id > 0 then player:AddNullCostume(id) end
    end

    -- His staff works overtime (read by synergies' familiarBoost).
    function mod.coachFamiliarBoost(player)
        return mod.coachKind(player) == "normal" and Cfg.COACH_FAMILIAR_BOOST or 1
    end

    function mod:OnCacheCoach(player, flag)
        if mod.coachKind(player) == "normal" and flag == CacheFlag.CACHE_DAMAGE then
            player.Damage = player.Damage * Cfg.COACH_DAMAGE_MULT
        end
    end
    mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, mod.OnCacheCoach)

    function mod:OnPeffectCoach(player)
        local kind = mod.coachKind(player)
        if kind == "normal" and player:HasCollectible(C.COLLECTIBLE_BIRTHRIGHT) and not pdata(player).coachStaff then
            pdata(player).coachStaff = true                 -- Birthright: the Dummy joins the staff
            player:AddCollectible(Items.DUMMY)
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, mod.OnPeffectCoach)

    -- Tainted Coach: his team -----------------------------------------------------------------
    local function squadOf(player)
        local mine, list = GetPtrHash(player), {}
        for _, e in ipairs(Isaac.FindByType(mod.MonsterType, mod.MonsterVariants.LINEMAN)) do
            local owner = e:GetData().GridironCoach
            if owner == mine and e:Exists() and not e:IsDead() then list[#list + 1] = e end
        end
        return list
    end

    function mod.subIn(player, count)
        local cap = player:HasCollectible(C.COLLECTIBLE_BIRTHRIGHT) and Cfg.TCOACH_SQUAD_BR or Cfg.TCOACH_SQUAD
        local room = game:GetRoom()
        local spawned = 0
        for i = 1, count do
            if #squadOf(player) >= cap then break end
            local pos = room:FindFreePickupSpawnPosition(player.Position + Vector.FromAngle(i * 120) * 40, 0, true)
            local guy = Isaac.Spawn(mod.MonsterType, mod.MonsterVariants.LINEMAN, 0, pos, Vector.Zero, player)
            guy:AddCharmed(EntityRef(player), -1)        -- on his side for good
            guy:AddEntityFlags(EntityFlag.FLAG_FRIENDLY)
            guy:GetData().GridironCoach = GetPtrHash(player)
            local colour = mod.uniformColor(player, "jersey")              -- your team's kit
            for _, known in ipairs(mod.UNIFORM_COLORS.jersey) do
                if known == colour then guy:GetData().teamColor = colour end
            end
            if mod.dressFoe then mod.dressFoe(guy) end
            if player:HasCollectible(C.COLLECTIBLE_BIRTHRIGHT) and mod.makeCaptain then mod.makeCaptain(guy) end
            spawned = spawned + 1
        end
        if spawned > 0 then mod.popOn(player, "SUB IN!", mod.Colors.yellow) end
        return spawned
    end

    function mod:OnNewRoomCoach()
        local room = game:GetRoom()
        mod.forEachPlayer(function(player)
            mod.updateCoachLook(player)
            if mod.coachKind(player) == "tainted" and not room:IsClear() then
                mod.subIn(player, Cfg.TCOACH_ROOM_SUBS)
            end
        end)
    end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoomCoach)

    function mod:OnUseWhistleCoach(_, _, player)
        if mod.coachKind(player) == "tainted" then mod.subIn(player, Cfg.TCOACH_WHISTLE_SUBS) end
    end
    mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.OnUseWhistleCoach, Items.WHISTLE)

    if EID and EID.addBirthright then
        if HC >= 0 then EID:addBirthright(HC, "The Tackling Dummy joins the staff") end
        if HC_B >= 0 then EID:addBirthright(HC_B, "A bigger squad, and every sub is a gold Team Captain") end
    end
end
