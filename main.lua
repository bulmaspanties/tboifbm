-- Gridiron: American football gear for The Binding of Isaac: Repentance+
-- Uses only the vanilla Lua API (REPENTOGON not required).
--
-- scripts/core.lua      item ids, tuning (Cfg), settings, shared helpers
-- scripts/fx.lua        floating callouts and effect bursts
-- scripts/gear.lua      passive items, trinkets and stats
-- scripts/actives.lua   Kicking Tee, Pigskin, Playbook, Coach's Whistle
-- scripts/costumes.lua  worn gear
-- scripts/hud.lua       Suited Up glow and on-screen readouts
-- scripts/save.lua      settings + save & continue persistence
-- scripts/eid.lua       External Item Descriptions
-- scripts/menu.lua      Dead Sea Scrolls settings menu
-- scripts/commands.lua  debug console commands (`gridiron`)
-- scripts/challenges.lua Fourth and Long, Two-Minute Drill, Ground Game
-- scripts/extras.lua    Foam Finger, Super Bowl Ring, Coin Toss card, Timeout! pill

local mod = RegisterMod("Gridiron", 1)

for _, name in ipairs({ "core", "fx", "gear", "actives", "costumes", "hud", "save", "eid", "menu", "commands", "challenges", "extras" }) do
    include("scripts." .. name)(mod)
end
