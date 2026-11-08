-- Boss themes: the Linebacker and The Franchise get their own music while they're on the field.
-- Once the room is clear we stop overriding, so the game plays its own boss-defeated jingle.
return function(mod)
    local game = mod.game
    local TRACKS = {
        { variant = "FRANCHISE", music = Isaac.GetMusicIdByName("Gridiron Franchise") },
        { variant = "LINEBACKER", music = Isaac.GetMusicIdByName("Gridiron Linebacker") },
    }

    function mod.bossTheme()
        if not mod.Settings.bossMusic then return nil end
        local room = game:GetRoom()
        if room:IsClear() then return nil end
        for _, t in ipairs(TRACKS) do
            local v = mod.MonsterVariants[t.variant]
            if t.music and t.music > 0 and v and #Isaac.FindByType(mod.MonsterType, v) > 0 then return t.music end
        end
        return nil
    end

    function mod:OnUpdateMusic()
        if game:GetFrameCount() % 10 ~= 0 then return end
        local theme = mod.bossTheme()
        if not theme then return end
        local music = MusicManager()
        if music:GetCurrentMusicID() ~= theme then
            music:Crossfade(theme, 0.08)
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.OnUpdateMusic)
end
