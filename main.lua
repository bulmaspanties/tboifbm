-- Gridiron: American football gear for The Binding of Isaac: Repentance+
-- Uses only the vanilla Lua API (REPENTOGON not required).

local mod = RegisterMod("Gridiron", 1)
local game = Game()
local sfx = SFXManager()

local Items = {
    HELMET     = Isaac.GetItemIdByName("Football Helmet"),
    PADS       = Isaac.GetItemIdByName("Shoulder Pads"),
    JERSEY     = Isaac.GetItemIdByName("Team Jersey"),
    CLEATS     = Isaac.GetItemIdByName("Football Cleats"),
    EYE_BLACK  = Isaac.GetItemIdByName("Eye Black"),
    GLOVES     = Isaac.GetItemIdByName("Receiver Gloves"),
    MOUTHGUARD = Isaac.GetItemIdByName("Mouthguard"),
    KICKING_TEE = Isaac.GetItemIdByName("Kicking Tee"),
    PIGSKIN    = Isaac.GetItemIdByName("Pigskin"),
}
local Trinkets = {
    PANTS = Isaac.GetTrinketIdByName("Padded Pants"),
}
mod.Items = Items
mod.Trinkets = Trinkets

-- Body costumes that share a layer come in combined variants (see content/costumes2.xml).
local function nullCostume(name)
    return Isaac.GetCostumeIdByPath("gfx/characters/gridiron_" .. name .. ".anm2")
end
local Costumes = {
    torso = {
        jersey     = nullCostume("torso_jersey"),
        pads       = nullCostume("torso_pads"),
        jerseypads = nullCostume("torso_jerseypads"),
    },
    legs = {
        pants       = nullCostume("legs_pants"),
        cleats      = nullCostume("legs_cleats"),
        pantscleats = nullCostume("legs_pantscleats"),
    },
}

