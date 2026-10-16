-- Worn gear. Every costume is a null costume managed here (not tied to the item)
-- so it can be toggled from the menu, hidden per character, and re-applied if
-- the game clears costumes (Clicker, character swaps, etc.).
return function(mod)
    local Items, Trinkets = mod.Items, mod.Trinkets
    local pdata = mod.pdata

    local function nullCostume(name)
        return Isaac.GetCostumeIdByPath("gfx/characters/gridiron_" .. name .. ".anm2")
    end

    -- slot -> variant -> costume id. Pieces sharing a body layer come combined.
    local Costumes = {
        helmet = { helmet = nullCostume("helmet") },
        eyeblack = { eyeblack = nullCostume("eyeblack") },
        torso = {
            jersey     = nullCostume("torso_jersey"),
            pads       = nullCostume("torso_pads"),
            jerseypads = nullCostume("torso_jerseypads"),
        },
        legs = {
            pants       = nullCostume("legs_pants"),
            cleats      = nullCostume("legs_cleats"),
            pantscleats = nullCostume("legs_pantscleats"),
        },
    }
    mod.Costumes = Costumes
    mod.COSTUME_SLOTS = { "helmet", "eyeblack", "torso", "legs" }

    -- Per-character hides: CharacterCostumeRules[PlayerType] = { helmet = false, ... }.
    -- Built-in rules go here; players can add their own with the `gridiron hide` command.
    mod.CharacterCostumeRules = {}

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
        if player:HasCollectible(Items.HELMET) then want.helmet = "helmet" end
        if player:HasCollectible(Items.EYE_BLACK) then want.eyeblack = "eyeblack" end

        local jersey, pads = player:HasCollectible(Items.JERSEY), player:HasCollectible(Items.PADS)
        want.torso = (jersey and pads and "jerseypads") or (jersey and "jersey") or (pads and "pads") or "none"

        local pants = Trinkets.PANTS > 0 and player:HasTrinket(Trinkets.PANTS)
        local cleats = player:HasCollectible(Items.CLEATS)
        want.legs = (pants and cleats and "pantscleats") or (pants and "pants") or (cleats and "cleats") or "none"

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
end
