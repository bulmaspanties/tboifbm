-- The Mascot (boss): the team's giant costumed hype-man, for floors 2-6 (swapped in like the
-- Linebacker, see monsters.lua). He waddles after you, fires the T-shirt cannon, belly-flops
-- across the room, and at 75/50/25% health the costume sheds a few smaller Mascots.
return function(mod)
    local game, sfx = mod.game, mod.sfx
    local Cfg = mod.Cfg
    local TYPE, V = mod.MonsterType, mod.MonsterVariants
    local shoot, ring, toward, face = mod.monsterShoot, mod.monsterRing, mod.monsterToward, mod.monsterFace

    local SHIRT = Color(1, 1, 1, 1, 0.3, 0.3, 0.5)
    local SPLITS = { 0.75, 0.5, 0.25 }

    local function startWalk(d, s, frames)
        d.mode, d.timer = "walk", frames
        s:Play("Idle", true)
    end

    -- T-shirt cannon: two volleys of three, the second fanned wider.
    local function cannon(npc, target, wide)
        local spread = wide and 28 or 16
        for k = -1, 1 do shoot(npc, toward(npc, target, 7.5):Rotated(k * spread), 1.6, SHIRT) end
        sfx:Play(SoundEffect.SOUND_SHELLGAME, 0.9, 0, false, 0.6)
    end

    local function shedMascots(npc, d)
        local have = #Isaac.FindByType(TYPE, V.MASCOT)
        local n = math.max(0, math.min(2, Cfg.MASCOT_BOSS_MAX_MINIS - have))
        for i = 1, n do
            local off = Vector.FromAngle(math.random(360)) * 40
            local m = Isaac.Spawn(TYPE, V.MASCOT, 0, npc.Position + off, off * 0.15, npc)
            m:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
        end
        npc:GetSprite():Play("Hurt", true)
        d.mode, d.timer = "hurt", 16
        mod.popOn(npc, "SPIRIT SQUAD!", mod.Colors.gold, 1.3)
        mod.playSound("CHEER", 0.7)
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_EXPLOSION, 0, npc.Position, Vector.Zero, npc)
    end

    local function update(npc, d, target, s)
        if not d.mode then
            d.mode, d.timer, d.splits = "intro", 40, 0
            s:Play("Idle", true)
            game:GetHUD():ShowItemText("The Mascot", "Spirit squad, party of one")
            mod.playSound("HORN", 1)
        end
        d.timer = d.timer - 1

        -- Shed a few minis at each health threshold (checked between moves, never mid-air).
        local nextSplit = SPLITS[d.splits + 1]
        if nextSplit and d.mode ~= "jump" and npc.HitPoints < npc.MaxHitPoints * nextSplit then
            d.splits = d.splits + 1
            shedMascots(npc, d)
            return
        end
        local angry = d.splits >= 2

        if d.mode == "intro" or d.mode == "hurt" or d.mode == "land" then
            npc.Velocity = npc.Velocity * 0.5
            if d.timer <= 0 then startWalk(d, s, angry and 35 or 50) end

        elseif d.mode == "walk" then
            npc.Pathfinder:FindGridPath(target.Position, angry and 0.5 or 0.38, 900, true)
            npc.SpriteScale = Vector(1 + math.sin(d.timer * 0.3) * 0.04, 1)   -- the waddle
            face(npc, s, target.Position.X)
            if d.timer <= 0 then
                npc.SpriteScale = Vector.One
                if math.random() < 0.45 then
                    d.mode, d.timer, d.landAt = "jump", 26, target.Position
                    npc.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
                    s:Play("Jump", true)
                    mod.popOn(npc, "BELLY FLOP!", mod.Colors.yellow, 1.1)
                else
                    d.mode, d.timer = "shoot", 34
                    s:Play("Shoot", true)
                    mod.popOn(npc, "T-SHIRT TIME!", mod.Colors.white, 1)
                end
            end

        elseif d.mode == "shoot" then
            npc.Velocity = npc.Velocity * 0.7
            face(npc, s, target.Position.X)
            if d.timer == 24 then cannon(npc, target, false) end
            if d.timer == 12 then cannon(npc, target, true) end
            if angry and d.timer == 4 then cannon(npc, target, false) end
            if d.timer <= 0 then startWalk(d, s, angry and 45 or 60) end

        elseif d.mode == "jump" then
            local left = math.max(d.timer, 1)
            npc.Velocity = (d.landAt - npc.Position) / left
            npc.SpriteOffset = Vector(0, -math.sin((26 - d.timer) / 26 * math.pi) * 80)
            if d.timer <= 0 then
                npc.SpriteOffset = Vector.Zero
                npc.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
                game:ShakeScreen(14)
                sfx:Play(SoundEffect.SOUND_FORESTBOSS_STOMPS, 1.3)
                ring(npc, angry and 12 or 8, 6)
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF02, 1, npc.Position, Vector.Zero, npc)
                d.mode, d.timer = "land", 20
                s:Play("Land", true)
            end
        end
    end
    mod.FoeUpdaters[V.MASCOT_BOSS] = update

    function mod:OnMascotBossDeath(npc)
        if npc.Variant ~= V.MASCOT_BOSS then return end
        mod.popAt(npc.Position, "UNMASKED!", mod.Colors.gold, 1.6)
        game:ShakeScreen(16)
        mod.playSound("HORN", 0.9)
        mod.playSound("CHEER", 1)
        for i = 0, 3 do
            Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.FIREWORKS, 0,
                npc.Position + Vector.FromAngle(i * 90 + 45) * 60, Vector.Zero, nil)
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, mod.OnMascotBossDeath, TYPE)
end
