-- Football enemies: Lineman, Blitzer, Punter, Huddle, Gatorade Cooler, Chain Gang,
-- Sacker and The Coach (miniboss). monsters.lua dispatches NPC_UPDATE here by variant
-- and swaps them in for vanilla enemies that fight the same way.
return function(mod)
    local game, sfx = mod.game, mod.sfx
    local Cfg = mod.Cfg
    local TYPE, V = mod.MonsterType, mod.MonsterVariants
    local shoot, toward, face, ring = mod.monsterShoot, mod.monsterToward, mod.monsterFace, mod.monsterRing

    local ORANGE = Color(1, 0.55, 0.1, 1, 0.4, 0.15, 0)
    local updaters = {}
    mod.FoeUpdaters = updaters

    local function hasPartner(d) return d.partner and d.partner:Exists() and not d.partner:IsDead() end

    -- Lineman: waddles after you; line up with him and he digs in and charges --------------
    updaters[V.LINEMAN] = function(npc, d, target, s)
        if not d.mode then d.mode, d.timer, d.cooldown = "walk", 0, 30; s:Play("Walk", true) end
        d.timer, d.cooldown = d.timer - 1, d.cooldown - 1
        local diff = target.Position - npc.Position
        if d.mode == "walk" then
            npc.Pathfinder:FindGridPath(target.Position, 0.4, 900, true)
            face(npc, s, target.Position.X)
            local aligned = math.abs(diff.X) < 16 or math.abs(diff.Y) < 16
            if aligned and d.cooldown <= 0 and diff:Length() < 320 then
                d.dir = math.abs(diff.X) > math.abs(diff.Y) and Vector(diff.X > 0 and 1 or -1, 0)
                    or Vector(0, diff.Y > 0 and 1 or -1)
                d.mode, d.timer = "dig", 18
                s:Play("Dig", true)
                sfx:Play(SoundEffect.SOUND_MONSTER_GRUNT_0, 0.8)
            end
        elseif d.mode == "dig" then
            npc.Velocity = npc.Velocity * 0.5
            if d.timer % 4 == 0 then npc:SetColor(Color(1, 1, 1, 1, 0.5, 0.1, 0.1), 2, 1, false, false) end
            if d.timer <= 0 then
                d.mode, d.timer = "charge", 50
                s:Play("Charge", true)
            end
        elseif d.mode == "charge" then
            npc.Velocity = d.dir * 9
            face(npc, s, npc.Position.X + d.dir.X)
            if (npc:CollidesWithGrid() and d.timer < 47) or d.timer <= 0 then
                if npc:CollidesWithGrid() then
                    game:ShakeScreen(4)
                    sfx:Play(SoundEffect.SOUND_FORESTBOSS_STOMPS, 0.5, 0, false, 1.4)
                    mod.playSound("CLACK", 0.7)
                end
                -- a captain doesn't stop: he lines you up again and goes, three times
                if d.captain and (d.chain or 0) < 2 then
                    d.chain = (d.chain or 0) + 1
                    local diff2 = target.Position - npc.Position
                    d.dir = math.abs(diff2.X) > math.abs(diff2.Y) and Vector(diff2.X > 0 and 1 or -1, 0)
                        or Vector(0, diff2.Y > 0 and 1 or -1)
                    d.mode, d.timer = "dig", 8
                    s:Play("Dig", true)
                else
                    d.chain = 0
                    d.mode, d.timer, d.cooldown = "walk", 0, 45
                    s:Play("Walk", true)
                end
            end
        end
    end

    -- Blitzer: circles you, flashes, then dives in a straight line -------------------------
    updaters[V.BLITZER] = function(npc, d, target, s)
        if not d.mode then
            d.mode, d.timer = "orbit", 70 + math.random(40)
            d.angle = (npc.Position - target.Position):GetAngleDegrees()
            npc.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS   -- flies over rocks
            s:Play("Fly", true)
        end
        d.timer = d.timer - 1
        if d.mode == "orbit" then
            d.angle = d.angle + 3
            local want = target.Position + Vector.FromAngle(d.angle) * 90
            local v = (want - npc.Position) * 0.15
            npc.Velocity = v:Length() > 6 and v:Resized(6) or v
            if d.timer <= 0 then
                d.mode, d.timer = "windup", 12
            end
        elseif d.mode == "windup" then
            npc.Velocity = npc.Velocity * 0.6
            if d.timer % 4 == 0 then npc:SetColor(Color(1, 1, 1, 1, 0.6, 0.1, 0.1), 2, 1, false, false) end
            if d.timer <= 0 then
                d.dir = toward(npc, target, 1)
                d.mode, d.timer = "dive", 24
                s:Play("Dive", true)
                sfx:Play(SoundEffect.SOUND_FETUS_JUMP, 0.6, 0, false, 1.6)
            end
        else
            npc.Velocity = d.dir * 11
            if d.timer <= 0 and d.captain and not d.doubled then
                d.doubled = true                                  -- a captain dives twice
                d.mode, d.timer = "windup", 8
                s:Play("Fly", true)
            elseif d.timer <= 0 then
                d.doubled = false
                d.mode, d.timer = "orbit", 60 + math.random(40)
                d.angle = (npc.Position - target.Position):GetAngleDegrees()
                s:Play("Fly", true)
            end
        end
        face(npc, s, target.Position.X)
    end

    -- Punter: stays put, boots spiked footballs over the rocks at you -----------------------
    local function puntFootball(npc, target, angle)
        local dist = (target.Position - npc.Position):Length()
        local vel = toward(npc, target, math.max(3, math.min(9, dist / 28)))
        local p = shoot(npc, angle and vel:Rotated(angle) or vel, 1.6, Color(0.55, 0.3, 0.15, 1))
        p.FallingSpeed = -18
        p.FallingAccel = 1.2
        p:AddProjectileFlags(ProjectileFlags.BURST)
        p:GetData().GridironFootball = mod.newFootballSprite()
        p:GetSprite().Color = Color(1, 1, 1, 0)
        return p
    end
    mod.puntFootball = puntFootball

    updaters[V.PUNTER] = function(npc, d, target, s)
        if not d.mode then d.mode, d.timer = "idle", 40 + math.random(40); s:Play("Idle", true) end
        d.timer = d.timer - 1
        if (target.Position - npc.Position):Length() < 90 then
            npc.Pathfinder:EvadeTarget(target.Position)          -- give the kicker some room
        else
            npc.Velocity = npc.Velocity * 0.6
        end
        if d.mode == "idle" and d.timer <= 0 then
            d.mode, d.timer = "kick", 18
            s:Play("Kick", true)
        elseif d.mode == "kick" then
            if d.timer == 8 then
                puntFootball(npc, target)
                if d.captain then                                 -- a captain punts a spread
                    puntFootball(npc, target, -25)
                    puntFootball(npc, target, 25)
                end
                sfx:Play(SoundEffect.SOUND_PUNCH, 0.8, 0, false, 0.8)
            end
            if d.timer <= 0 then
                d.mode, d.timer = "idle", 70 + math.random(40)
                s:Play("Idle", true)
            end
        end
        face(npc, s, target.Position.X)
    end

    -- Huddle: a ring of four; hit one and they all break and rush you ------------------------
    local brokenHuddles = {}

    local function breakHuddle(npc)
        local d = npc:GetData()
        if not d.group or brokenHuddles[d.group] then return end
        brokenHuddles[d.group] = true
        mod.popOn(npc, "BREAK!", mod.Colors.orange, 1.1)
        sfx:Play(SoundEffect.SOUND_MONSTER_YELL_A, 0.7)
    end

    updaters[V.HUDDLE] = function(npc, d, target, s)
        if not d.started then
            d.started = true
            if not d.group then                                  -- a fresh huddle: this one leads
                d.group, d.slot, d.leader = GetPtrHash(npc), 0, npc
                if npc.SubType == 0 then                          -- and brings the rest
                    d.size = d.captain and 6 or 4                 -- a captain's huddle is six deep
                    for i = 1, d.size - 1 do
                        local m = Isaac.Spawn(TYPE, V.HUDDLE, 1, npc.Position + Vector.FromAngle(i * 360 / d.size) * 16, Vector.Zero, npc)
                        local md = m:GetData()
                        md.group, md.slot, md.leader, md.size = d.group, i, npc, d.size
                        if d.captain then mod.makeCaptain(m) end
                    end
                end
            end
            s:Play("Walk", true)
        end
        if not brokenHuddles[d.group] and d.leader ~= npc and not (d.leader:Exists() and not d.leader:IsDead()) then
            breakHuddle(npc)                                     -- lose the leader, lose the formation
        end
        if brokenHuddles[d.group] then
            if not s:IsPlaying("Run") then s:Play("Run", true) end
            npc.Pathfinder:FindGridPath(target.Position, 0.85, 900, true)
        elseif d.leader == npc then
            npc.Pathfinder:FindGridPath(target.Position, 0.25, 900, true)
        else
            local spot = d.leader.Position + Vector.FromAngle(d.slot * 360 / (d.size or 4) + game:GetFrameCount() * 2) * 16
            npc.Velocity = (spot - npc.Position) * 0.3
        end
        face(npc, s, target.Position.X)
    end

    function mod:OnFoeDamage(entity)
        if entity.Variant == V.HUDDLE then breakHuddle(entity) end
    end
    mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.OnFoeDamage, TYPE)

    -- Gatorade Cooler: sloshes after you, leaks, and bursts into slowing orange creep ---------
    local function creep(pos, scale, timeout)
        local c = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.CREEP_WHITE, 0, pos, Vector.Zero, nil)
        c.SpriteScale = Vector(scale, scale)
        c.Color = ORANGE
        local fx = c:ToEffect()
        if fx then
            fx.Scale = scale
            fx.Timeout = timeout
        end
        return c
    end

    updaters[V.COOLER] = function(npc, d, target, s)
        if not d.mode then d.mode, d.timer = "walk", 45; s:Play("Walk", true) end
        d.timer = d.timer - 1
        npc.Pathfinder:FindGridPath(target.Position, 0.3, 900, true)
        if d.timer <= 0 then
            d.timer = d.captain and 15 or 45                      -- a captain leaves a trail
            creep(npc.Position, 0.6, 90)
        end
        face(npc, s, target.Position.X)
    end

    -- Chain Gang: two zombie refs on one chain; they flank you and the chain hurts ------------
    local CHAIN_MAX = 150
    local chainSprite

    local function segmentDistance(p, a, b)
        local ab = b - a
        local len2 = ab.X * ab.X + ab.Y * ab.Y
        if len2 < 1 then return (p - a):Length() end
        local t = math.max(0, math.min(1, ((p - a).X * ab.X + (p - a).Y * ab.Y) / len2))
        return (p - (a + ab * t)):Length()
    end

    updaters[V.CHAIN_GANG] = function(npc, d, target, s)
        if not d.mode then
            d.mode = "walk"
            if npc.SubType == 0 then
                local partner = Isaac.Spawn(TYPE, V.CHAIN_GANG, 1, npc.Position + Vector(60, 0), Vector.Zero, npc)
                partner:GetData().partner = npc
                if d.captain then mod.makeCaptain(partner) end
                d.partner = partner
            end
            s:Play("Walk", true)
        end
        local side = npc.SubType == 0 and 1 or -1
        local toMe = npc.Position - target.Position
        local flank = target.Position + toMe:Rotated(90 * side):Resized(50)
        if hasPartner(d) then
            npc.Pathfinder:FindGridPath(flank, (d.captain and 0.5 or 0.38) * (mod.drugTestOn() and 1.3 or 1), 900, true)
            local gap = d.partner.Position - npc.Position
            if gap:Length() > CHAIN_MAX then npc:AddVelocity(gap:Resized(1.5)) end   -- the chain pulls
            -- the chain hurts: only the first ref checks, so it's one hit per touch
            if npc.SubType == 0 then
                for i = 0, game:GetNumPlayers() - 1 do
                    local p = Isaac.GetPlayer(i)
                    if segmentDistance(p.Position, npc.Position, d.partner.Position) < p.Size + (d.captain and 10 or 4) then
                        p:TakeDamage(1, 0, EntityRef(npc), 30)
                    end
                end
            end
        else
            if not d.unchained then
                d.unchained = true
                mod.popOn(npc, "UNCHAINED!", mod.Colors.red)
            end
            npc.Pathfinder:FindGridPath(target.Position, 0.6, 900, true)
        end
        face(npc, s, target.Position.X)
    end

    function mod:OnChainRender(npc, offset)
        if npc.Variant ~= V.CHAIN_GANG or npc.SubType ~= 0 or mod.isReflectionPass() then return end
        local d = npc:GetData()
        if not hasPartner(d) then return end
        if not chainSprite then
            chainSprite = Sprite()
            chainSprite:Load("gfx/monsters/gridiron_chain.anm2", true)
            chainSprite:Play("Idle", true)
        end
        local a, b = npc.Position + Vector(0, -8), d.partner.Position + Vector(0, -8)
        local links = math.max(2, math.floor((b - a):Length() / 9))
        for i = 1, links - 1 do
            chainSprite:Render(Isaac.WorldToScreen(a + (b - a) * (i / links)) + offset)
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_NPC_RENDER, mod.OnChainRender, TYPE)

    -- Sacker: tunnels under the turf toward you and bursts up underneath -------------------
    updaters[V.SACKER] = function(npc, d, target, s)
        if not d.mode then
            d.mode, d.timer = "under", 70
            npc.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
            npc.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS
            s:Play("Mound", true)
        end
        d.timer = d.timer - 1
        if d.mode == "under" then
            local v = target.Position - npc.Position
            npc.Velocity = v:Length() > 2.4 and v:Resized(2.4) or v
            if d.timer <= 0 or v:Length() < 12 then
                d.mode, d.timer = "rise", 16
                s:Play("Rise", true)
                sfx:Play(SoundEffect.SOUND_MAGGOT_BURST_OUT, 0.7)
            end
        elseif d.mode == "rise" then
            npc.Velocity = Vector.Zero
            if d.timer <= 0 then
                d.mode, d.timer = "up", 50
                npc.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
                npc.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_GROUND
                s:Play("Up", true)
                game:ShakeScreen(5)
                mod.popOn(npc, "SACK!", mod.Colors.red)
            end
        elseif d.mode == "up" then
            npc.Velocity = npc.Velocity * 0.6
            if d.timer == 25 then
                local n = d.captain and 8 or 4                   -- a captain erupts in a full ring
                for i = 0, n - 1 do shoot(npc, Vector.FromAngle(45 + i * 360 / n) * 7, 1) end
            end
            if d.timer <= 0 then
                d.mode, d.timer = "dig", 10
                s:Play("Dig", true)
            end
        elseif d.mode == "dig" then
            npc.Velocity = Vector.Zero
            if d.timer <= 0 then
                d.mode, d.timer = "under", 80
                npc.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
                npc.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS
                s:Play("Mound", true)
            end
        end
    end

    -- The Coach (miniboss): hangs back and calls plays for everyone else ---------------------
    -- blitz: the team speeds up; prevent: the team takes half damage; pep talk: heals and enrages.
    local PLAYS = {
        { id = "blitz", call = "BLITZ!", tint = Color(1, 1, 1, 1, 0.35, 0.2, 0) },
        { id = "prevent", call = "PREVENT D!", tint = Color(1, 1, 1, 1, 0.1, 0.15, 0.4) },
        { id = "pep", call = "PEP TALK!", tint = Color(1, 1, 1, 1, 0.45, 0.05, 0.05) },
    }
    local coachPlay, coachPlayTimer = nil, 0

    local function teammates(coach)
        local list = {}
        for _, e in ipairs(Isaac.GetRoomEntities()) do
            if e:IsVulnerableEnemy() and e:IsActiveEnemy(false) and not (e.Type == TYPE and e.Variant == V.COACH) then
                list[#list + 1] = e
            end
        end
        return list
    end

    updaters[V.COACH] = function(npc, d, target, s)
        if not d.mode then d.mode, d.timer, d.playIndex, d.subTimer = "idle", 60, 0, 240; s:Play("Idle", true) end
        d.timer, d.subTimer = d.timer - 1, d.subTimer - 1
        local dist = (target.Position - npc.Position):Length()
        if dist < 180 then
            npc.Pathfinder:EvadeTarget(target.Position)
        else
            npc.Velocity = npc.Velocity * 0.8
        end
        if d.mode == "idle" and d.timer <= 0 then
            d.mode, d.timer = "yell", 24
            s:Play("Yell", true)
            d.playIndex = d.playIndex % #PLAYS + 1
            local play = PLAYS[d.playIndex]
            coachPlay, coachPlayTimer = play, Cfg.COACH_PLAY_FRAMES
            mod.popOn(npc, play.call, mod.Colors.red, 1.2)
            mod.playWhistle(0.8)
            for _, e in ipairs(teammates(npc)) do
                e:SetColor(play.tint, 30, 1, true, false)
                if play.id == "pep" then e.HitPoints = math.min(e.MaxHitPoints, e.HitPoints + e.MaxHitPoints * 0.25) end
            end
        elseif d.mode == "yell" and d.timer <= 0 then
            d.mode, d.timer = "idle", 150
            s:Play("Idle", true)
        end
        -- no one left to coach: call in a sub
        if d.subTimer <= 0 then
            d.subTimer = 300
            if #teammates(npc) < 2 then
                Isaac.Spawn(TYPE, V.LINEMAN, 0, npc.Position + toward(npc, target, 30), Vector.Zero, npc)
                mod.popOn(npc, "SUB IN!", mod.Colors.yellow)
            end
        end
        face(npc, s, target.Position.X)
    end

    -- Active plays: blitz pushes everyone faster; tints remind you what's on.
    function mod:OnUpdateCoachPlay()
        if not coachPlay then return end
        coachPlayTimer = coachPlayTimer - 1
        if coachPlayTimer <= 0 or #Isaac.FindByType(TYPE, V.COACH) == 0 then
            coachPlay = nil
            return
        end
        if coachPlay.id == "blitz" then
            for _, e in ipairs(teammates(nil)) do
                if e.Velocity:Length() < 8 then e.Velocity = e.Velocity * Cfg.COACH_BLITZ_SPEED end   -- capped: no snowballing
            end
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.OnUpdateCoachPlay)

    -- Prevent defense: enemies take half damage while it's called (read by gear.lua).
    function mod.enemyDamageTakenMult(entity)
        if coachPlay and coachPlay.id == "prevent" and not (entity.Type == TYPE and entity.Variant == V.COACH) then
            return 0.5
        end
        return 1
    end
    function mod.currentCoachPlay() return coachPlay and coachPlay.id end

    function mod:OnFoeDeath(npc)
        if npc.Variant == V.COOLER then
            creep(npc.Position, npc:GetData().captain and 3.6 or 2.6, 300)   -- the bucket spills
            for i = 0, 5 do shoot(npc, Vector.FromAngle(i * 60) * 6, 1, ORANGE) end
            sfx:Play(SoundEffect.SOUND_SPLATTER, 1.1)
            mod.popAt(npc.Position, "SPLASH!", mod.Colors.orange)
        elseif npc.Variant == V.COACH then
            coachPlay = nil
            mod.popAt(npc.Position, "FIRED!", mod.Colors.gold, 1.4)
            mod.playSound("HORN", 0.8)
            mod.playSound("CHEER", 0.7)
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, mod.OnFoeDeath, TYPE)

    -- Team Captains: a gold champion version of any football enemy, with a twist each ----------
    local CAPTAIN_GOLD = Color(1, 0.9, 0.55, 1, 0.22, 0.16, 0)
    local NO_CAPTAIN = { [V.LINEBACKER] = true, [V.COACH] = true, [V.FRANCHISE] = true, [V.MASCOT_BOSS] = true }

    -- Football players wear real kits: a captain swaps to his captain's sheet (gold trim and
    -- the "C" patch) instead of being washed gold, and the Tainted Coach's squad wears your colours.
    local KIT_SHEETS = {
        [V.LINEMAN] = "gfx/monsters/gridiron_lineman", [V.HUDDLE] = "gfx/monsters/gridiron_huddle",
        [V.PUNTER] = "gfx/monsters/gridiron_punter", [V.SACKER] = "gfx/monsters/gridiron_sacker",
        [V.BLITZER] = "gfx/monsters/gridiron_blitzer",
    }
    local CAPTAIN_SHINE = Color(1, 1, 1, 1, 0.06, 0.05, 0)

    function mod.dressFoe(npc)
        local base = KIT_SHEETS[npc.Variant]
        if not base then return false end
        local d = npc:GetData()
        local sheet = base
        if d.teamColor and npc.Variant == V.LINEMAN then sheet = sheet .. "_team_" .. d.teamColor end
        if d.captain then sheet = sheet .. "_captain" end
        local s = npc:GetSprite()
        s:ReplaceSpritesheet(0, sheet .. ".png")
        s:LoadGraphics()
        return true
    end

    function mod.makeCaptain(npc)
        local d = npc:GetData()
        if d.captain then return end
        d.captain = true
        npc.MaxHitPoints = npc.MaxHitPoints * Cfg.CAPTAIN_HP_MULT
        npc.HitPoints = npc.MaxHitPoints
        npc.Color = mod.dressFoe(npc) and CAPTAIN_SHINE or CAPTAIN_GOLD
        if npc.SubType == 0 then mod.popOn(npc, "CAPTAIN!", mod.Colors.gold, 1.0) end
    end

    function mod:OnFoeInit(npc)
        if NO_CAPTAIN[npc.Variant] or npc.SubType ~= 0 then return end   -- partners follow their leader
        if npc.IsChampion and npc:IsChampion() then return end            -- vanilla champions stay vanilla
        if ((npc.InitSeed or 0) % 1000) / 1000 < Cfg.CAPTAIN_CHANCE then mod.makeCaptain(npc) end
    end
    mod:AddCallback(ModCallbacks.MC_POST_NPC_INIT, mod.OnFoeInit, TYPE)

    function mod:OnNewRoomFoes()
        brokenHuddles, coachPlay, coachPlayTimer = {}, nil, 0
    end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoomFoes)
end
