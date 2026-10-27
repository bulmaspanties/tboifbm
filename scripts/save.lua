-- Save data: one JSON blob holding settings, DSS menu state and the current run.
return function(mod)
    local json = require("json")
    local Cfg = mod.Cfg

    local data

    function mod.GetSaveData()
        if not data then
            data = {}
            if Isaac.HasModData(mod) then
                local ok, decoded = pcall(json.decode, Isaac.LoadModData(mod))
                if ok and type(decoded) == "table" then data = decoded end
            end
            data.settings = data.settings or {}
            data.menu = data.menu or {}
        end
        return data
    end

    function mod.StoreSaveData()
        Isaac.SaveModData(mod, json.encode(mod.GetSaveData()))
    end

    -- Settings ------------------------------------------------------------------------
    -- Saved settings override Cfg / Settings values with the same key.
    function mod.ApplySettings()
        local saved = mod.GetSaveData().settings
        for k, default in pairs(mod.Defaults) do
            local v = saved[k]
            Cfg[k] = (type(v) == type(default)) and v or default
        end
        for k, v in pairs(saved) do
            if mod.Settings[k] ~= nil and type(v) == type(mod.Settings[k]) then
                mod.Settings[k] = v
            end
        end
        mod.Settings.charRules = saved.charRules or {}
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
        mod.Settings.costumes, mod.Settings.suitedGlow, mod.Settings.hud, mod.Settings.popups = true, true, true, true
        mod.ApplySettings()
        mod.StoreSaveData()
    end

    -- Run persistence ----------------------------------------------------------------------
    -- Lua-side player data (GetData) is lost on save & continue, so mirror it here.
    local PERSISTED = {
        "caught", "shots", "jerseyShown", "playIndex", "bucket",
        "firstDowns", "yardDist", "touchdown", "guardUsed", "hitThisRoom",
        "play", "trickShots",
    }

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
        mod.RunState = run.state or {}
        mod.forEachPlayer(function(player, i)
            local saved = run.players and run.players[tostring(i)]
            if not saved then return end
            local d = mod.pdata(player)
            for _, key in ipairs(PERSISTED) do
                if saved[key] ~= nil then d[key] = saved[key] end
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