-- Tuning ---------------------------------------------------------------------
local Cfg = {
    -- Football Helmet
    TACKLE_MIN_SPEED      = 2.5,   -- velocity needed to count as "running"
    TACKLE_STRAIGHTNESS   = 0.94,  -- dot product between frames to count as a straight line
    TACKLE_WINDUP         = 30,    -- frames of straight running before a tackle is live
    TACKLE_WINDUP_SUITED  = 15,
    TACKLE_REACH          = 28,    -- extra radius beyond the player's size
    TACKLE_DMG_MULT       = 3.0,
    TACKLE_DMG_FLAT       = 5.0,
    TACKLE_KNOCKBACK      = 14,
    TACKLE_CONFUSE        = 60,
    TACKLE_HIT_COOLDOWN   = 20,    -- frames before the same enemy can be tackled again
    FACEMASK_BLOCK_CHANCE = 0.5,
    FACEMASK_ARC          = 0.6,   -- dot product threshold for "in front of the face"

    -- Shoulder Pads
    PADS_DEFLECT_CHANCE   = 0.25,
    PADS_POP_RADIUS       = 120,
    PADS_POP_KNOCKBACK    = 12,

    -- Team Jersey
    JERSEY_SNAP_FREEZE    = 30,    -- "set" freeze on room entry
    JERSEY_BALL_DMG_MULT  = 2.0,
    JERSEY_BALL_SCALE     = 1.6,

    -- Football Cleats
    CLEATS_SPEED          = 0.2,
    YARD_UNITS            = 40,    -- world units per "yard"
    FIRST_DOWN_YARDS      = 10,
    MAX_FIRST_DOWNS       = 4,
    FIRST_DOWN_DAMAGE     = 0.5,

    -- Eye Black
    EYE_BLACK_LUCK        = 1,
    EYE_BLACK_RANGE_FULL  = 500,   -- tear travel distance for the full bonus
    EYE_BLACK_MAX_BONUS   = 0.5,

    -- Receiver Gloves
    GLOVES_CATCH_CHANCE   = 0.35,
    GLOVES_MAX_HELD       = 3,
    GLOVES_THROW_DMG      = 1.5,

    -- Mouthguard
    MOUTHGUARD_MIN_HIT    = 2,     -- hits of at least a full heart get reduced
    MOUTHGUARD_REDUCTION  = 1,     -- by half a heart

    -- Kicking Tee
    KICK_RANGE            = 300,
    KICK_FLIGHT           = 26,    -- frames in the air
    KICK_PEAK             = 70,    -- screen pixels at the top of the arc
    KICK_DAMAGE           = 40,
    KICK_DAMAGE_MULT      = 4,     -- + player damage x this
    KICK_RADIUS           = 85,
    KICK_RADIUS_MULT      = 1.2,
    FIELD_GOAL_COINS      = 3,

    -- Pigskin
    FUMBLE_RANGE          = 180,
    FUMBLE_FLIGHT         = 16,
    FUMBLE_PEAK           = 40,
    FUMBLE_TIME           = 150,   -- frames the ball stays on the ground
    FUMBLE_PULL_RADIUS    = 260,
    FUMBLE_PULL           = 0.9,
    FUMBLE_PICKUP_GRACE   = 15,
    TOUCHDOWN_DAMAGE      = 1.0,

    -- Padded Pants
    PANTS_IGNORE_CHANCE   = 0.25,  -- per trinket multiplier (golden / Mom's Box stack)
    PANTS_MAX_CHANCE      = 0.6,

    -- Set bonus
    SUITED_UP_PIECES      = 3,
    SUITED_UP_DAMAGE      = 1.0,
}
mod.Config = Cfg

local FOOTBALL_ANM2 = "gfx/gridiron_football_tear.anm2"
local SCREEN_PER_WORLD = 0.65 -- Isaac renders 40 world units per 26 screen pixels

-- Wearable gear counts toward Suited Up; the active items don't.
local GEAR = {
    Items.HELMET, Items.PADS, Items.JERSEY, Items.CLEATS, Items.EYE_BLACK,
    Items.GLOVES, Items.MOUTHGUARD,
}

local DIR_VECTORS = {
    [Direction.LEFT]  = Vector(-1, 0),
    [Direction.UP]    = Vector(0, -1),
    [Direction.RIGHT] = Vector(1, 0),
    [Direction.DOWN]  = Vector(0, 1),
}

-- Helpers --------------------------------------------------------------------
local function pdata(player)
    local d = player:GetData()
    d.Gridiron = d.Gridiron or { runFrames = 0, yardDist = 0, firstDowns = 0, shots = 0, caught = 0 }
    return d.Gridiron
end

local function forEachPlayer(fn)
    for i = 0, game:GetNumPlayers() - 1 do
        fn(Isaac.GetPlayer(i), i)
    end
end

local function anyPlayerHas(item)
    local found = false
    forEachPlayer(function(p) if p:HasCollectible(item) then found = true end end)
    return found
end

local function gearCount(player)
    local n = 0
    for _, item in ipairs(GEAR) do
        if item > 0 and player:HasCollectible(item) then n = n + 1 end
    end
    return n
end

local function isSuitedUp(player)
    return gearCount(player) >= Cfg.SUITED_UP_PIECES
end

local function rngFor(player, item)
    return player:GetCollectibleRNG(item)
end

local function isReflectionPass()
    return RenderMode ~= nil and game:GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT
end

local function refreshDamage(player)
    player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
    player:EvaluateItems()
end

-- Where the player "wants" to throw: shooting direction, then movement, then facing.
local function aimDirection(player)
    local aim = player:GetAimDirection()
    if aim:Length() > 0.1 then return aim:Normalized() end
    if player.Velocity:Length() > 1 then return player.Velocity:Normalized() end
    return DIR_VECTORS[player:GetHeadDirection()] or Vector(0, 1)
end

local function newFootballSprite()
    local s = Sprite()
    s:Load(FOOTBALL_ANM2, true)
    s:Play("Spiral", true)
    return s
end

-- Jersey number is fixed for the whole run (derived from the run seed).
local function jerseyNumber(player)
    local seed = game:GetSeeds():GetStartSeed()
    return (seed + player.ControllerIndex * 17) % 99 + 1
end

-- Every Nth shot becomes a thrown football; N comes from the jersey number.
local function footballInterval(number)
    return number % 7 + 3 -- 3..9
end

local function isContactDamage(source)
    if not source or not source.Entity then return false end
    if source.Type == EntityType.ENTITY_PROJECTILE then return false end
    local ent = source.Entity
    return ent:IsEnemy() and ent.Type < EntityType.ENTITY_EFFECT
end

-- Turn a tear into a thrown football (piercing, spectral, drawn as a spiral).
local function makeFootball(tear, dmgMult)
    tear.CollisionDamage = tear.CollisionDamage * dmgMult
    tear.Scale = tear.Scale * Cfg.JERSEY_BALL_SCALE
    tear:AddTearFlags(TearFlags.TEAR_PIERCING | TearFlags.TEAR_SPECTRAL)
    tear.Color = Color(0.55, 0.3, 0.15, 1, 0.1, 0.05, 0) -- tints the splash on impact
    tear:GetData().GridironFootball = newFootballSprite()
    tear:GetSprite().Color = Color(1, 1, 1, 0)
    sfx:Play(SoundEffect.SOUND_SHELLGAME, 0.6, 0, false, 1.3)
end

-- Shoulder Pads shockwave: shove enemies away and swat nearby shots.
local function padPop(player, origin, scale)
    scale = scale or 1
    local radius = Cfg.PADS_POP_RADIUS * scale
    for _, e in ipairs(Isaac.FindInRadius(origin, radius, EntityPartition.ENEMY)) do
        if e:IsVulnerableEnemy() and e:IsActiveEnemy(false) then
            local away = (e.Position - origin):Resized(Cfg.PADS_POP_KNOCKBACK * scale)
            if e:IsBoss() then away = away * 0.3 end
            e:AddVelocity(away)
            e:TakeDamage(player.Damage * scale, 0, EntityRef(player), 0)
        end
    end
    for _, b in ipairs(Isaac.FindInRadius(origin, radius * 0.8, EntityPartition.BULLET)) do
        local proj = b:ToProjectile()
        if proj and not proj:HasProjectileFlags(ProjectileFlags.CANT_HIT_PLAYER) then
            proj:Die()
        end
    end
    Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF02, 0, origin, Vector.Zero, player)
    sfx:Play(SoundEffect.SOUND_FORESTBOSS_STOMPS, 0.6 * scale + 0.2)
    game:ShakeScreen(math.floor(6 * scale))
