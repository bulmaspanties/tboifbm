-- Active items: Kicking Tee, Pigskin, Playbook, Coach's Whistle.
return function(mod)
    local game, sfx = mod.game, mod.sfx
    local Items, Cfg = mod.Items, mod.Cfg
    local pdata, forEachPlayer = mod.pdata, mod.forEachPlayer

    -- Footballs in flight ---------------------------------------------------------
    -- Balls are tracked in Lua and drawn in MC_POST_RENDER, so they can fly over
    -- rocks and pits without being real entities.
    local balls = {}

    local function launchBall(kind, player)
        local dir = mod.aimDirection(player)
        local kick = kind == "kick"
        local range = kick and Cfg.KICK_RANGE or Cfg.FUMBLE_RANGE
        local target = game:GetRoom():GetClampedPosition(player.Position + dir * range, 10)
        balls[#balls + 1] = {
            kind = kind,
            player = player,
            from = player.Position,
            to = target,
            pos = player.Position,
            dir = dir,
            t = 0,
            flight = kick and Cfg.KICK_FLIGHT or Cfg.FUMBLE_FLIGHT,
            peak = kick and Cfg.KICK_PEAK or Cfg.FUMBLE_PEAK,
            height = 0,
            scale = kick and 1.6 or 1.3,
            landed = false,
            life = 0,
            sprite = mod.newFootballSprite(),
        }
        sfx:Play(kick and SoundEffect.SOUND_PUNCH or SoundEffect.SOUND_SHELLGAME, 0.9, 0, false, kick and 0.8 or 1)
    end

    local function landKick(ball)
        local player = ball.player
        local dmg = Cfg.KICK_DAMAGE + player.Damage * Cfg.KICK_DAMAGE_MULT

        -- It's good if the explosion is going to finish something off.
        local good = false
        for _, e in ipairs(Isaac.FindInRadius(ball.pos, Cfg.KICK_RADIUS, EntityPartition.ENEMY)) do
            if e:IsVulnerableEnemy() and e:IsActiveEnemy(false) and e.HitPoints <= dmg then
                good = true
            end
        end

        mod.kickExploding = true
        game:BombExplosionEffects(ball.pos, dmg, TearFlags.TEAR_NORMAL, Color.Default, player,
            Cfg.KICK_RADIUS_MULT, true, false, DamageFlag.DAMAGE_EXPLOSION)
        mod.kickExploding = false

        if good then
            local rng = mod.rngFor(player, Items.KICKING_TEE)
            for _ = 1, Cfg.FIELD_GOAL_COINS do
                local vel = Vector.FromAngle(rng:RandomInt(360)) * (2 + rng:RandomFloat() * 2)
                Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_PENNY,
                    ball.pos, vel, player)
            end
            game:GetHUD():ShowItemText("It's good!", "Field goal: 3 points")
            sfx:Play(SoundEffect.SOUND_CASH_REGISTER)
        end
    end

    local function scoreTouchdown(player)
        local d = pdata(player)
        if not d.touchdown then
            d.touchdown = true
            mod.refreshCache(player)
        end
        game:GetHUD():ShowItemText("Touchdown!", "+1 Damage this room")
        sfx:Play(SoundEffect.SOUND_THUMBSUP)
        player:SetColor(Color(1, 1, 1, 1, 0.4, 0.3, 0), 15, 1, true, false)
    end

    local function updateFumble(ball)
        ball.life = ball.life - 1
        local player = ball.player

        for _, e in ipairs(Isaac.FindInRadius(ball.pos, Cfg.FUMBLE_PULL_RADIUS, EntityPartition.ENEMY)) do
            if e:IsVulnerableEnemy() and e:IsActiveEnemy(false) and not e:IsBoss() then
                local toBall = ball.pos - e.Position
                if toBall:Length() > 8 then
                    e:AddVelocity(toBall:Resized(Cfg.FUMBLE_PULL))
                end
                if ball.life % 30 == 0 then
                    e:AddConfusion(EntityRef(player), 35, false)
                end
            end
        end

        local canRecover = ball.life < Cfg.FUMBLE_TIME - Cfg.FUMBLE_PICKUP_GRACE
        if canRecover and (player.Position - ball.pos):Length() < player.Size + 14 then
            scoreTouchdown(player)
            return true
        end
        if ball.life <= 0 then
            Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, ball.pos, Vector.Zero, nil)
            return true
        end
        return false
    end

    function mod:OnUpdate()
        for i = #balls, 1, -1 do
            local ball = balls[i]
            local done = false
            if not ball.player:Exists() then
                done = true
            elseif not ball.landed then
                ball.t = ball.t + 1
                local u = ball.t / ball.flight
                ball.pos = ball.from + (ball.to - ball.from) * u
                ball.height = 4 * ball.peak * u * (1 - u)
                ball.sprite:Update()
                if ball.kind == "kick" then
                    ball.sprite.Rotation = ball.sprite.Rotation + 24 -- end over end
                else
                    ball.sprite.Rotation = ball.dir:GetAngleDegrees()
                end
                if ball.t >= ball.flight then
                    ball.height = 0
                    if ball.kind == "kick" then
                        landKick(ball)
                        done = true
                    else
                        ball.landed = true
                        ball.life = Cfg.FUMBLE_TIME
                        ball.sprite:SetFrame("Spiral", 0)
                        ball.sprite.Rotation = 0
                        sfx:Play(SoundEffect.SOUND_PLOP)
                    end
                end
            else
                done = updateFumble(ball)
            end
            if done then table.remove(balls, i) end
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.OnUpdate)

    function mod:OnRender()
        for _, ball in ipairs(balls) do
            local ground = Isaac.WorldToScreen(ball.pos)
            local s = ball.sprite
            local rot, col = s.Rotation, s.Color

            -- shadow
            s.Rotation = 0
            s.Color = Color(0, 0, 0, 0.35)
            s.Scale = Vector(ball.scale, ball.scale * 0.45)
            s:Render(ground + Vector(0, 4))

            -- ball (blinks when a fumble is about to disappear)
            s.Rotation, s.Color = rot, col
            s.Scale = Vector(ball.scale, ball.scale)
            local blinking = ball.landed and ball.life < 40 and ball.life % 8 < 4
            if not blinking then
                s:Render(ground - Vector(0, ball.height))
            end
        end
    end
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.OnRender)

    function mod:OnUseKickingTee(_, _, player)
        launchBall("kick", player)
        return true
    end
    mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.OnUseKickingTee, Items.KICKING_TEE)

    function mod:OnUsePigskin(_, _, player)
        launchBall("fumble", player)
        return true
    end
    mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.OnUsePigskin, Items.PIGSKIN)

    -- Playbook: call a play for the room, cycling through the book ---------------
    local PLAYS = {
        { id = "blitz",    name = "Blitz!",     desc = "Tears and speed up" },
        { id = "hailmary", name = "Hail Mary!", desc = "Range, shot speed, piercing" },
        { id = "trick",    name = "Trick play!", desc = "Your next shots are footballs" },
    }
    mod.PLAYS = PLAYS
    local PLAY_CACHE = CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_SPEED | CacheFlag.CACHE_RANGE
        | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_TEARFLAG

    function mod.playName(id)
        for _, play in ipairs(PLAYS) do
            if play.id == id then return play.name end
        end
    end

    function mod:OnUsePlaybook(_, _, player)
        local d = pdata(player)
        d.playIndex = d.playIndex % #PLAYS + 1
        local play = PLAYS[d.playIndex]
        d.play = play.id
        d.trickShots = play.id == "trick" and Cfg.TRICK_PLAY_SHOTS or 0
        mod.refreshCache(player, PLAY_CACHE)
        game:GetHUD():ShowItemText(play.name, play.desc)
        mod.playWhistle(0.6)
        return true
    end
    mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.OnUsePlaybook, Items.PLAYBOOK)

    -- Coach's Whistle: "Offsides!" Everyone back five yards ----------------------
    function mod:OnUseWhistle(_, _, player)
        local ref = EntityRef(player)
        for _, e in ipairs(Isaac.GetRoomEntities()) do
            local proj = e:ToProjectile()
            if proj and not proj:HasProjectileFlags(ProjectileFlags.CANT_HIT_PLAYER) then
                proj:Die() -- the play is dead
            elseif e:IsVulnerableEnemy() and e:IsActiveEnemy(false) then
                local away = e.Position - player.Position
                if away:Length() < 1 then away = Vector(0, 1) end
                if e:IsBoss() then
                    e:TakeDamage(Cfg.WHISTLE_BOSS_DAMAGE + player.Damage * Cfg.WHISTLE_BOSS_DMG_MULT, 0, ref, 0)
                    e:AddSlowing(ref, math.floor(Cfg.WHISTLE_SLOW_FRAMES / 2), Cfg.WHISTLE_SLOW_VALUE, Color(1, 1, 0.5, 1))
                else
                    e:AddVelocity(away:Resized(Cfg.WHISTLE_KNOCKBACK))
                    e:AddSlowing(ref, Cfg.WHISTLE_SLOW_FRAMES, Cfg.WHISTLE_SLOW_VALUE, Color(1, 1, 0.5, 1))
                end
            end
        end
        mod.playWhistle(1)
        game:ShakeScreen(8)
        game:GetHUD():ShowItemText("Offsides!", "Five yard penalty")
        return true
    end
    mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.OnUseWhistle, Items.WHISTLE)

    -- Room / run resets ---------------------------------------------------------
    function mod:OnNewRoomActives()
        balls = {}
        forEachPlayer(function(player)
            local d = pdata(player)
            if d.play then
                d.play = nil
                d.trickShots = 0
                mod.refreshCache(player, PLAY_CACHE)
            end
        end)
    end
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoomActives)

    function mod:OnGameExitActives()
        balls = {}
    end
    mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.OnGameExitActives)
end
