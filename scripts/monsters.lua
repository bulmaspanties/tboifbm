-- Enemies and boss: Mascot, Referee, and The Linebacker.
-- They enter the game by replacing some room-layout spawns as rooms load.
return function(mod)
    local game, sfx = mod.game, mod.sfx
    local Cfg = mod.Cfg

    local TYPE = Isaac.GetEntityTypeByName("Gridiron Linebacker")
    local V = {
        LINEBACKER = Isaac.GetEntityVariantByName("Gridiron Linebacker"),
        MASCOT     = Isaac.GetEntityVariantByName("Gridiron Mascot"),
        REFEREE    = Isaac.GetEntityVariantByName("Gridiron Referee"),
    }
    mod.MonsterType, mod.MonsterVariants = TYPE, V

    local SHIRT = Color(1, 1, 1, 1, 0.3, 0.3, 0.5)
    local FLAG = Color(1, 1, 0.2, 1, 0.5, 0.45, 0)

    local function shoot(npc, vel, scale, color)
        local p = Isaac.Spawn(EntityType.ENTITY_PROJECTILE, ProjectileVariant.PROJECTILE_NORMAL, 0,
            npc.Position, vel, npc):ToProjectile()
        p.Scale = scale or 1
        if color then p.Color = color end
        return p
    end

    local function ring(npc, count, speed)
        for i = 0, count - 1 do
            shoot(npc, Vector.FromAngle(i * 360 / count) * speed, 1)
        end
    end

    local function toward(npc, target, speed)
        local v = target.Position - npc.Position
        if v:Length() < 1 then v = Vector(1, 0) end
        return v:Resized(speed)
    end

    local function face(npc, sprite, x)
        sprite.FlipX = x < npc.Position.X
    end

    -- Mascot: waddles at you, fires a big slow t-shirt --------------------------------
    local function updateMascot(npc, d, target, s)
        if not d.mode then d.mode, d.timer = "walk", 50 + math.random(40); s:Play("Walk", true) end
        d.timer = d.timer - 1
        if d.mode == "walk" then
            npc.Pathfinder:FindGridPath(target.Position, 0.45, 900, true)
            if d.timer <= 0 and (target.Position - npc.Position):Length() < 320 then
                d.mode, d.timer = "shoot", 18
                s:Play("Shoot", true)
            end
        else
            npc.Velocity = npc.Velocity * 0.8
            if d.timer == 12 then
                shoot(npc, toward(npc, target, 6), 1.8, SHIRT)
                sfx:Play(SoundEffect.SOUND_SHELLGAME, 0.7, 0, false, 0.7)
            end
            if d.timer <= 0 then
                d.mode, d.timer = "walk", 80 + math.random(30)
                s:Play("Walk", true)
            end
        end
        face(npc, s, target.Position.X)
    end

    -- Referee: keeps his distance and throws flags -----------------------------------
    local function updateReferee(npc, d, target, s)
        if not d.mode then d.mode, d.timer = "walk", 60 + math.random(40); s:Play("Walk", true) end
        d.timer = d.timer - 1
        local dist = (target.Position - npc.Position):Length()
        if d.mode == "walk" then
            if dist < 150 then
                npc.Pathfinder:EvadeTarget(target.Position)
            elseif dist > 240 then
                npc.Pathfinder:FindGridPath(target.Position, 0.35, 900, true)
            else
                npc.Velocity = npc.Velocity * 0.85
            end
            if d.timer <= 0 then
                d.mode, d.timer = "throw", 18
                s:Play("Throw", true)
                mod.playWhistle(0.5)
            end
        else
            npc.Velocity = npc.Velocity * 0.8
            if d.timer == 8 then
                shoot(npc, toward(npc, target, 8), 1.4, FLAG)
                mod.popOn(npc, "FLAG!", mod.Colors.yellow, 0.8)
            end
            if d.timer <= 0 then
                d.mode, d.timer = "walk", 100 + math.random(40)
                s:Play("Walk", true)
            end
        end
        face(npc, s, target.Position.X)
    end

    -- The Linebacker (boss) -------------------------------------------------------------
    local function startWalk(d, s, frames)
        d.mode, d.timer = "walk", frames
        s:Play("Walk", true)
    end

    local function throwFootball(npc, target)
        local p = shoot(npc, toward(npc, target, 7), 1.8, Color(0.55, 0.3, 0.15, 1))
        p.FallingSpeed = -14
        p.FallingAccel = 0.9
        p:AddProjectileFlags(ProjectileFlags.BURST)
        p:GetData().GridironFootball = mod.newFootballSprite()
        p:GetSprite().Color = Color(1, 1, 1, 0)
    end

    local function updateLinebacker(npc, d, target, s)
        local hurt = npc.HitPoints < npc.MaxHitPoints * 0.5
        if hurt and not d.enraged then
            d.enraged = true
            mod.popOn(npc, "BLITZ!", mod.Colors.red, 1.4)
            sfx:Play(SoundEffect.SOUND_BOSS_LITE_SLOPPY_ROAR, 1, 0, false, 0.8)
        end
        if not d.mode then
            d.mode, d.timer = "intro", 30
            s:Play("Idle", true)
        end
        d.timer = d.timer - 1

        if d.mode == "intro" then
            npc.Velocity = npc.Velocity * 0.5
            if d.timer <= 0 then startWalk(d, s, 40) end

        elseif d.mode == "walk" then
            npc.Pathfinder:FindGridPath(target.Position, d.enraged and 0.75 or 0.55, 900, true)
            face(npc, s, target.Position.X)
            if d.timer <= 0 then
                local r = math.random()
                if d.enraged and r < 0.3 then
                    d.mode, d.timer, d.landAt = "jump", 20, target.Position
                    npc.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
                    s:Play("Jump", true)
                elseif r < 0.65 then
                    d.mode, d.timer = "windup", d.enraged and 16 or 25
                    s:Play("Windup", true)
                else
                    d.mode, d.timer = "throw", 21
                    s:Play("Throw", true)
                end
            end

        elseif d.mode == "windup" then
            npc.Velocity = npc.Velocity * 0.6
            face(npc, s, target.Position.X)
            if d.timer % 4 == 0 then npc:SetColor(Color(1, 1, 1, 1, 0.6, 0.15, 0.15), 2, 1, false, false) end
            if d.timer <= 0 then
                d.dir = toward(npc, target, 1)
                d.mode, d.timer = "charge", 45
                s:Play("Charge", true)
                sfx:Play(SoundEffect.SOUND_BOSS_LITE_SLOPPY_ROAR, 0.8)
            end

        elseif d.mode == "charge" then
            npc.Velocity = d.dir * (d.enraged and 14 or 12)
            face(npc, s, npc.Position.X + d.dir.X)
            if npc:CollidesWithGrid() and d.timer < 41 then
                game:ShakeScreen(12)
                sfx:Play(SoundEffect.SOUND_FORESTBOSS_STOMPS, 1.2)
                ring(npc, 6, 6)
                mod.popOn(npc, "OOF", mod.Colors.white)
                d.mode, d.timer = "stunned", d.enraged and 35 or 50
                s:Play("Stunned", true)
            elseif d.timer <= 0 then
                startWalk(d, s, 50)
            end

        elseif d.mode == "stunned" then
            npc.Velocity = npc.Velocity * 0.7
            if d.timer <= 0 then startWalk(d, s, 40) end

        elseif d.mode == "throw" then
            npc.Velocity = npc.Velocity * 0.7
            face(npc, s, target.Position.X)
            if d.timer == 11 then throwFootball(npc, target) end
            if d.timer <= 0 then startWalk(d, s, 60) end

        elseif d.mode == "jump" then
            local left = math.max(d.timer, 1)
            npc.Velocity = (d.landAt - npc.Position) / left
            npc.SpriteOffset = Vector(0, -math.sin((20 - d.timer) / 20 * math.pi) * 60)
            if d.timer <= 0 then
                npc.SpriteOffset = Vector.Zero
                npc.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
                game:ShakeScreen(14)
                sfx:Play(SoundEffect.SOUND_FORESTBOSS_STOMPS, 1.4)
                ring(npc, 10, 7)
                mod.popOn(npc, "PILE-UP!", mod.Colors.red)
                d.mode, d.timer = "land", 14
                s:Play("Land", true)
            end

        elseif d.mode == "land" then
            npc.Velocity = Vector.Zero
            if d.timer <= 0 then startWalk(d, s, 40) end
        end
    end

    function mod:OnNpcUpdateGridiron(npc)
        local target = npc:GetPlayerTarget()
        if not target then return end
        local d, s = npc:GetData(), npc:GetSprite()
        if npc.Variant == V.LINEBACKER then
            updateLinebacker(npc, d, target, s)
        elseif npc.Variant == V.MASCOT then
            updateMascot(npc, d, target, s)
        elseif npc.Variant == V.REFEREE then
            updateReferee(npc, d, target, s)
        end
    end
    mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, mod.OnNpcUpdateGridiron, TYPE)

    function mod:OnNpcDeathGridiron(npc)
        if npc.Variant == V.LINEBACKER then
            mod.popAt(npc.Position, "SACKED!", mod.Colors.gold, 1.5)
            game:ShakeScreen(16)
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, mod.OnNpcDeathGridiron, TYPE)

    -- Thrown footballs from the boss: draw the spiral sprite --------------------------
    function mod:OnProjectileUpdateFootball(proj)
        local ball = proj:GetData().GridironFootball
        if not ball then return end
        proj:GetSprite().Color = Color(1, 1, 1, 0)
        ball:Update()
        if proj.Velocity:Length() > 0.1 then ball.Rotation = proj.Velocity:GetAngleDegrees() end
    end
    mod:AddCallback(ModCallbacks.MC_POST_PROJECTILE_UPDATE, mod.OnProjectileUpdateFootball)

    function mod:OnProjectileRenderFootball(proj, offset)
        local ball = proj:GetData().GridironFootball
        if not ball or mod.isReflectionPass() then return end
        ball.Scale = Vector(1.5, 1.5)
        ball:Render(Isaac.WorldToScreen(proj.Position + proj.PositionOffset) + offset)
    end
    mod:AddCallback(ModCallbacks.MC_POST_PROJECTILE_RENDER, mod.OnProjectileRenderFootball)

    -- Spawning: swap some layout spawns as rooms load ----------------------------------
    -- Single-entity early bosses the Linebacker can take the place of.
    local REPLACEABLE_BOSSES = { [20] = true, [36] = true, [67] = true, [99] = true, [261] = true }
    -- Basic enemies that can become a Mascot or Referee (Gaper, Horf, Clotty).
    local REPLACEABLE_ENEMIES = { [10] = true, [12] = true, [15] = true }

    local bossSwappedThisRoom = false

    local function currentRoomType()
        local desc = game:GetLevel():GetCurrentRoomDesc()
        if desc and desc.Data then return desc.Data.Type end
        return game:GetRoom():GetType()
    end

    function mod:OnPreRoomEntitySpawn(type, variant, _, _, seed)
        local stage = game:GetLevel():GetStage()
        local roll = (seed % 1000) / 1000
        if currentRoomType() == RoomType.ROOM_BOSS then
            if REPLACEABLE_BOSSES[type] and variant == 0 and stage >= 2 and stage <= 6
                and not bossSwappedThisRoom and roll < Cfg.LINEBACKER_CHANCE then
                bossSwappedThisRoom = true
                return { TYPE, V.LINEBACKER, 0 }
            end
        elseif REPLACEABLE_ENEMIES[type] and stage <= 8 and roll < Cfg.FOOTBALL_ENEMY_CHANCE then
            return { TYPE, (seed // 1000) % 2 == 0 and V.MASCOT or V.REFEREE, 0 }
        end
    end
    mod:AddCallback(ModCallbacks.MC_PRE_ROOM_ENTITY_SPAWN, mod.OnPreRoomEntitySpawn)

    function mod:OnNewRoomMonsters()
        bossSwappedThisRoom = false
    end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoomMonsters)

    -- Console helper used by `gridiron boss` / `gridiron enemies`
    function mod.spawnMonster(variant, pos)
        return Isaac.Spawn(TYPE, variant, 0, pos, Vector.Zero, nil)
    end
end