end

-- Football Helmet: tackle ----------------------------------------------------
local function updateTackle(player, d)
    local vel = player.Velocity
    if vel:Length() > Cfg.TACKLE_MIN_SPEED then
        local dir = vel:Normalized()
        if d.runDir and d.runDir:Dot(dir) > Cfg.TACKLE_STRAIGHTNESS then
            d.runFrames = d.runFrames + 1
        else
            d.runFrames = 0
        end
        d.runDir = dir
    else
        d.runFrames = 0
        d.runDir = nil
    end

    local windup = isSuitedUp(player) and Cfg.TACKLE_WINDUP_SUITED or Cfg.TACKLE_WINDUP
    d.tackling = d.runDir ~= nil and d.runFrames >= windup
    if not d.tackling then return end

    -- Visual tell: helmet glows while a tackle is live.
    player:SetColor(Color(1, 1, 1, 1, 0.3, 0.18, 0), 2, 1, false, false)

    local now = game:GetFrameCount()
    local reach = player.Size + Cfg.TACKLE_REACH
    for _, e in ipairs(Isaac.FindInRadius(player.Position, reach, EntityPartition.ENEMY)) do
        if e:IsVulnerableEnemy() and e:IsActiveEnemy(false) then
            local ed = e:GetData()
            if (ed.GridironTackleCD or 0) <= now then
                ed.GridironTackleCD = now + Cfg.TACKLE_HIT_COOLDOWN
                local dmg = player.Damage * Cfg.TACKLE_DMG_MULT + Cfg.TACKLE_DMG_FLAT
                e:TakeDamage(dmg, 0, EntityRef(player), 0)
                local push = d.runDir * Cfg.TACKLE_KNOCKBACK
                if e:IsBoss() then push = push * 0.25 end
                e:AddVelocity(push)
                e:AddConfusion(EntityRef(player), Cfg.TACKLE_CONFUSE, true)
                sfx:Play(SoundEffect.SOUND_PUNCH)
                game:ShakeScreen(5)
                if player:HasCollectible(Items.PADS) then
                    padPop(player, e.Position, 0.6)
                end
            end
        end
    end
end

-- Football Cleats: yards and first downs -------------------------------------
local function updateCleats(player, d)
    local room = game:GetRoom()
    if room:IsClear() or d.firstDowns >= Cfg.MAX_FIRST_DOWNS then return end
    d.yardDist = d.yardDist + player.Velocity:Length()
    local needed = Cfg.YARD_UNITS * Cfg.FIRST_DOWN_YARDS
    if d.yardDist >= needed then
        d.yardDist = d.yardDist - needed
        d.firstDowns = d.firstDowns + 1
        refreshDamage(player)
        player:SetColor(Color(1, 1, 1, 1, 0.1, 0.4, 0.1), 10, 1, true, false)
        sfx:Play(SoundEffect.SOUND_THUMBSUP, 0.7)
    end
