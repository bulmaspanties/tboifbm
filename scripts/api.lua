-- The Gridiron API: a global table other mods can use. Safe to call from your own mod's
-- callbacks once Gridiron has loaded (check `if Gridiron then ... end`).
--
--   Gridiron.Items, .Trinkets, .Cards, .Pills         ids of everything Gridiron adds
--   Gridiron.MonsterType, .MonsterVariants            the football enemies and bosses
--   Gridiron.PlayerTypes                              the Quarterback, the Kicker and their tainted versions
--
--   Gridiron.IsSuitedUp(player)      3+ wearable gear pieces (or the Hall of Fame Jacket)
--   Gridiron.IsAllPro(player)        the All-Pro transformation
--   Gridiron.IsJuiced(player)        steroids + football
--   Gridiron.GearCount(player)       wearable pieces counted toward Suited Up
--   Gridiron.UniformColor(player, "helmet" | "jersey" | "pants")
--
--   Gridiron.AddSynergyNote(itemId, text)          append a line to that item's EID description
--   Gridiron.AddFootballSwap(entityType, variant)  let a vanilla enemy type become a football enemy
--   Gridiron.SetCharacterColors(playerType, { "red", "blue", "white" })   auto uniform for a character
--   Gridiron.AddCallback(event, fn)                events: "TACKLE" (player, enemy, damage),
--       "FIELD_GOAL" (player, position), "TOUCHDOWN" (player), "SUITED_UP" (player), "ALL_PRO" (player)
return function(mod)
    -- Inputs are checked before anything reaches the game: other mods share our Lua sandbox,
    -- but a bad value (a string as an entity variant, an unknown colour) could otherwise end up
    -- in a spawn or a sprite path. Every function returns true if it did something, else false.
    -- The id tables are copies, so nothing outside can change what Gridiron itself uses.
    local function copy(t)
        local out = {}
        for k, v in pairs(t or {}) do out[k] = v end
        return out
    end
    local function isInt(v) return type(v) == "number" and v == v and math.floor(v) == v end

    local api = {
        VERSION = 1,
        Items = copy(mod.Items), Trinkets = copy(mod.Trinkets), Cards = copy(mod.Cards), Pills = copy(mod.Pills),
        MonsterType = mod.MonsterType, MonsterVariants = copy(mod.MonsterVariants), PlayerTypes = copy(mod.PlayerTypes),
    }
    -- Anything that isn't really a player (nil, a number, some other object) is turned away.
    local function asPlayer(p)
        if type(p) ~= "userdata" and type(p) ~= "table" then return nil end
        local ok, player = pcall(function() return p:ToPlayer() end)
        return ok and player or nil
    end

    function api.IsSuitedUp(player)
        local p = asPlayer(player)
        return p ~= nil and mod.isSuitedUp(p)
    end
    function api.IsAllPro(player)
        local p = asPlayer(player)
        return p ~= nil and mod.pdata(p).allPro == true
    end
    function api.IsJuiced(player)
        local p = asPlayer(player)
        return p ~= nil and mod.isJuiced(p)
    end
    function api.GearCount(player)
        local p = asPlayer(player)
        return p and mod.gearCount(p) or 0
    end
    function api.UniformColor(player, kind)
        local p = asPlayer(player)
        if not p or not mod.UNIFORM_COLORS[kind] then return nil end
        return mod.uniformColor(p, kind)
    end

    function api.AddSynergyNote(itemId, text)
        if not isInt(itemId) or itemId <= 0 or type(text) ~= "string" or text == "" then return false end
        local old = mod.SynergyNotes[itemId]
        mod.SynergyNotes[itemId] = old and (old .. "#" .. text:sub(1, 500)) or text:sub(1, 500)
        mod.RegisterEID()
        return true
    end

    -- Only regular football enemies can stand in for vanilla ones (no bosses).
    local SWAPPABLE = {}
    for key, v in pairs(mod.MonsterVariants) do
        if key ~= "LINEBACKER" and key ~= "FRANCHISE" and key ~= "MASCOT_BOSS" and v >= 0 then SWAPPABLE[v] = true end
    end
    function api.AddFootballSwap(entityType, variant)
        -- enemies only: types below 10 are players, tears, pickups and the like; 1000+ are effects
        if not isInt(entityType) or entityType < 10 or entityType >= 1000 or entityType == mod.MonsterType then
            return false
        end
        if not isInt(variant) or not SWAPPABLE[variant] then return false end
        mod.FoeSwaps[entityType] = mod.FoeSwaps[entityType] or {}
        table.insert(mod.FoeSwaps[entityType], variant)
        return true
    end

    function api.SetCharacterColors(playerType, colors)
        if not isInt(playerType) or playerType < 0 or type(colors) ~= "table" then return false end
        local kinds = { "helmet", "jersey", "pants" }
        for i, kind in ipairs(kinds) do
            local ok = false
            for _, c in ipairs(mod.UNIFORM_COLORS[kind]) do if colors[i] == c then ok = true end end
            if not ok then return false end
        end
        mod.CharacterTeamColors[playerType] = { colors[1], colors[2], colors[3] }
        mod.refreshAllCostumes()
        return true
    end

    local EVENTS = { TACKLE = true, FIELD_GOAL = true, TOUCHDOWN = true, SUITED_UP = true, ALL_PRO = true }
    function api.AddCallback(event, fn)
        if not EVENTS[event] or type(fn) ~= "function" then return false end
        mod.Listeners[event] = mod.Listeners[event] or {}
        table.insert(mod.Listeners[event], fn)
        return true
    end

    Gridiron = api
end
