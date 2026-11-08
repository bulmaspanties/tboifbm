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
    local api = {
        VERSION = 1,
        Items = mod.Items, Trinkets = mod.Trinkets, Cards = mod.Cards, Pills = mod.Pills,
        MonsterType = mod.MonsterType, MonsterVariants = mod.MonsterVariants, PlayerTypes = mod.PlayerTypes,
    }
    function api.IsSuitedUp(player) return mod.isSuitedUp(player) end
    function api.IsAllPro(player) return mod.pdata(player).allPro == true end
    function api.IsJuiced(player) return mod.isJuiced(player) end
    function api.GearCount(player) return mod.gearCount(player) end
    function api.UniformColor(player, kind) return mod.uniformColor(player, kind) end

    function api.AddSynergyNote(itemId, text)
        local old = mod.SynergyNotes[itemId]
        mod.SynergyNotes[itemId] = old and (old .. "#" .. text) or text
        mod.RegisterEID()
    end
    function api.AddFootballSwap(entityType, variant)
        mod.FoeSwaps[entityType] = mod.FoeSwaps[entityType] or {}
        table.insert(mod.FoeSwaps[entityType], variant)
    end
    function api.SetCharacterColors(playerType, colors)
        mod.CharacterTeamColors[playerType] = colors
        mod.refreshAllCostumes()
    end
    function api.AddCallback(event, fn)
        mod.Listeners[event] = mod.Listeners[event] or {}
        table.insert(mod.Listeners[event], fn)
    end

    Gridiron = api
end
