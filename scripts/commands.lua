-- Debug console commands, handy for playtesting:
--   gridiron give            drop every item as a pedestal (walk over them: they count for the collection)
--   gridiron give quick      give every passive instantly (skips the collection); drop the rest
--   gridiron spawn <name>    spawn one football enemy (mascot referee lineman blitzer punter
--                            huddle cooler chaingang sacker coach linebacker)
--   gridiron hide <slot>     hide a costume piece for your current character
--   gridiron show <slot>     show it again          (slots: helmet eyeblack torso legs)
--   gridiron reset           reset all settings to defaults
return function(mod)
    local HELP = "gridiron give [quick] | boss | enemies | spawn <name> | hide <slot> | show <slot> | reset   (slots: helmet eyeblack torso legs)"

    local function setSlot(slot, visible)
        local valid = false
        for _, s in ipairs(mod.COSTUME_SLOTS) do if s == slot then valid = true end end
        if not valid then return "unknown slot '" .. tostring(slot) .. "'. " .. HELP end
        local ptype = tostring(Isaac.GetPlayer(0):GetPlayerType())
        local all = mod.GetSaveData().settings.charRules or {}
        all[ptype] = all[ptype] or {}
        if visible then all[ptype][slot] = nil else all[ptype][slot] = false end
        if next(all[ptype]) == nil then all[ptype] = nil end
        mod.SetSetting("charRules", all)
        mod.StoreSaveData()
        mod.refreshAllCostumes()
        return (visible and "showing " or "hiding ") .. slot .. " for this character"
    end

    -- Dropping ~30 pickups in one frame with Room:FindFreePickupSpawnPosition could hang or
    -- crash the game once the floor filled up. Instead: pick open floor tiles ourselves
    -- (nearest to the player first) and drop one pickup every couple of frames.
    local drops = {}

    local function openTiles(room, from)
        local tiles = {}
        for i = 0, room:GetGridSize() - 1 do
            local pos = room:GetGridPosition(i)
            local d = (pos - from):Length()
            if d > 50 and room:IsPositionInRoom(pos, 0) and room:GetGridCollision(i) == GridCollisionClass.COLLISION_NONE then
                tiles[#tiles + 1] = { pos = pos, d = d }
            end
        end
        table.sort(tiles, function(x, y) return x.d < y.d end)
        return tiles
    end

    function mod.queueDrops(list, player)
        local tiles = openTiles(Game():GetRoom(), player.Position)
        for i, entry in ipairs(list) do
            local tile = tiles[i]
            drops[#drops + 1] = { variant = entry[1], subtype = entry[2],
                pos = tile and tile.pos or player.Position }
        end
    end

    function mod:OnUpdateDrops()
        if #drops == 0 or Game():GetFrameCount() % 2 ~= 0 then return end
        local d = table.remove(drops, 1)
        Isaac.Spawn(EntityType.ENTITY_PICKUP, d.variant, d.subtype, d.pos, Vector.Zero, nil)
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, d.pos, Vector.Zero, nil)
    end
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.OnUpdateDrops)

    -- leaving the room drops whatever was still queued: it belongs to the old room's tiles
    function mod:OnNewRoomDrops() drops = {} end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoomDrops)

    function mod:OnExecuteCmd(cmd, params)
        if cmd ~= "gridiron" then return end
        local args = {}
        for word in (params or ""):gmatch("%S+") do args[#args + 1] = word:lower() end

        if args[1] == "give" then
            -- Default: every item is a real pedestal. Picking an item up is what adds it to
            -- the collection (and the pause screen's My Stuff list); giving it directly doesn't.
            -- "quick" hands passives straight over for fast testing.
            local quick = args[2] == "quick"
            local player = Isaac.GetPlayer(0)
            local queue = {}
            for _, id in pairs(mod.Items) do
                if id > 0 then
                    if not quick or mod.ACTIVE_ITEMS[id] then
                        queue[#queue + 1] = { PickupVariant.PICKUP_COLLECTIBLE, id }
                    elseif not player:HasCollectible(id) then
                        player:AddCollectible(id)
                    end
                end
            end
            for _, id in pairs(mod.Trinkets) do
                if id > 0 then queue[#queue + 1] = { PickupVariant.PICKUP_TRINKET, id } end
            end
            if mod.Cards.COIN_TOSS > 0 then queue[#queue + 1] = { PickupVariant.PICKUP_TAROTCARD, mod.Cards.COIN_TOSS } end
            if mod.Pills.TIMEOUT >= 0 then
                queue[#queue + 1] = { PickupVariant.PICKUP_PILL, Game():GetItemPool():ForceAddPillEffect(mod.Pills.TIMEOUT) }
            end
            mod.queueDrops(queue, player)
            if quick then return "gave all Gridiron passives; actives and trinkets are dropping around you" end
            return "dropping every Gridiron item around you: walk over them to pick them up"
        elseif args[1] == "boss" or args[1] == "enemies" then
            local player = Isaac.GetPlayer(0)
            local room = Game():GetRoom()
            local V = mod.MonsterVariants
            local list = args[1] == "boss" and { V.LINEBACKER } or { V.MASCOT, V.REFEREE }
            for i, variant in ipairs(list) do
                local pos = room:FindFreePickupSpawnPosition(player.Position + Vector(0, -120 + i * 60), 0, true)
                mod.spawnMonster(variant, pos)
            end
            return args[1] == "boss" and "the Linebacker takes the field" or "spawned a Mascot and a Referee"
        elseif args[1] == "spawn" then
            local V = mod.MonsterVariants
            local names = { mascot = V.MASCOT, referee = V.REFEREE, lineman = V.LINEMAN, blitzer = V.BLITZER,
                punter = V.PUNTER, huddle = V.HUDDLE, cooler = V.COOLER, chaingang = V.CHAIN_GANG,
                sacker = V.SACKER, coach = V.COACH, linebacker = V.LINEBACKER }
            local variant = names[args[2] or ""]
            if not variant then
                return "spawn what? mascot referee lineman blitzer punter huddle cooler chaingang sacker coach linebacker"
            end
            local player = Isaac.GetPlayer(0)
            local pos = Game():GetRoom():FindFreePickupSpawnPosition(player.Position + Vector(0, -120), 0, true)
            mod.spawnMonster(variant, pos)
            return "spawned a " .. args[2]
        elseif args[1] == "hide" or args[1] == "show" then
            return setSlot(args[2], args[1] == "show")
        elseif args[1] == "reset" then
            mod.ResetSettings()
            mod.refreshAllCostumes()
            return "settings reset"
        end
        return HELP
    end
    mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, mod.OnExecuteCmd)
end
