-- In-game settings via Dead Sea Scrolls (public domain library, scripts/dssmenucore.lua).
-- Menu text must stay lowercase: the DSS font has no capitals.
return function(mod)
    local Cfg = mod.Cfg

    local function menuData() return mod.GetSaveData().menu end

    local MenuProvider = {}
    function MenuProvider.SaveSaveData() mod.StoreSaveData() end
    function MenuProvider.GetPaletteSetting() return menuData().MenuPalette end
    function MenuProvider.SavePaletteSetting(v) menuData().MenuPalette = v end
    function MenuProvider.GetHudOffsetSetting()
        if not REPENTANCE then return menuData().HudOffset end
        return Options.HUDOffset * 10
    end
    function MenuProvider.SaveHudOffsetSetting(v)
        if not REPENTANCE then menuData().HudOffset = v end
    end
    function MenuProvider.GetGamepadToggleSetting() return menuData().GamepadToggle end
    function MenuProvider.SaveGamepadToggleSetting(v) menuData().GamepadToggle = v end
    function MenuProvider.GetMenuKeybindSetting() return menuData().MenuKeybind end
    function MenuProvider.SaveMenuKeybindSetting(v) menuData().MenuKeybind = v end
    function MenuProvider.GetMenuHintSetting() return menuData().MenuHint end
    function MenuProvider.SaveMenuHintSetting(v) menuData().MenuHint = v end
    function MenuProvider.GetMenuBuzzerSetting() return menuData().MenuBuzzer end
    function MenuProvider.SaveMenuBuzzerSetting(v) menuData().MenuBuzzer = v end
    function MenuProvider.GetMenusNotified() return menuData().MenusNotified end
    function MenuProvider.SaveMenusNotified(v) menuData().MenusNotified = v end
    function MenuProvider.GetMenusPoppedUp() return menuData().MenusPoppedUp end
    function MenuProvider.SaveMenusPoppedUp(v) menuData().MenusPoppedUp = v end

    local dssmenucore = include("scripts.dssmenucore")
    local dssmod = dssmenucore.init("Dead Sea Scrolls (Gridiron)", MenuProvider)

    -- Button builders -----------------------------------------------------------------
    local ONOFF = { "on", "off" }

    local function toggle(label, key, tip)
        return {
            str = label, choices = ONOFF, setting = 1, variable = "Gridiron_" .. key,
            load = function() return mod.Settings[key] and 1 or 2 end,
            store = function(v)
                mod.SetSetting(key, v == 1)
                if key == "costumes" then mod.refreshAllCostumes() end
            end,
            tooltip = { strset = tip },
        }
    end

    -- Percent sliders edit a 0..1 Cfg value.
    local function percent(label, key, step, tip)
        return {
            str = label, min = 0, max = 100, increment = step, suf = "%",
            setting = math.floor(mod.Defaults[key] * 100 + 0.5), variable = "Gridiron_" .. key,
            load = function() return math.floor(Cfg[key] * 100 + 0.5) end,
            store = function(v) mod.SetSetting(key, v / 100) end,
            tooltip = { strset = tip },
        }
    end

    local function number(label, key, min, max, step, tip)
        return {
            str = label, min = min, max = max, increment = step,
            setting = mod.Defaults[key], variable = "Gridiron_" .. key,
            load = function() return Cfg[key] end,
            store = function(v) mod.SetSetting(key, v) end,
            tooltip = { strset = tip },
        }
    end

    local WINDUP_LABELS = { "0.5s", "0.75s", "1s", "1.5s", "2s" }
    local WINDUP_FRAMES = { 15, 23, 30, 45, 60 }
    local function windupIndex(frames)
        local best, bestDiff = 3, math.huge
        for i, f in ipairs(WINDUP_FRAMES) do
            if math.abs(f - frames) < bestDiff then best, bestDiff = i, math.abs(f - frames) end
        end
        return best
    end

    -- Per-character costume toggles apply to the character player 1 is playing.
    local function currentType()
        local p = Isaac.GetPlayer(0)
        return p and tostring(p:GetPlayerType()) or "0"
    end

    local function charToggle(label, slot)
        return {
            str = label, choices = { "show", "hide" }, setting = 1, variable = "Gridiron_char_" .. slot,
            load = function()
                local rules = mod.Settings.charRules[currentType()]
                return (rules and rules[slot] == false) and 2 or 1
            end,
            store = function(v)
                local all = mod.GetSaveData().settings.charRules or {}
                local key = currentType()
                all[key] = all[key] or {}
                if v == 1 then all[key][slot] = nil else all[key][slot] = false end
                if next(all[key]) == nil then all[key] = nil end
                mod.SetSetting("charRules", all)
                mod.refreshAllCostumes()
            end,
            tooltip = { strset = { "only for the", "character you're", "playing now" } },
        }
    end

    local directory = {
        main = {
            title = "gridiron",
            buttons = {
                { str = "resume game", action = "resume" },
                { str = "gameplay", dest = "gameplay" },
                { str = "visuals", dest = "visuals" },
                { str = "costume fit", dest = "character" },
                { str = "menu settings", dest = "menusettings" },
                dssmod.changelogsButton,
            },
            tooltip = dssmod.menuOpenToolTip,
        },
        gameplay = {
            title = "gameplay",
            buttons = {
                {
                    str = "tackle windup", choices = WINDUP_LABELS, setting = 3,
                    variable = "Gridiron_TACKLE_WINDUP",
                    load = function() return windupIndex(Cfg.TACKLE_WINDUP) end,
                    store = function(v) mod.SetSetting("TACKLE_WINDUP", WINDUP_FRAMES[v]) end,
                    tooltip = { strset = { "straight running", "before a tackle", "(halved when", "suited up)" } },
                },
                percent("facemask block", "FACEMASK_BLOCK_CHANCE", 10, { "chance to block", "shots from the", "front" }),
                percent("pad deflect", "PADS_DEFLECT_CHANCE", 5, { "shoulder pads", "deflect chance" }),
                percent("glove catch", "GLOVES_CATCH_CHANCE", 5, { "receiver gloves", "catch chance" }),
                percent("pants shrug off", "PANTS_IGNORE_CHANCE", 5, { "padded pants", "contact hit", "ignore chance" }),
                number("yards per down", "FIRST_DOWN_YARDS", 5, 20, 1, { "cleats: yards", "for a first down" }),
                number("kick damage", "KICK_DAMAGE", 10, 100, 10, { "kicking tee base", "damage (plus 4x", "your damage)" }),
                { str = "", fsize = 2, nosel = true },
                {
                    str = "reset to defaults",
                    func = function()
                        mod.ResetSettings()
                        mod.refreshAllCostumes()
                    end,
                    tooltip = { strset = { "reopen the menu", "to see the", "reset values" } },
                },
            },
        },
        visuals = {
            title = "visuals",
            buttons = {
                toggle("costumes", "costumes", { "show worn gear", "on your", "character" }),
                toggle("suited up glow", "suitedGlow", { "gold pulse while", "suited up" }),
                toggle("hud text", "hud", { "downs, plays and", "bucket under", "your character" }),
                toggle("popup text", "popups", { "callouts like", "tackle! and", "it's good!" }),
            },
        },
        character = {
            title = "costume fit",
            buttons = {
                { str = "hide pieces that", fsize = 1, nosel = true },
                { str = "look wrong on", fsize = 1, nosel = true },
                { str = "this character", fsize = 1, nosel = true },
                { str = "", fsize = 1, nosel = true },
                charToggle("helmet", "helmet"),
                charToggle("eye black", "eyeblack"),
                charToggle("jersey/pads", "torso"),
                charToggle("pants/cleats", "legs"),
            },
        },
        menusettings = {
            title = "menu settings",
            buttons = {
                dssmod.gamepadToggleButton,
                dssmod.menuKeybindButton,
                dssmod.paletteButton,
                dssmod.menuHintButton,
                dssmod.menuBuzzerButton,
            },
        },
    }

    local directoryKey = {
        Item = directory.main,
        Main = "main",
        Idle = false,
        MaskAlpha = 1,
        Settings = {},
        SettingsChanged = false,
        Path = {},
    }

    DeadSeaScrollsMenu.AddMenu("Gridiron", {
        Run = dssmod.runMenu,
        Open = dssmod.openMenu,
        Close = dssmod.closeMenu,
        UseSubMenu = false,
        Directory = directory,
        DirectoryKey = directoryKey,
    })
    mod.MenuDirectory = directory
end