end

-- Costumes ---------------------------------------------------------------------
local function setSlotCostume(player, d, slot, key)
    local current = d.costumes[slot]
    if current == key then return end
    if current ~= "none" then player:TryRemoveNullCostume(Costumes[slot][current]) end
    if key ~= "none" then player:AddNullCostume(Costumes[slot][key]) end
    d.costumes[slot] = key
end

local function updateCostumes(player, d)
    if not d.costumes then
        -- Fresh data (new run or continue): clear anything left over, then re-apply.
        for _, group in pairs(Costumes) do
            for _, id in pairs(group) do player:TryRemoveNullCostume(id) end
        end
        d.costumes = { torso = "none", legs = "none" }
    end

    local jersey, pads = player:HasCollectible(Items.JERSEY), player:HasCollectible(Items.PADS)
    local torso = (jersey and pads and "jerseypads") or (jersey and "jersey") or (pads and "pads") or "none"

    local pants = Trinkets.PANTS > 0 and player:HasTrinket(Trinkets.PANTS)
    local cleats = player:HasCollectible(Items.CLEATS)
    local legs = (pants and cleats and "pantscleats") or (pants and "pants") or (cleats and "cleats") or "none"

    setSlotCostume(player, d, "torso", torso)
    setSlotCostume(player, d, "legs", legs)
end

-- Per-player update ----------------------------------------------------------
function mod:OnPeffectUpdate(player)
    local d = pdata(player)
    updateCostumes(player, d)

    -- Re-evaluate damage when the number of gear pieces changes (set bonus).
    local count = gearCount(player)
    if count ~= d.lastGearCount then
        if d.lastGearCount and count >= Cfg.SUITED_UP_PIECES and d.lastGearCount < Cfg.SUITED_UP_PIECES then
            game:GetHUD():ShowItemText("Suited Up!", "Ready for kickoff")
            sfx:Play(SoundEffect.SOUND_POWERUP_SPEWER)
        end
        d.lastGearCount = count
        refreshDamage(player)
    end

    -- Announce the jersey number the first time it's picked up.
    if player:HasCollectible(Items.JERSEY) and not d.jerseyShown then
        d.jerseyShown = true
        local num = jerseyNumber(player)
        game:GetHUD():ShowItemText("#" .. num, "Every " .. footballInterval(num) .. " shots: go long")
    end

    if player:HasCollectible(Items.HELMET) then
        updateTackle(player, d)
    else
        d.tackling = false
    end

    if player:HasCollectible(Items.CLEATS) then
        updateCleats(player, d)
    end

    -- Mouthguard: keep your head straight.
    if player:HasCollectible(Items.MOUTHGUARD) then
        local dazed = EntityFlag.FLAG_FEAR | EntityFlag.FLAG_CONFUSION
        if player:HasEntityFlags(dazed) then player:ClearEntityFlags(dazed) end
    end

    if not player:HasCollectible(Items.GLOVES) then
        d.caught = 0
    end
end
mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, mod.OnPeffectUpdate)

-- Stats ----------------------------------------------------------------------
function mod:OnEvaluateCache(player, flag)
    local d = pdata(player)
    if flag == CacheFlag.CACHE_DAMAGE then
        local bonus = 0
        if player:HasCollectible(Items.CLEATS) then
            bonus = bonus + d.firstDowns * Cfg.FIRST_DOWN_DAMAGE
        end
        if isSuitedUp(player) then
            bonus = bonus + Cfg.SUITED_UP_DAMAGE
        end
        if d.touchdown then
            bonus = bonus + Cfg.TOUCHDOWN_DAMAGE
        end
        player.Damage = player.Damage + bonus
    elseif flag == CacheFlag.CACHE_SPEED then
        player.MoveSpeed = player.MoveSpeed + player:GetCollectibleNum(Items.CLEATS) * Cfg.CLEATS_SPEED
    elseif flag == CacheFlag.CACHE_LUCK then
        player.Luck = player.Luck + player:GetCollectibleNum(Items.EYE_BLACK) * Cfg.EYE_BLACK_LUCK
    end
end
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, mod.OnEvaluateCache)

