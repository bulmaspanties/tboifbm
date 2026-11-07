-- Completion notes for the Gridiron characters: the vanilla marks (Mom's Heart, Isaac, Satan...)
-- tracked per character as normal or hard, announced when earned, and listed on pages in the
-- settings menu. The game has no way for mods to draw marks on the character-select paper,
-- so the menu is where they live. They don't unlock anything; they're bragging rights.
return function(mod)
    local game = mod.game

    mod.MARKS = {
        { id = "heart",     name = "mom's heart" },
        { id = "isaac",     name = "isaac" },
        { id = "satan",     name = "satan" },
        { id = "bluebaby",  name = "blue baby" },
        { id = "lamb",      name = "the lamb" },
        { id = "bossrush",  name = "boss rush" },
        { id = "hush",      name = "hush" },
        { id = "megasatan", name = "mega satan" },
        { id = "delirium",  name = "delirium" },
        { id = "mother",    name = "mother" },
        { id = "beast",     name = "the beast" },
        { id = "greed",     name = "ultra greed" },
        { id = "greedier",  name = "ultra greedier" },
    }

    -- Boss IDs from the game's entities2.xml (room:GetBossID() on the cleared boss room).
    local BOSS_ROOM_MARKS = {
        [8] = "heart", [25] = "heart", [39] = "isaac", [24] = "satan", [40] = "bluebaby",
        [54] = "lamb", [63] = "hush", [55] = "megasatan", [70] = "delirium", [88] = "mother",
    }

    -- Gridiron characters by save key.
    local function characterKey(player)
        local t, P = player:GetPlayerType(), mod.PlayerTypes or {}
        if P.QUARTERBACK and t == P.QUARTERBACK then return "qb" end
        if P.QUARTERBACK_B and t == P.QUARTERBACK_B then return "qb_b" end
        if P.KICKER and t == P.KICKER then return "kicker" end
        if P.KICKER_B and t == P.KICKER_B then return "kicker_b" end
    end
    mod.CHARACTER_PAGES = {
        { key = "qb", title = "quarterback" }, { key = "qb_b", title = "tainted qb" },
        { key = "kicker", title = "kicker" }, { key = "kicker_b", title = "tainted kicker" },
    }

    local function marks()
        local data = mod.GetSaveData()
        data.marks = data.marks or {}
        return data.marks
    end
    mod.getMarks = marks

    local function hardMode()
        local diff = game.Difficulty
        return diff == Difficulty.DIFFICULTY_HARD or diff == Difficulty.DIFFICULTY_GREEDIER
    end

    local function markName(id)
        for _, m in ipairs(mod.MARKS) do if m.id == id then return m.name end end
        return id
    end

    function mod.awardMark(id)
        local level = hardMode() and "hard" or "normal"
        mod.forEachPlayer(function(player)
            local key = characterKey(player)
            if not key then return end
            local all = marks()
            all[key] = all[key] or {}
            local had = all[key][id]
            if had == "hard" or had == level then return end      -- never downgrade a hard mark
            all[key][id] = level
            mod.StoreSaveData()
            game:GetHUD():ShowItemText("Completion note!", markName(id) .. (level == "hard" and " (hard)" or ""))
            mod.popOn(player, "NOTE: " .. markName(id):upper(), mod.Colors.gold, 1.1)
            mod.playSound("FANFARE", 0.7)
        end)
        if mod.RefreshMarkPages then mod.RefreshMarkPages() end
    end

    function mod:OnRoomClearMarks()
        local room = game:GetRoom()
        local rtype = room:GetType()
        if rtype == RoomType.ROOM_BOSSRUSH then
            mod.awardMark("bossrush")
        elseif rtype == RoomType.ROOM_BOSS then
            local mark = BOSS_ROOM_MARKS[room:GetBossID()]
            if mark then mod.awardMark(mark) end
        end
    end
    mod:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, mod.OnRoomClearMarks)

    -- The Beast and Ultra Greed end the fight without a normal room clear.
    function mod:OnNpcDeathMarks(npc)
        if npc.Type == EntityType.ENTITY_BEAST and npc.Variant == 0 then
            mod.awardMark("beast")
        elseif npc.Type == EntityType.ENTITY_ULTRA_GREED then
            mod.awardMark(game.Difficulty == Difficulty.DIFFICULTY_GREEDIER and "greedier" or "greed")
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, mod.OnNpcDeathMarks)

    -- Menu pages ------------------------------------------------------------------------
    function mod.RefreshMarkPages()
        local dir = mod.MenuDirectory
        if not dir then return end
        local all = marks()
        for _, page in ipairs(mod.CHARACTER_PAGES) do
            local got, buttons = 0, {}
            for _, m in ipairs(mod.MARKS) do
                local v = all[page.key] and all[page.key][m.id]
                if v then got = got + 1 end
                buttons[#buttons + 1] = { str = m.name .. ": " .. (v == "hard" and "hard" or v and "done" or "-"),
                    fsize = 1, nosel = true }
            end
            table.insert(buttons, 1, { str = got .. "/" .. #mod.MARKS .. " notes", fsize = 2, nosel = true })
            dir["marks_" .. page.key] = { title = page.title, buttons = buttons }
        end
    end
    mod.RefreshMarkPages()
end
