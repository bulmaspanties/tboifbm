-- The Franchise: two-phase boss for floors 7-8 (swapped in like the Linebacker, see monsters.lua).
--   Phase 1, the quarterback: runs a route tree (slants, go route, screen pass, Hail Mary) and
--            calls audibles that bring in Linemen.
--   Phase 2, the stadium (below half health): he retreats to the top of the field and the
--            stadium turns on you: the crowd wave, the Kiss Cam and falling goalposts.
return function(mod)
    local game, sfx = mod.game, mod.sfx
    local Cfg = mod.Cfg
    local TYPE, V = mod.MonsterType, mod.MonsterVariants
    local shoot, toward, face = mod.monsterShoot, mod.monsterToward, mod.monsterFace

    local LEATHER = Color(0.55, 0.3, 0.15, 1)

    local function football(npc, vel, scale)
        local p = shoot(npc, vel, scale or 1.3, LEATHER)
        p:GetData().GridironFootball = mod.newFootballSprite()
        p:GetSprite().Color = Color(1, 1, 1, 0)
        return p
    end

    -- Phase 1 plays ---------------------------------------------------------------------
    local function slants(npc, target)
        for i, curve in ipairs({ ProjectileFlags.CURVE_LEFT, ProjectileFlags.CURVE_RIGHT, ProjectileFlags.CURVE_LEFT }) do
            local p = football(npc, toward(npc, target, 7):Rotated((i - 2) * 25))
            p:AddProjectileFlags(curve)
        end
    end

    local function goRoute(npc, target)
        local dir = toward(npc, target, 1)
        football(npc, dir * 14, 1.9)                                  -- the bomb...
        for k = 1, 4 do football(npc, dir * (11 - k * 1.5), 0.9) end  -- ...and its wake
    end

    local function screenPass(npc, target)
        for k = -3, 3 do
            local p = football(npc, toward(npc, target, 6):Rotated(k * 14), 1.0)
            p.FallingAccel = 0.3                                     -- short, it drops early
        end
    end

    local function hailMary(npc, target)
        local dist = (target.Position - npc.Position):Length()
        local p = football(npc, toward(npc, target, math.max(3, dist / 32)), 2.2)
        p.FallingSpeed = -20
        p.FallingAccel = 1.2
        p:AddProjectileFlags(ProjectileFlags.BURST)
        local marker = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.TARGET, 0, target.Position, Vector.Zero, npc)
        marker:ToEffect().Timeout = 32
    end

    local function audible(npc)
        local linemen = #Isaac.FindByType(TYPE, V.LINEMAN)
        if linemen < Cfg.FRANCHISE_MAX_LINEMEN then
            for side = -1, 1, 2 do
                Isaac.Spawn(TYPE, V.LINEMAN, 0, npc.Position + Vector(side * 60, 30), Vector.Zero, npc)
            end
        end
        mod.popOn(npc, "AUDIBLE! HUT HUT!", mod.Colors.red, 1.2)
        mod.playWhistle(0.9)
    end

    local PHASE1 = {
        { anim = "Wind", call = "SLANTS!", play = slants },
        { anim = "Wind", call = "GO ROUTE!", play = goRoute },
        { anim = "Throw", call = "SCREEN!", play = screenPass },
        { anim = "Wind", call = "HAIL MARY!", play = hailMary },
        { anim = "Audible", call = nil, play = audible },
    }

    -- Phase 2: the stadium --------------------------------------------------------------
    local function crowdWave(npc, target)
        local room = game:GetRoom()
        local tl, br = room:GetTopLeftPos(), room:GetBottomRightPos()
        local gap = target.Position.X + (math.random() - 0.5) * 120
        for x = tl.X + 10, br.X - 10, 28 do
            if math.abs(x - gap) > 42 then
                local p = shoot(npc, Vector(0, 4.2), 1.1, Color(1, 1, 1, 1, 0.25, 0.1, 0.35))
                p.Position = Vector(x, tl.Y + 10)
                p.FallingAccel = -0.09                               -- floats all the way down the field
            end
        end
        mod.popAt(Vector((tl.X + br.X) / 2, tl.Y + 30), "THE WAVE!", mod.Colors.blue, 1.2)
        mod.playSound("CHEER", 0.7)
    end

    local function kissCam(npc, target, d)
        d.camPos = target.Position
        d.camTimer = 40
        local marker = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.TARGET, 0, d.camPos, Vector.Zero, npc)
        marker:ToEffect().Timeout = 40
        marker.Color = Color(1, 0.4, 0.7, 1, 0.4, 0, 0.2)
        mod.popAt(d.camPos + Vector(0, -40), "KISS CAM!", mod.Colors.red, 1.2)
    end

    local function goalposts(npc, target, d)
        local room = game:GetRoom()
        local tl, br = room:GetTopLeftPos(), room:GetBottomRightPos()
        d.posts = {}
        for _, x in ipairs({ target.Position.X, tl.X + math.random() * (br.X - tl.X) }) do
            for y = tl.Y + 20, br.Y - 20, 44 do
                local spot = Vector(x, y)
                d.posts[#d.posts + 1] = spot
                local m = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.TARGET, 0, spot, Vector.Zero, npc)
                m:ToEffect().Timeout = 30
            end
        end
        d.postTimer = 30
        mod.popAt(Vector(target.Position.X, tl.Y + 30), "GOALPOSTS!", mod.Colors.yellow, 1.2)
    end

    local PHASE2 = {
        { call = nil, play = crowdWave },
        { call = nil, play = kissCam },
        { call = nil, play = goalposts },
        { call = "GO ROUTE!", play = goRoute },
    }

    -- Hazards that resolve a little later (they keep ticking even mid-attack).
    local function updateHazards(npc, d)
        if d.camTimer then
            d.camTimer = d.camTimer - 1
            if d.camTimer <= 0 then
                game:BombExplosionEffects(d.camPos, Cfg.FRANCHISE_CAM_DAMAGE, TearFlags.TEAR_NORMAL, Color.Default,
                    npc, 1, true, false, DamageFlag.DAMAGE_EXPLOSION)
                d.camTimer, d.camPos = nil, nil
            end
        end
        if d.postTimer then
            d.postTimer = d.postTimer - 1
            if d.postTimer <= 0 then
                for _, spot in ipairs(d.posts) do                    -- the goalposts come down
                    local p = shoot(npc, Vector.Zero, 1.6, Color(1, 1, 0.4, 1, 0.3, 0.3, 0))
                    p.Position = spot
                    p.Height = -300
                    p.FallingSpeed = 12
                    p.FallingAccel = 1
                end
                game:ShakeScreen(10)
                sfx:Play(SoundEffect.SOUND_FORESTBOSS_STOMPS, 1.1)
                d.postTimer, d.posts = nil, nil
            end
        end
    end

    -- The boss ---------------------------------------------------------------------------
    local function update(npc, d, target, s)
        if not d.mode then
            d.mode, d.timer, d.play = "idle", 50, 0
            s:Play("Idle", true)
            game:GetHUD():ShowItemText("The Franchise", "Max contract. Zero defense.")
            mod.playSound("HORN", 1)
        end
        d.timer = d.timer - 1
        updateHazards(npc, d)
        local stadium = d.phase == 2

        if not stadium and npc.HitPoints < npc.MaxHitPoints * 0.5 then
            -- Phase change: off to the top of the field, and the stadium takes over.
            d.phase, d.mode, d.timer, d.play = 2, "retreat", 40, 0   -- the stadium opens with the wave
            local room = game:GetRoom()
            d.home = Vector(room:GetCenterPos().X, room:GetTopLeftPos().Y + 70)
            npc.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
            s:Play("Slam", true)
            game:ShakeScreen(18)
            mod.popOn(npc, "THE STADIUM!", mod.Colors.red, 1.5)
            mod.playSound("BOO", 0.9)
            mod.playSound("HORN", 1)
            return
        end

        if d.mode == "retreat" then
            npc.Velocity = (d.home - npc.Position) * 0.15
            if d.timer <= 0 then
                npc.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
                d.mode, d.timer = "idle", 30
                s:Play("Rage", true)
            end
            return
        end

        if d.mode == "idle" then
            if stadium then
                npc.Velocity = (d.home - npc.Position) * 0.1             -- he holds the far end
            else
                local dist = (target.Position - npc.Position):Length()
                if dist < 130 then npc.Pathfinder:EvadeTarget(target.Position)
                else npc.Pathfinder:FindGridPath(target.Position, 0.3, 900, true) end
            end
            face(npc, s, target.Position.X)
            if d.timer <= 0 then
                local list = stadium and PHASE2 or PHASE1
                d.play = d.play % #list + 1
                local play = list[d.play]
                d.mode, d.timer = "windup", stadium and 14 or 18
                s:Play(stadium and "RageWind" or (play.anim or "Wind"), true)
                if play.call then mod.popOn(npc, play.call, mod.Colors.gold, 1.1) end
            end
        elseif d.mode == "windup" then
            npc.Velocity = npc.Velocity * 0.6
            if d.timer <= 0 then
                local play = (stadium and PHASE2 or PHASE1)[d.play]
                play.play(npc, target, d)
                d.mode, d.timer = "release", 16
                s:Play(stadium and "RageThrow" or "Throw", true)
                sfx:Play(SoundEffect.SOUND_SHELLGAME, 0.9, 0, false, 0.7)
            end
        elseif d.mode == "release" then
            npc.Velocity = npc.Velocity * 0.7
            if d.timer <= 0 then
                d.mode, d.timer = "idle", stadium and 40 or 55
                s:Play(stadium and "Rage" or "Idle", true)
            end
        end
    end
    mod.FoeUpdaters[V.FRANCHISE] = update

    function mod:OnFranchiseDeath(npc)
        if npc.Variant ~= V.FRANCHISE then return end
        mod.popAt(npc.Position, "TRADED!", mod.Colors.gold, 1.6)
        game:ShakeScreen(20)
        mod.playSound("HORN", 1)
        mod.playSound("CHEER", 1)
        for i = 0, 5 do
            Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.FIREWORKS, 0,
                npc.Position + Vector.FromAngle(i * 60) * 70, Vector.Zero, nil)
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, mod.OnFranchiseDeath, TYPE)
end
