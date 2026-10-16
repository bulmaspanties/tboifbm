-- Gridiron: American football gear for The Binding of Isaac: Repentance+
-- Uses only the vanilla Lua API (REPENTOGON not required).

local mod = RegisterMod("Gridiron", 1)
local game = Game()
local sfx = SFXManager()

local Items = {
    HELMET    = Isaac.GetItemIdByName("Football Helmet"),
    PADS      = Isaac.GetItemIdByName("Shoulder Pads"),
    JERSEY    = Isaac.GetItemIdByName("Team Jersey"),
    CLEATS    = Isaac.GetItemIdByName("Football Cleats"),
    EYE_BLACK = Isaac.GetItemIdByName("Eye Black"),
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

    -- Padded Pants
    PANTS_IGNORE_CHANCE   = 0.25,  -- per trinket multiplier (golden / Mom's Box stack)
    PANTS_MAX_CHANCE      = 0.6,

    -- Set bonus
    SUITED_UP_PIECES      = 3,
    SUITED_UP_DAMAGE      = 1.0,
}
mod.Config = Cfg

local GEAR = { Items.HELMET, Items.PADS, Items.JERSEY, Items.CLEATS, Items.EYE_BLACK }

local DIR_VECTORS = {
    [Direction.LEFT]  = Vector(-1, 0),
    [Direction.UP]    = Vector(0, -1),
    [Direction.RIGHT] = Vector(1, 0),
    [Direction.DOWN]  = Vector(0, 1),
}

-- Helpers --------------------------------------------------------------------
local function pdata(player)
    local d = player:GetData()
    d.Gridiron = d.Gridiron or { runFrames = 0, yardDist = 0, firstDowns = 0, shots = 0 }
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
        player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
        player:EvaluateItems()
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
        player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
        player:EvaluateItems()
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
        player.Damage = player.Damage + bonus
    elseif flag == CacheFlag.CACHE_SPEED then
        player.MoveSpeed = player.MoveSpeed + player:GetCollectibleNum(Items.CLEATS) * Cfg.CLEATS_SPEED
    elseif flag == CacheFlag.CACHE_LUCK then
        player.Luck = player.Luck + player:GetCollectibleNum(Items.EYE_BLACK) * Cfg.EYE_BLACK_LUCK
    end
end
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, mod.OnEvaluateCache)

-- New room: reset downs, Team Jersey pre-snap freeze -------------------------
function mod:OnNewRoom()
    forEachPlayer(function(player)
        local d = pdata(player)
        d.runFrames = 0
        d.runDir = nil
        d.tackling = false
        if d.firstDowns > 0 or d.yardDist > 0 then
            d.firstDowns = 0
            d.yardDist = 0
            player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
            player:EvaluateItems()
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

-- Tears: Team Jersey footballs, Eye Black origin tracking --------------------
function mod:OnFireTear(tear)
    local player = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
    if not player then return end

    if player:HasCollectible(Items.EYE_BLACK) then
        tear:GetData().GridironOrigin = tear.Position
    end

    if player:HasCollectible(Items.JERSEY) then
        local d = pdata(player)
        d.shots = d.shots + 1
        if d.shots % footballInterval(jerseyNumber(player)) == 0 then
            tear.CollisionDamage = tear.CollisionDamage * Cfg.JERSEY_BALL_DMG_MULT
            tear.Scale = tear.Scale * Cfg.JERSEY_BALL_SCALE
            tear:AddTearFlags(TearFlags.TEAR_PIERCING | TearFlags.TEAR_SPECTRAL)
            tear.Color = Color(0.55, 0.3, 0.15, 1, 0.1, 0.05, 0)
            tear:GetData().GridironFootball = true
        end
    end
end
mod:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, mod.OnFireTear)

-- Projectiles: facemask blocks, shoulder pad deflections ---------------------
function mod:OnProjectileCollision(proj, collider)
    local player = collider and collider:ToPlayer()
    if not player then return end
    if proj:HasProjectileFlags(ProjectileFlags.CANT_HIT_PLAYER) then return end

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
local reapplying = false

function mod:OnPlayerDamage(entity, amount, flags, source, countdown)
    local player = entity:ToPlayer()
    if not player then return end
    local d = pdata(player)
    local contact = isContactDamage(source)

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

    -- Shoulder Pads: the hit lands, but you pop everything around you.
    if player:HasCollectible(Items.PADS) then
        padPop(player, player.Position, 1)
    end
end
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.OnPlayerDamage, EntityType.ENTITY_PLAYER)

-- Eye Black: tears hit harder the farther they travel.
function mod:OnEnemyDamage(entity, amount, flags, source, countdown)
    if reapplying then return end
    if not entity:IsVulnerableEnemy() then return end
    if not source or source.Type ~= EntityType.ENTITY_TEAR or not source.Entity then return end

    local origin = source.Entity:GetData().GridironOrigin
    if not origin then return end
    local dist = (source.Entity.Position - origin):Length()
    local bonus = math.min(dist / Cfg.EYE_BLACK_RANGE_FULL, 1) * Cfg.EYE_BLACK_MAX_BONUS
    if bonus < 0.05 then return end

    reapplying = true
    entity:TakeDamage(amount * (1 + bonus), flags, source, countdown)
    reapplying = false
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
    EID:addTrinket(Trinkets.PANTS,
        "25% chance to ignore damage from touching enemies#Stacks with golden/Mom's Box (up to 60%)")
end
