-- Worn gear. Every costume is a null costume managed here (not tied to the item)
-- so it can be toggled from the menu, hidden per character, and re-applied if
-- the game clears costumes (Clicker, character swaps, etc.).
return function(mod)
    local Items = mod.Items
    local pdata = mod.pdata

    local function nullCostume(name)
        return Isaac.GetCostumeIdByPath("gfx/characters/gridiron_" .. name .. ".anm2")
    end

    -- slot -> variant -> costume id. Pieces sharing a body layer come combined.
    -- Coloured pieces have one costume per uniform colour: key "jersey" is the default
    -- colour, "jersey_red" etc. are the others (see tools/make_costumes.py).
    local Costumes = {
        helmet = {},
        eyeblack = { eyeblack = nullCostume("eyeblack") },
        torso = { pads = nullCostume("torso_pads") },
        legs = { cleats = nullCostume("legs_cleats") },
    }
    local function colorSuffix(kind, color)
        return color == mod.UNIFORM_COLORS[kind][1] and "" or "_" .. color
    end
    for _, color in ipairs(mod.UNIFORM_COLORS.helmet) do
        for _, size in ipairs({ "", "_roomy", "_horns" }) do
            local key = "helmet" .. size .. colorSuffix("helmet", color)
            Costumes.helmet[key] = nullCostume(key)
        end
    end
    for _, color in ipairs(mod.UNIFORM_COLORS.jersey) do
        local sfx = colorSuffix("jersey", color)
        Costumes.torso["jersey" .. sfx] = nullCostume("torso_jersey" .. sfx)
        Costumes.torso["jerseypads" .. sfx] = nullCostume("torso_jerseypads" .. sfx)
    end
    for _, color in ipairs(mod.UNIFORM_COLORS.pants) do
        local sfx = colorSuffix("pants", color)
        Costumes.legs["pants" .. sfx] = nullCostume("legs_pants" .. sfx)
        Costumes.legs["pantscleats" .. sfx] = nullCostume("legs_pantscleats" .. sfx)
    end
    mod.Costumes = Costumes
    mod.COSTUME_SLOTS = { "helmet", "eyeblack", "torso", "legs" }

    -- Per-character hides: CharacterCostumeRules[PlayerType] = { helmet = false, ... }.
    -- Built-in rules go here; players can add their own with the `gridiron hide` command.
    -- Characters with no legs to put pants on (ghosts, and Azazel's bat body) skip the legs.
    local P = PlayerType
    mod.CharacterCostumeRules = {}
    for _, name in ipairs({ "PLAYER_THELOST", "PLAYER_THELOST_B", "PLAYER_THESOUL", "PLAYER_THESOUL_B",
        "PLAYER_AZAZEL", "PLAYER_AZAZEL_B" }) do
        if P[name] then mod.CharacterCostumeRules[P[name]] = { legs = false } end
    end

    -- Big hair (or a big head) gets the roomy helmet, a shell 2px bigger all round.
    -- Sized from the character sprites: anyone wider than Isaac's 28px head.
    mod.ROOMY_HELMET = {}
    for _, name in ipairs({ "PLAYER_MAGDALENE", "PLAYER_MAGDALENE_B", "PLAYER_EVE", "PLAYER_EVE_B",
        "PLAYER_SAMSON", "PLAYER_SAMSON_B", "PLAYER_BETHANY", "PLAYER_BETHANY_B", "PLAYER_LILITH",
        "PLAYER_LILITH_B", "PLAYER_LAZARUS", "PLAYER_LAZARUS2", "PLAYER_LAZARUS_B", "PLAYER_LAZARUS2_B",
        "PLAYER_EDEN", "PLAYER_EDEN_B", "PLAYER_JUDAS_B", "PLAYER_CAIN_B" }) do
        if P[name] then mod.ROOMY_HELMET[P[name]] = true end
    end

    -- Horns come up through reinforced holes in the shell instead of poking out from under it.
    mod.HORNED_HELMET = {}
    for _, name in ipairs({ "PLAYER_AZAZEL", "PLAYER_AZAZEL_B", "PLAYER_LILITH", "PLAYER_LILITH_B",
        "PLAYER_APOLLYON", "PLAYER_APOLLYON_B" }) do
        if P[name] then mod.HORNED_HELMET[P[name]] = true end
    end

    local function slotAllowed(player, slot)
        if not mod.Settings.costumes then return false end
        local ptype = player:GetPlayerType()
        local user = mod.Settings.charRules and mod.Settings.charRules[tostring(ptype)]
        if user and user[slot] == false then return false end
        local builtin = mod.CharacterCostumeRules[ptype]
        if builtin and builtin[slot] == false then return false end
        return true
    end

    local function desiredCostumes(player)
        local want = { helmet = "none", eyeblack = "none", torso = "none", legs = "none" }
        local S = mod.Settings
        local ptype = player:GetPlayerType()
        local fit = (mod.HORNED_HELMET[ptype] and "_horns") or (mod.ROOMY_HELMET[ptype] and "_roomy") or ""
        local helmetKey = "helmet" .. fit .. colorSuffix("helmet", S.helmetColor)
        local jerseySfx = colorSuffix("jersey", S.jerseyColor)
        local pantsSfx = colorSuffix("pants", S.pantsColor)
        if player:HasCollectible(Items.HELMET) then want.helmet = helmetKey end
        if player:HasCollectible(Items.EYE_BLACK) then want.eyeblack = "eyeblack" end

        local jersey, pads = player:HasCollectible(Items.JERSEY), player:HasCollectible(Items.PADS)
        want.torso = (jersey and pads and "jerseypads" .. jerseySfx) or (jersey and "jersey" .. jerseySfx)
            or (pads and "pads") or "none"

        local pants = player:HasCollectible(Items.PANTS)
        local cleats = player:HasCollectible(Items.CLEATS)
        want.legs = (pants and cleats and "pantscleats" .. pantsSfx) or (pants and "pants" .. pantsSfx)
            or (cleats and "cleats") or "none"

        -- a colour that isn't in the lists (old save, edited file) falls back to the default
        for slot, key in pairs(want) do
            if key ~= "none" and not Costumes[slot][key] then want[slot] = "none" end
        end

        for slot in pairs(want) do
            if not slotAllowed(player, slot) then want[slot] = "none" end
        end
        return want
    end

    local function removeAll(player)
        for _, group in pairs(Costumes) do
            for _, id in pairs(group) do player:TryRemoveNullCostume(id) end
        end
    end

    function mod.updateCostumes(player, force)
        local d = pdata(player)
        local ptype = player:GetPlayerType()
        if force or not d.costumes or d.costumeType ~= ptype then
            removeAll(player)
            d.costumes = { helmet = "none", eyeblack = "none", torso = "none", legs = "none" }
            d.costumeType = ptype
        end
        local want = desiredCostumes(player)
        for _, slot in ipairs(mod.COSTUME_SLOTS) do
            local current, key = d.costumes[slot], want[slot]
            if current ~= key then
                if current ~= "none" then player:TryRemoveNullCostume(Costumes[slot][current]) end
                if key ~= "none" then player:AddNullCostume(Costumes[slot][key]) end
                d.costumes[slot] = key
            end
        end
    end

    function mod.refreshAllCostumes()
        mod.forEachPlayer(function(p) mod.updateCostumes(p, true) end)
    end

    function mod:OnPeffectCostumes(player)
        mod.updateCostumes(player, false)
    end
    mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, mod.OnPeffectCostumes)

    -- The game sometimes rebuilds costumes; re-apply ours on every room change.
    function mod:OnNewRoomCostumes()
        mod.refreshAllCostumes()
    end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoomCostumes)

    -- Pedestal icons follow the uniform colours too (Helmet and Team Jersey).
    -- Never on a pedestal that could be hiding its item: Curse of the Blind, or the
    -- alt-floor treasure rooms whose second choice is a "?".
    local function mayBeBlind()
        local level = mod.game:GetLevel()
        if level:GetCurses() & LevelCurse.CURSE_OF_BLIND ~= 0 then return true end
        local alt = level:GetStageType() == StageType.STAGETYPE_REPENTANCE
            or level:GetStageType() == StageType.STAGETYPE_REPENTANCE_B
        return alt and mod.game:GetRoom():GetType() == RoomType.ROOM_TREASURE
    end

    local function pedestalIcon(subtype)
        local S = mod.Settings
        if subtype == Items.HELMET then
            local sfx = colorSuffix("helmet", S.helmetColor)
            return "gfx/items/collectibles/football_helmet" .. sfx .. ".png"
        elseif subtype == Items.JERSEY then
            local sfx = colorSuffix("jersey", S.jerseyColor)
            return "gfx/items/collectibles/team_jersey" .. sfx .. ".png"
        end
    end
    mod.pedestalIcon = pedestalIcon

    function mod:OnPedestalUpdate(pickup)
        local icon = pedestalIcon(pickup.SubType)
        if not icon then return end
        local d = pickup:GetData()
        if d.GridironIcon == icon or mayBeBlind() then return end
        d.GridironIcon = icon
        local s = pickup:GetSprite()
        s:ReplaceSpritesheet(1, icon)
        s:LoadGraphics()
    end
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, mod.OnPedestalUpdate, PickupVariant.PICKUP_COLLECTIBLE)
end