-- Kicking Tee / Pigskin: footballs in flight ----------------------------------
-- Balls are tracked in Lua and drawn in MC_POST_RENDER, so they can fly over
-- rocks and pits without being real entities.
local balls = {}

local function launchBall(kind, player)
    local dir = aimDirection(player)
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
        sprite = newFootballSprite(),
    }
    sfx:Play(kick and SoundEffect.SOUND_PUNCH or SoundEffect.SOUND_SHELLGAME, 0.9, 0, false, kick and 0.8 or 1)
end

local kickExploding = false

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

    kickExploding = true
    game:BombExplosionEffects(ball.pos, dmg, TearFlags.TEAR_NORMAL, Color.Default, player,
        Cfg.KICK_RADIUS_MULT, true, false, DamageFlag.DAMAGE_EXPLOSION)
    kickExploding = false

    if good then
        local rng = rngFor(player, Items.KICKING_TEE)
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
        refreshDamage(player)
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

-- New room: reset per-room bonuses, Team Jersey pre-snap freeze --------------
function mod:OnNewRoom()
    balls = {}
    forEachPlayer(function(player)
        local d = pdata(player)
        d.runFrames = 0
        d.runDir = nil
        d.tackling = false
        d.guardUsed = false
        if d.firstDowns > 0 or d.yardDist > 0 or d.touchdown then
            d.firstDowns = 0
            d.yardDist = 0
            d.touchdown = false
            refreshDamage(player)
        end
    end)

    local room = game:GetRoom()
    if room:IsClear() then return end
    local snapper
    forEachPlayer(function(p) if not snapper and p:HasCollectible(Items.JERSEY) then snapper = p end end)
    if not snapper then return end

    local froze = false
    for _, e in ipairs(Isaac.GetRoomEntities()) do
        if e:IsActiveEnemy(false) and e:IsVulnerableEnemy() then
            local duration = e:IsBoss() and math.floor(Cfg.JERSEY_SNAP_FREEZE / 2) or Cfg.JERSEY_SNAP_FREEZE
            e:AddFreeze(EntityRef(snapper), duration)
            froze = true
        end
    end
    if froze then
        sfx:Play(SoundEffect.SOUND_BUTTON_PRESS, 0.8)
    end
end
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.OnNewRoom)

function mod:OnGameExit()
    balls = {}
end
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.OnGameExit)

-- Tears: footballs (Team Jersey, Receiver Gloves), Eye Black origin ----------
local throwingCaught = false

function mod:OnFireTear(tear)
    if throwingCaught then return end
    local player = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
    if not player then return end
    local d = pdata(player)

    if player:HasCollectible(Items.EYE_BLACK) then
        tear:GetData().GridironOrigin = tear.Position
    end

    if player:HasCollectible(Items.JERSEY) then
        d.shots = d.shots + 1
        if d.shots % footballInterval(jerseyNumber(player)) == 0 then
            makeFootball(tear, Cfg.JERSEY_BALL_DMG_MULT)
        end
    end

    -- Receiver Gloves: throw back one caught shot alongside this tear.
    if d.caught > 0 and player:HasCollectible(Items.GLOVES) then
        d.caught = d.caught - 1
        local spread = rngFor(player, Items.GLOVES):RandomInt(21) - 10
        throwingCaught = true
        local extra = player:FireTear(player.Position, tear.Velocity:Rotated(spread) * 1.1,
            false, true, false, player, Cfg.GLOVES_THROW_DMG)
        throwingCaught = false
        if extra then
            if player:HasCollectible(Items.EYE_BLACK) then
                extra:GetData().GridironOrigin = extra.Position
            end
            makeFootball(extra, 1)
        end
    end
end
mod:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, mod.OnFireTear)

-- Football tears: hide the vanilla tear and draw a spiraling ball instead.
function mod:OnTearUpdate(tear)
    local ball = tear:GetData().GridironFootball
    if not ball then return end
    tear:GetSprite().Color = Color(1, 1, 1, 0)
    ball:Update()
    if tear.Velocity:Length() > 0.1 then
        ball.Rotation = tear.Velocity:GetAngleDegrees()
    end
end
mod:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, mod.OnTearUpdate)

function mod:OnTearRender(tear, renderOffset)
    local ball = tear:GetData().GridironFootball
    if not ball or isReflectionPass() then return end
    local s = math.max(tear.Scale, 0.6)
    ball.Scale = Vector(s, s)
    ball:Render(Isaac.WorldToScreen(tear.Position + tear.PositionOffset) + renderOffset)
