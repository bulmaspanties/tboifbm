-- End Zone: paint an end zone on the floor for the room.
-- Standing in it gives bonus damage (gear.lua tracks who's inside), enemies in it
-- are slowed, and a Pigskin touchdown scored in it counts double (actives.lua).
return function(mod)
    local game, sfx = mod.game, mod.sfx
    local Items, Cfg = mod.Items, mod.Cfg

    local VARIANT = Isaac.GetEntityVariantByName("Gridiron End Zone")
    mod.EndZoneVariant = VARIANT

    local zones = {}   -- centres of the zones painted in this room

    function mod.inEndZone(pos)
        for _, z in ipairs(zones) do
            if math.abs(pos.X - z.X) <= Cfg.END_ZONE_HALF_W and math.abs(pos.Y - z.Y) <= Cfg.END_ZONE_HALF_H then
                return true
            end
        end
        return false
    end

    function mod:OnUseEndZone(_, _, player)
        local pos = game:GetRoom():GetClampedPosition(player.Position, Cfg.END_ZONE_HALF_H)
        zones[#zones + 1] = pos
        if VARIANT > 0 then
            local paint = Isaac.Spawn(EntityType.ENTITY_EFFECT, VARIANT, 0, pos, Vector.Zero, player)
            paint:AddEntityFlags(EntityFlag.FLAG_RENDER_FLOOR)   -- under everyone's feet
            paint:GetSprite():Play("Idle", true)
        end
        sfx:Play(SoundEffect.SOUND_SUMMONSOUND, 0.6, 0, false, 1.2)
        game:GetHUD():ShowItemText("End Zone!", "Damage up while you stand in it")
        mod.popAt(pos, "SIX POINTS!", mod.Colors.gold, 1.2)
        return true
    end
    mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.OnUseEndZone, Items.END_ZONE)

    -- Enemies inside the paint are bogged down.
    function mod:OnUpdateEndZone()
        if #zones == 0 then return end
        local ref = EntityRef(Isaac.GetPlayer(0))
        for _, z in ipairs(zones) do
            for _, e in ipairs(Isaac.FindInRadius(z, Cfg.END_ZONE_HALF_W + 10, EntityPartition.ENEMY)) do
                if e:IsVulnerableEnemy() and e:IsActiveEnemy(false) and mod.inEndZone(e.Position) then
                    e:AddSlowing(ref, 2, Cfg.END_ZONE_SLOW, Color(1, 0.95, 0.8, 1))
                end
            end
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.OnUpdateEndZone)

    function mod:OnNewRoomEndZone() zones = {} end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoomEndZone)
    mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.OnNewRoomEndZone)
end
