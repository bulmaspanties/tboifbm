-- Save data: one JSON blob holding settings, DSS menu state and the current run.
return function(mod)
    local json = require("json")
    local Cfg = mod.Cfg

    local data

    -- The save file is only ever parsed as JSON (data, never code), and nothing in it is trusted:
    -- a corrupted or hand-edited file can only set what the menu can set, within the menu's
    -- ranges. Everything else falls back to defaults.
    local SAVED_RANGES = {
        TACKLE_WINDUP = { 15, 60 }, FIRST_DOWN_YARDS = { 5, 20 }, KICK_DAMAGE = { 10, 100 },
        FACEMASK_BLOCK_CHANCE = { 0, 1 }, PADS_DEFLECT_CHANCE = { 0, 1 }, GLOVES_CATCH_CHANCE = { 0, 1 },
        PANTS_IGNORE_CHANCE = { 0, 1 }, LINEBACKER_CHANCE = { 0, 1 }, FRANCHISE_CHANCE = { 0, 1 },
        MASCOT_BOSS_CHANCE = { 0, 1 }, PROSHOP_CHANCE = { 0, 1 }, HALFTIME_CHANCE = { 0, 1 },
        FOOTBALL_ENEMY_CHANCE = { 0, 1 },
    }
    mod.SAVED_RANGES = SAVED_RANGES

    local function isTable(v) return type(v) == "table" end
    local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end

    local function sanitize(d)
        if not isTable(d.settings) then d.settings = {} end
        if not isTable(d.menu) then d.menu = {} end
        for k, v in pairs(d.menu) do                          -- DSS keeps numbers, flags and lists
            if type(v) ~= "number" and type(v) ~= "boolean" and not isTable(v) then d.menu[k] = nil end
        end
        if d.marks ~= nil and not isTable(d.marks) then d.marks = nil end
        for k, v in pairs(d.marks or {}) do
            if not isTable(v) then d.marks[k] = nil end
        end
        local rules = d.settings.charRules
        if rules ~= nil then
            if not isTable(rules) then
                d.settings.charRules = nil
            else
                for k, v in pairs(rules) do
                    if not isTable(v) then rules[k] = nil end
                end
            end
        end
        if d.run ~= nil and not isTable(d.run) then d.run = nil end
        return d
    end

    function mod.GetSaveData()
        if not data then
            data = {}
            if Isaac.HasModData(mod) then
                local ok, decoded = pcall(json.decode, Isaac.LoadModData(mod))
                if ok and isTable(decoded) then data = decoded end
            end
            sanitize(data)
        end
        return data
    end

    -- A value json can't encode would throw and lose the whole save, settings and notes
    -- included; if that ever happens, save everything but the run snapshot instead.
    function mod.StoreSaveData()
        local d = mod.GetSaveData()
        local ok, encoded = pcall(json.encode, d)
        if not ok then
            Isaac.DebugString("Gridiron: couldn't save the run snapshot: " .. tostring(encoded))
            local run = d.run
            d.run = nil
            ok, encoded = pcall(json.encode, d)
            d.run = run
            if not ok then return end
        end
        Isaac.SaveModData(mod, encoded)
    end

    -- Each of the game's three save files has its own mod data. Read it again when a run
    -- starts, so switching save files never carries one file's settings or notes into another.
    function mod.ReloadSaveData()
        data = nil
        mod.ApplySettings()
        if mod.RefreshMarkPages then mod.RefreshMarkPages() end
    end

    -- Settings ------------------------------------------------------------------------
    -- Saved settings override Cfg / Settings values with the same key.
    local function knownColor(kind, v)
        if v == "auto" then return true end
        for _, c in ipairs(mod.UNIFORM_COLORS[kind]) do if c == v then return true end end
        return false
    end

    function mod.ApplySettings()
        local saved = mod.GetSaveData().settings
        for k, default in pairs(mod.Defaults) do
            local v, range = saved[k], SAVED_RANGES[k]
            if range and finite(v) then
                Cfg[k] = math.max(range[1], math.min(range[2], v))
            else
                Cfg[k] = default                                -- not a menu setting: never from the file
            end
        end
        for k, v in pairs(saved) do
            if mod.Settings[k] ~= nil and type(v) == type(mod.Settings[k]) then
                local kind = type(k) == "string" and k:match("^(%a+)Color$")
                if not kind or (mod.UNIFORM_COLORS[kind] and knownColor(kind, v)) then
                    mod.Settings[k] = v
                end
            end
        end
        mod.Settings.charRules = isTable(saved.charRules) and saved.charRules or {}
        if mod.RegisterEID then mod.RegisterEID() end
    end

    function mod.SetSetting(key, value)
        mod.GetSaveData().settings[key] = value
        mod.ApplySettings()
    end

    function mod.ResetSettings()
        local s = mod.GetSaveData().settings
        local rules = s.charRules
        mod.GetSaveData().settings = { charRules = rules }
        for k, v in pairs(mod.SettingDefaults) do mod.Settings[k] = v end
        mod.ApplySettings()
        mod.StoreSaveData()
    end

    -- Run persistence ----------------------------------------------------------------------
    -- Lua-side player data (GetData) is lost on save & continue, so mirror it here.
    local PERSISTED = {
        "caught", "shots", "jerseyShown", "playIndex", "bucket",
        "firstDowns", "yardDist", "touchdown", "guardUsed", "hitThisRoom",
        "play", "trickShots", "rings", "coinHeads", "qbShots", "allPro", "allProShots", "fieldGoals", "shanks", "gameCoin",
        "coachStaff",
    }
    -- What each saved value may be. Counts are clamped (a huge "caught" would make the game
    -- draw that many footballs every frame); anything else is dropped.
    local BIG = 1e6
    local SCHEMA = {
        caught = { "number", 0, function() return Cfg.GLOVES_MAX_HELD end },
        shots = { "number", 0, BIG }, playIndex = { "number", 0, 3 }, bucket = { "number", 0, BIG },
        firstDowns = { "number", 0, function() return Cfg.MAX_FIRST_DOWNS end }, yardDist = { "number", 0, BIG },
        trickShots = { "number", 0, function() return Cfg.TRICK_PLAY_SHOTS end }, rings = { "number", 0, 100 },
        qbShots = { "number", 0, BIG }, allProShots = { "number", 0, BIG },
        fieldGoals = { "number", 0, function() return Cfg.KICKER_FG_MAX end }, shanks = { "number", 0, BIG },
        jerseyShown = { "boolean" }, guardUsed = { "boolean" }, hitThisRoom = { "boolean" }, coinHeads = { "boolean" },
        allPro = { "boolean" }, coachStaff = { "boolean" },
        touchdown = { "touchdown" },
        play = { "one of", { blitz = true, hailmary = true, trick = true } },
        gameCoin = { "one of", { heads = true, tails = true } },
    }

    local function clean(key, v)
        local rule = SCHEMA[key]
        if not rule or v == nil then return nil end
        local kind = rule[1]
        if kind == "number" then
            if not finite(v) then return nil end
            local hi = type(rule[3]) == "function" and rule[3]() or rule[3]
            return math.max(rule[2], math.min(hi, math.floor(v)))
        elseif kind == "boolean" then
            return type(v) == "boolean" and v or nil
        elseif kind == "touchdown" then
            if v == true or v == false or v == 1 or v == 2 then return v end
            return nil
        elseif kind == "one of" then
            return type(v) == "string" and rule[2][v] and v or nil
        end
    end

    -- Run-wide state: only the known keys, each a table of flags (or the challenge clock).
    local function cleanRunState(state)
        local out = {}
        if not isTable(state) then return out end
        for _, key in ipairs({ "proShops", "halftime", "trophies" }) do
            if isTable(state[key]) then
                out[key] = {}
                for k, v in pairs(state[key]) do
                    if type(k) == "string" and v == true then out[key][k] = true end
                end
            end
        end
        if finite(state.clock) then out.clock = math.max(-BIG, math.min(BIG, math.floor(state.clock))) end
        return out
    end

    local function snapshotRun()
        local run = { players = {}, state = mod.RunState }
        mod.forEachPlayer(function(player, i)
            local d = mod.pdata(player)
            local p = {}
            for _, key in ipairs(PERSISTED) do p[key] = d[key] end
            run.players[tostring(i)] = p
        end)
        return run
    end

    local function restoreRun(run)
        mod.RunState = cleanRunState(run.state)
        mod.forEachPlayer(function(player, i)
            local saved = isTable(run.players) and run.players[tostring(i)]
            if not isTable(saved) then return end
            local d = mod.pdata(player)
            for _, key in ipairs(PERSISTED) do
                local v = clean(key, saved[key])
                if v ~= nil then d[key] = v end
            end
            player:AddCacheFlags(CacheFlag.CACHE_ALL)
            player:EvaluateItems()
        end)
    end

    -- On continue the game may fire NEW_LEVEL before GAME_STARTED; never snapshot an
    -- empty run over the saved one before it has been restored.
    local runStarted = false

    function mod:OnGameStartedSave(isContinued)
        runStarted = true
        mod.gameExiting = false
        mod.ReloadSaveData()
        local save = mod.GetSaveData()
        if isContinued and save.run then
            restoreRun(save.run)
        else
            save.run = nil
            mod.RunState = {}
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.OnGameStartedSave)

    function mod:OnGameExitSave(shouldSave)
        runStarted = false
        mod.gameExiting = true          -- entities are being torn down: nothing may spawn now
        local save = mod.GetSaveData()
        save.run = shouldSave and snapshotRun() or nil
        mod.StoreSaveData()
    end
    mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.OnGameExitSave)

    -- Also checkpoint at the start of every floor, in case the game closes uncleanly.
    function mod:OnNewLevelSave()
        if not runStarted then return end
        mod.GetSaveData().run = snapshotRun()
        mod.StoreSaveData()
    end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.OnNewLevelSave)

    mod.ApplySettings()
end