end
mod:AddCallback(ModCallbacks.MC_POST_TEAR_RENDER, mod.OnTearRender)

-- Receiver Gloves: show the balls you're holding above your head.
local heldBall

function mod:OnPlayerRender(player, renderOffset)
    local d = pdata(player)
    if d.caught <= 0 or isReflectionPass() then return end
    if not heldBall then
        heldBall = newFootballSprite()
        heldBall:SetFrame("Spiral", 0)
        heldBall.Scale = Vector(0.6, 0.6)
    end
    local base = Isaac.WorldToScreen(player.Position) + renderOffset + Vector(0, -44)
    for i = 1, d.caught do
        heldBall:Render(base + Vector((i - (d.caught + 1) / 2) * 9, 0))
    end
end
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, mod.OnPlayerRender)

-- Projectiles: glove catches, facemask blocks, shoulder pad deflections ------
function mod:OnProjectileCollision(proj, collider)
    local player = collider and collider:ToPlayer()
    if not player then return end
    if proj:HasProjectileFlags(ProjectileFlags.CANT_HIT_PLAYER) then return end
    local d = pdata(player)

    -- Hands are free only when you're not shooting.
    if player:HasCollectible(Items.GLOVES) and d.caught < Cfg.GLOVES_MAX_HELD
        and player:GetAimDirection():Length() < 0.1 then
        if rngFor(player, Items.GLOVES):RandomFloat() < Cfg.GLOVES_CATCH_CHANCE then
            proj:Remove()
            d.caught = d.caught + 1
            sfx:Play(SoundEffect.SOUND_PLOP, 1.2)
            player:SetColor(Color(1, 1, 1, 1, 0.3, 0.3, 0.3), 6, 1, true, false)
            return true
        end
    end

    if player:HasCollectible(Items.HELMET) then
        local face = DIR_VECTORS[player:GetHeadDirection()]
        local toProj = proj.Position - player.Position
        if face and toProj:Length() > 0.01 and face:Dot(toProj:Normalized()) > Cfg.FACEMASK_ARC then
            if rngFor(player, Items.HELMET):RandomFloat() < Cfg.FACEMASK_BLOCK_CHANCE then
                proj:Die()
                sfx:Play(SoundEffect.SOUND_TEARIMPACTS, 1.2)
                return true
            end
        end
    end

    if player:HasCollectible(Items.PADS) then
        if rngFor(player, Items.PADS):RandomFloat() < Cfg.PADS_DEFLECT_CHANCE then
            proj.Velocity = proj.Velocity * -1.3
            proj:AddProjectileFlags(ProjectileFlags.HIT_ENEMIES | ProjectileFlags.CANT_HIT_PLAYER)
            proj.Color = Color(0.5, 0.7, 1, 1, 0, 0, 0.2)
            sfx:Play(SoundEffect.SOUND_PUNCH, 0.6)
            return true
        end
    end
end
mod:AddCallback(ModCallbacks.MC_PRE_PROJECTILE_COLLISION, mod.OnProjectileCollision)

-- Damage ---------------------------------------------------------------------
local reapplyingEnemy = false
local reapplyingPlayer = false

function mod:OnPlayerDamage(entity, amount, flags, source, countdown)
    local player = entity:ToPlayer()
    if not player then return end
    local d = pdata(player)
    local contact = isContactDamage(source)

    -- Your own field goal doesn't blow you up.
    if kickExploding then
        return false
    end

    -- Mid-tackle you are the one doing the hitting.
    if contact and d.tackling then
        return false
    end

    -- Padded Pants: shrug off some contact hits.
    if contact and Trinkets.PANTS > 0 and player:HasTrinket(Trinkets.PANTS) then
        local chance = math.min(Cfg.PANTS_MAX_CHANCE,
            Cfg.PANTS_IGNORE_CHANCE * player:GetTrinketMultiplier(Trinkets.PANTS))
        if player:GetTrinketRNG(Trinkets.PANTS):RandomFloat() < chance then
            player:SetMinDamageCooldown(30)
            sfx:Play(SoundEffect.SOUND_PUNCH, 0.5)
            return false
        end
    end

    -- Mouthguard: the first big hit each room only takes half a heart less.
    if not reapplyingPlayer and not d.guardUsed and amount >= Cfg.MOUTHGUARD_MIN_HIT
        and player:HasCollectible(Items.MOUTHGUARD) then
        d.guardUsed = true
        reapplyingPlayer = true
        player:TakeDamage(amount - Cfg.MOUTHGUARD_REDUCTION, flags, source, countdown)
        reapplyingPlayer = false
        sfx:Play(SoundEffect.SOUND_TEARIMPACTS, 0.8, 0, false, 0.7)
        return false
    end

    -- Shoulder Pads: the hit lands, but you pop everything around you.
    if player:HasCollectible(Items.PADS) then
        padPop(player, player.Position, 1)
    end
end
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.OnPlayerDamage, EntityType.ENTITY_PLAYER)

-- Eye Black: tears hit harder the farther they travel.
function mod:OnEnemyDamage(entity, amount, flags, source, countdown)
    if reapplyingEnemy then return end
    if not entity:IsVulnerableEnemy() then return end
    if not source or source.Type ~= EntityType.ENTITY_TEAR or not source.Entity then return end

    local origin = source.Entity:GetData().GridironOrigin
    if not origin then return end
    local dist = (source.Entity.Position - origin):Length()
    local bonus = math.min(dist / Cfg.EYE_BLACK_RANGE_FULL, 1) * Cfg.EYE_BLACK_MAX_BONUS
    if bonus < 0.05 then return end

    reapplyingEnemy = true
    entity:TakeDamage(amount * (1 + bonus), flags, source, countdown)
    reapplyingEnemy = false
    return false
end
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.OnEnemyDamage)

-- Eye Black: no Curse of Darkness.
function mod:OnCurseEval(curses)
    if anyPlayerHas(Items.EYE_BLACK) and curses & LevelCurse.CURSE_OF_DARKNESS ~= 0 then
        return curses & ~LevelCurse.CURSE_OF_DARKNESS
    end
end
mod:AddCallback(ModCallbacks.MC_POST_CURSE_EVAL, mod.OnCurseEval)

-- External Item Descriptions support -----------------------------------------
if EID then
    EID:addCollectible(Items.HELMET,
        "Run in a straight line for 1 second to start a tackle (Isaac glows)#" ..
        "Tackling an enemy deals 3x damage +5, knocks it back and confuses it#" ..
        "No contact damage while tackling#" ..
        "Facemask: 50% chance to block shots that hit you from the direction you're facing")
    EID:addCollectible(Items.PADS,
        "25% chance to deflect enemy shots back at enemies#" ..
        "Taking damage releases a shockwave that shoves enemies and destroys nearby shots#" ..
        "Tackles (Football Helmet) also cause a smaller shockwave")
    EID:addCollectible(Items.JERSEY,
        "You get a jersey number for the run#" ..
        "Every 3-9 shots (based on your number) you throw a football: 2x damage, piercing, spectral#" ..
        "Enemies freeze for a moment when you enter a room (pre-snap)")
    EID:addCollectible(Items.CLEATS,
        "↑ +0.2 Speed#" ..
        "Running 10 yards in an uncleared room earns a First Down: +0.5 Damage for the room (up to 4)")
    EID:addCollectible(Items.EYE_BLACK,
        "↑ +1 Luck#" ..
        "Tears deal up to +50% damage the farther they travel#" ..
        "Immune to Curse of Darkness")
    EID:addCollectible(Items.GLOVES,
        "While not shooting, 35% chance to catch enemy shots instead of getting hit (hold up to 3)#" ..
        "Each shot you fire throws one caught ball back as a football: 1.5x damage, piercing, spectral")
    EID:addCollectible(Items.MOUTHGUARD,
        "The first hit each room that deals a full heart or more deals half a heart less#" ..
        "Immune to fear and confusion")
    EID:addCollectible(Items.KICKING_TEE,
        "Punt a football in the direction you're aiming; it sails over obstacles#" ..
        "Explodes on landing for 40 + 4x your damage (doesn't hurt you)#" ..
        "If the blast kills an enemy: Field goal! Spawns 3 pennies")
    EID:addCollectible(Items.PIGSKIN,
        "Throw a fumble that sits on the ground for 5 seconds#" ..
        "Non-boss enemies scramble toward it and get confused#" ..
        "Recover it for a Touchdown: +1 Damage for the room")
    EID:addTrinket(Trinkets.PANTS,
        "25% chance to ignore damage from touching enemies#Stacks with golden/Mom's Box (up to 60%)")
end
