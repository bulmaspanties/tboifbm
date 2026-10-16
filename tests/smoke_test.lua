-- Smoke test: runs main.lua against a mock of the Isaac Lua API.
-- It can't prove game feel, but it catches typos, nil errors and broken
-- callback wiring, and checks that item names / costume paths / sprite paths
-- line up with the XML and files on disk.
--
-- Run from the repo root with Lua 5.3+:   lua tests/smoke_test.lua

local failures, checks = 0, 0
local function check(cond, msg)
    checks = checks + 1
    if not cond then
        failures = failures + 1
        print("FAIL: " .. msg)
    end
end

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("a")
    f:close()
    return s
end

-- XML-derived lookups -----------------------------------------------------------
local itemsXml = assert(readFile("content/items.xml"), "run from the repo root")
local itemIds, trinketIds, nextId = {}, {}, 1000
for tag, attrs in itemsXml:gmatch("<(%a+)%s+(.-)/>") do
    local name = attrs:match('name="(.-)"')
    if name then
        nextId = nextId + 1
        if tag == "trinket" then trinketIds[name] = nextId else itemIds[name] = nextId end
    end
end

local costumesXml = assert(readFile("content/costumes2.xml"))
local costumePaths, costumeCount = {}, 0
for path in costumesXml:gmatch('anm2path="(.-)"') do
    costumeCount = costumeCount + 1
    costumePaths["gfx/" .. path] = costumeCount
    check(readFile("resources/gfx/" .. path) ~= nil, "costume anm2 missing: " .. path)
end

-- Enums: every unknown key gets a fresh power of two so bit ops behave ----------
local bit = 0
local function enum(fixed)
    return setmetatable(fixed or {}, { __index = function(t, k)
        bit = (bit % 60) + 1
        rawset(t, k, 1 << bit)
        return t[k]
    end })
end

ModCallbacks = enum()
CacheFlag = enum()
EntityPartition = enum()
EntityFlag = enum()
ProjectileFlags = enum()
TearFlags = enum({ TEAR_NORMAL = 0 })
LevelCurse = enum()
SoundEffect = enum()
EffectVariant = enum()
PickupVariant = enum()
CoinSubType = enum()
DamageFlag = enum()
RenderMode = enum()
Direction = { LEFT = 0, UP = 1, RIGHT = 2, DOWN = 3 }
EntityType = { ENTITY_PLAYER = 1, ENTITY_TEAR = 2, ENTITY_PROJECTILE = 9, ENTITY_PICKUP = 5,
    ENTITY_EFFECT = 1000, ENTITY_GAPER = 10 }

-- Vector / Color ------------------------------------------------------------------
local VMT = {}
VMT.__index = VMT
Vector = setmetatable({}, { __call = function(_, x, y) return setmetatable({ X = x, Y = y }, VMT) end })
VMT.__add = function(a, b) return Vector(a.X + b.X, a.Y + b.Y) end
VMT.__sub = function(a, b) return Vector(a.X - b.X, a.Y - b.Y) end
VMT.__unm = function(a) return Vector(-a.X, -a.Y) end
VMT.__mul = function(a, b)
    if type(a) == "number" then a, b = b, a end
    assert(type(b) == "number", "Vector * non-number")
    return Vector(a.X * b, a.Y * b)
end
function VMT:Length() return math.sqrt(self.X * self.X + self.Y * self.Y) end
function VMT:Normalized() local l = self:Length(); if l == 0 then return Vector(0, 0) end return Vector(self.X / l, self.Y / l) end
function VMT:Resized(n) return self:Normalized() * n end
function VMT:Dot(o) return self.X * o.X + self.Y * o.Y end
function VMT:GetAngleDegrees() return math.deg(math.atan(self.Y, self.X)) end
function VMT:Rotated(deg)
    local r = math.rad(deg)
    return Vector(self.X * math.cos(r) - self.Y * math.sin(r), self.X * math.sin(r) + self.Y * math.cos(r))
end
Vector.Zero = Vector(0, 0)
function Vector.FromAngle(deg) return Vector(math.cos(math.rad(deg)), math.sin(math.rad(deg))) end

Color = setmetatable({}, { __call = function(_, r, g, b, a) return { R = r, G = g, B = b, A = a or 1 } end })
Color.Default = Color(1, 1, 1, 1)

-- Sprites: Load/Play must point at real files and animation names ----------------
local function anm2Animations(path)
    local xml = readFile("resources/" .. path)
    if not xml then return nil end
    local anims = {}
    for name in xml:gmatch('<Animation Name="(.-)"') do anims[name] = true end
    for sheet in xml:gmatch('Spritesheet Path="(.-)"') do
        local dir = path:match("^(.*)/") or ""
        check(readFile("resources/" .. dir .. "/" .. sheet) ~= nil, "spritesheet missing: " .. sheet .. " for " .. path)
    end
    return anims
end

function Sprite()
    local s = { Rotation = 0, Scale = Vector(1, 1), Color = Color(1, 1, 1, 1), renders = 0 }
    function s:Load(path) self.anims = anm2Animations(path); check(self.anims ~= nil, "anm2 missing: " .. path) end
    function s:Play(name) check(self.anims and self.anims[name], "animation missing: " .. tostring(name)) end
    function s:SetFrame(name) check(self.anims and self.anims[name], "animation missing: " .. tostring(name)) end
    function s:Update() end
    function s:Render(pos) assert(getmetatable(pos) == VMT, "Render needs a Vector"); self.renders = self.renders + 1 end
    return s
end

-- World -------------------------------------------------------------------------------
local world = { entities = {}, frame = 0, roomClear = false, spawned = {}, hudText = {} }
local mod -- set by RegisterMod

local function dispatch(cb, filter, ...)
    local result
    for _, entry in ipairs(mod.callbacks[cb] or {}) do
        if entry.filter == nil or entry.filter == filter then
            local r = entry.fn(mod, ...)
            if r ~= nil and result == nil then result = r end
        end
    end
    return result
end

local function newRng(value)
    return { value = value or 0.0,
        RandomFloat = function(self) return self.value end,
        RandomInt = function(_, max) return math.floor(max / 2) end }
end

local function newEntity(t)
    local e = t or {}
    e.Position = e.Position or Vector(0, 0)
    e.Velocity = e.Velocity or Vector(0, 0)
    e.PositionOffset = e.PositionOffset or Vector(0, 0)
    e.Size = e.Size or 10
    e.HitPoints = e.HitPoints or 10
    e.flags = 0
    e.data = {}
    e.sprite = Sprite()
    e.exists = true
    e.damageTaken = 0
    function e:GetData() return self.data end
    function e:GetSprite() return self.sprite end
    function e:ToPlayer() return self.isPlayer and self or nil end
    function e:ToProjectile() return self.isProjectile and self or nil end
    function e:IsEnemy() return self.isEnemy == true end
    function e:IsVulnerableEnemy() return self.isEnemy == true end
    function e:IsActiveEnemy() return self.isEnemy == true and self.exists end
    function e:IsBoss() return self.boss == true end
    function e:Exists() return self.exists end
    function e:AddVelocity(v) self.Velocity = self.Velocity + v end
    function e:AddConfusion() self.confused = true end
    function e:AddFreeze() self.frozen = true end
    function e:SetColor() end
    function e:HasEntityFlags(f) return self.flags & f ~= 0 end
    function e:ClearEntityFlags(f) self.flags = self.flags & ~f end
    function e:Die() self.exists = false end
    function e:Remove() self.exists = false end
    function e:TakeDamage(amount, flags, source, countdown)
        local r = dispatch(ModCallbacks.MC_ENTITY_TAKE_DMG, self.Type, self, amount, flags, source, countdown)
        if r == false then return false end
        self.damageTaken = self.damageTaken + amount
        self.HitPoints = self.HitPoints - amount
        return true
    end
    world.entities[#world.entities + 1] = e
    return e
end

function EntityRef(e) return { Entity = e, Type = e and e.Type } end

local function newPlayer()
    local p = newEntity({ isPlayer = true, Type = EntityType.ENTITY_PLAYER, Size = 10, Damage = 3.5,
        MoveSpeed = 1, Luck = 0, ControllerIndex = 0 })
    p.items, p.trinkets, p.nullCostumes, p.aim = {}, {}, {}, Vector(0, 0)
    p.rng = newRng(0.0)
    function p:HasCollectible(id) return (self.items[id] or 0) > 0 end
    function p:GetCollectibleNum(id) return self.items[id] or 0 end
    function p:HasTrinket(id) return self.trinkets[id] == true end
    function p:GetTrinketMultiplier() return 1 end
    function p:GetTrinketRNG() return self.rng end
    function p:GetCollectibleRNG() return self.rng end
    function p:GetHeadDirection() return Direction.DOWN end
    function p:GetAimDirection() return self.aim end
    function p:SetMinDamageCooldown() end
    function p:AddNullCostume(id) check(type(id) == "number" and id > 0, "bad null costume id"); self.nullCostumes[id] = true end
    function p:TryRemoveNullCostume(id) self.nullCostumes[id] = nil end
    function p:AddCacheFlags(f) self.pendingCache = (self.pendingCache or 0) | f end
    function p:EvaluateItems()
        self.Damage, self.MoveSpeed, self.Luck = 3.5, 1, 0
        for _, flag in ipairs({ CacheFlag.CACHE_DAMAGE, CacheFlag.CACHE_SPEED, CacheFlag.CACHE_LUCK }) do
            dispatch(ModCallbacks.MC_EVALUATE_CACHE, nil, self, flag)
        end
        self.pendingCache = 0
    end
    function p:FireTear(pos, vel, _, _, _, _, mult)
        local t = newEntity({ Type = EntityType.ENTITY_TEAR, Position = pos, Velocity = vel,
            CollisionDamage = 3.5 * (mult or 1), Scale = 1, SpawnerEntity = self })
        function t:AddTearFlags(f) self.tearFlags = (self.tearFlags or 0) | f end
        return t
    end
    return p
end

local function newEnemy(pos, hp)
    return newEntity({ isEnemy = true, Type = EntityType.ENTITY_GAPER, Position = pos, HitPoints = hp or 10 })
end

local function newProjectile(pos)
    local pr = newEntity({ isProjectile = true, Type = EntityType.ENTITY_PROJECTILE, Position = pos })
    pr.pflags = 0
    function pr:HasProjectileFlags(f) return self.pflags & f ~= 0 end
    function pr:AddProjectileFlags(f) self.pflags = self.pflags | f end
    return pr
end

local players = {}

-- Global API ---------------------------------------------------------------------
function RegisterMod(name)
    mod = { Name = name, callbacks = {} }
    function mod:AddCallback(cb, fn, filter)
        assert(cb ~= nil, "AddCallback with nil callback id")
        assert(type(fn) == "function", "AddCallback with non-function")
        self.callbacks[cb] = self.callbacks[cb] or {}
        table.insert(self.callbacks[cb], { fn = fn, filter = filter })
    end
    return mod
end

local room = {
    IsClear = function() return world.roomClear end,
    GetClampedPosition = function(_, pos) return pos end,
    GetRenderMode = function() return 0 end,
}
local hud = { ShowItemText = function(_, a, b) world.hudText[#world.hudText + 1] = a end }

function Game()
    return {
        GetNumPlayers = function() return #players end,
        GetRoom = function() return room end,
        GetHUD = function() return hud end,
        GetSeeds = function() return { GetStartSeed = function() return 123456 end } end,
        GetFrameCount = function() return world.frame end,
        ShakeScreen = function() end,
        BombExplosionEffects = function(_, pos, dmg, _, _, source)
            for _, e in ipairs(world.entities) do
                if e.exists and (e.isEnemy or e.isPlayer) and (e.Position - pos):Length() < 100 then
                    e:TakeDamage(dmg, 0, EntityRef(source), 0)
                end
            end
        end,
    }
end
function SFXManager() return { Play = function() end } end

Isaac = {
    GetItemIdByName = function(name) return itemIds[name] or -1 end,
    GetTrinketIdByName = function(name) return trinketIds[name] or -1 end,
    GetCostumeIdByPath = function(path) return costumePaths[path] or -1 end,
    GetPlayer = function(i) return players[i + 1] end,
    GetRoomEntities = function()
        local list = {}
        for _, e in ipairs(world.entities) do if e.exists then list[#list + 1] = e end end
        return list
    end,
    FindInRadius = function(pos, radius, partition)
        local list = {}
        for _, e in ipairs(world.entities) do
            local match = (partition == EntityPartition.ENEMY and e.isEnemy)
                or (partition == EntityPartition.BULLET and e.isProjectile)
            if e.exists and match and (e.Position - pos):Length() <= radius then list[#list + 1] = e end
        end
        return list
    end,
    Spawn = function(type, variant, subtype, pos)
        local e = newEntity({ Type = type, Variant = variant, SubType = subtype, Position = pos })
        world.spawned[#world.spawned + 1] = e
        return e
    end,
    WorldToScreen = function(pos) return pos * 0.65 end,
}

local eidEntries = 0
EID = {
    addCollectible = function(_, id) check(id and id > 0, "EID for unknown collectible"); eidEntries = eidEntries + 1 end,
    addTrinket = function(_, id) check(id and id > 0, "EID for unknown trinket"); eidEntries = eidEntries + 1 end,
}

-- Load the mod ------------------------------------------------------------------------
dofile("main.lua")
local Items, Trinkets, Cfg = mod.Items, mod.Trinkets, mod.Config

for key, id in pairs(Items) do check(id > 0, "item name not found in items.xml: " .. key) end
for key, id in pairs(Trinkets) do check(id > 0, "trinket name not found in items.xml: " .. key) end
local itemCount = 0
for _ in pairs(itemIds) do itemCount = itemCount + 1 end
check(eidEntries == itemCount + 1, "every item and trinket has an EID description")

local function tick(n)
    for _ = 1, n or 1 do
        world.frame = world.frame + 1
        for _, p in ipairs(players) do dispatch(ModCallbacks.MC_POST_PEFFECT_UPDATE, nil, p) end
        dispatch(ModCallbacks.MC_POST_UPDATE)
        dispatch(ModCallbacks.MC_POST_RENDER)
        for _, p in ipairs(players) do dispatch(ModCallbacks.MC_POST_PLAYER_RENDER, nil, p, Vector(0, 0)) end
    end
end

local function newRoom(clear)
    world.entities = {}
    for _, p in ipairs(players) do world.entities[#world.entities + 1] = p end
    world.roomClear = clear
end

-- Scenarios -------------------------------------------------------------------------
local p = newPlayer()
players[1] = p
newRoom(true)
tick()

-- costumes follow gear
p.items[Items.JERSEY] = 1
p.items[Items.PADS] = 1
p.trinkets[Trinkets.PANTS] = true
tick()
check(p.nullCostumes[costumePaths["gfx/characters/gridiron_torso_jerseypads.anm2"]], "jersey+pads costume applied")
check(p.nullCostumes[costumePaths["gfx/characters/gridiron_legs_pants.anm2"]], "pants costume applied")
p.items[Items.CLEATS] = 1
tick()
check(p.nullCostumes[costumePaths["gfx/characters/gridiron_legs_pantscleats.anm2"]], "pants+cleats costume applied")
check(not p.nullCostumes[costumePaths["gfx/characters/gridiron_legs_pants.anm2"]], "old legs costume removed")

-- Suited Up (3 pieces) and stats
p:EvaluateItems()
check(math.abs(p.Damage - (3.5 + Cfg.SUITED_UP_DAMAGE)) < 1e-6, "Suited Up damage bonus")
check(math.abs(p.MoveSpeed - (1 + Cfg.CLEATS_SPEED)) < 1e-6, "Cleats speed")
p.items[Items.EYE_BLACK] = 1
p:EvaluateItems()
check(p.Luck == Cfg.EYE_BLACK_LUCK, "Eye Black luck")

-- Team Jersey pre-snap freeze
newRoom(false)
local frozen = newEnemy(Vector(200, 0))
dispatch(ModCallbacks.MC_POST_NEW_ROOM)
check(frozen.frozen, "pre-snap freeze on room entry")

-- Cleats first downs
p.Velocity = Vector(5, 0)
tick(Cfg.YARD_UNITS * Cfg.FIRST_DOWN_YARDS / 5 + 1)
p:EvaluateItems()
check(p.Damage > 3.5 + Cfg.SUITED_UP_DAMAGE, "first down adds damage")
dispatch(ModCallbacks.MC_POST_NEW_ROOM)
p:EvaluateItems()
check(math.abs(p.Damage - (3.5 + Cfg.SUITED_UP_DAMAGE)) < 1e-6, "first downs reset on new room")

-- Helmet tackle
newRoom(false)
p.items[Items.HELMET] = 1
p.Position, p.Velocity = Vector(0, 0), Vector(5, 0)
tick(Cfg.TACKLE_WINDUP_SUITED + 2)
local victim = newEnemy(p.Position + Vector(20, 0), 100)
tick()
check(victim.damageTaken > 0 and victim.confused, "tackle damages and confuses")
local contact = newEnemy(p.Position)
check(dispatch(ModCallbacks.MC_ENTITY_TAKE_DMG, EntityType.ENTITY_PLAYER, p, 1, 0, EntityRef(contact), 0) == false,
    "no contact damage while tackling")
p.Velocity = Vector(0, 0)
tick()

-- Team Jersey footballs
local footballs = 0
for _ = 1, 9 do
    local t = p:FireTear(p.Position, Vector(10, 0))
    dispatch(ModCallbacks.MC_POST_FIRE_TEAR, nil, t)
    if t.data.GridironFootball then
        footballs = footballs + 1
        dispatch(ModCallbacks.MC_POST_TEAR_UPDATE, nil, t)
        dispatch(ModCallbacks.MC_POST_TEAR_RENDER, nil, t, Vector(0, 0))
        check(t.data.GridironFootball.renders == 1, "football tear renders")
    end
end
check(footballs >= 1, "jersey throws at least one football in 9 shots")

-- Eye Black range bonus
local far = newEnemy(Vector(600, 0), 100)
local tear = p:FireTear(Vector(0, 0), Vector(10, 0))
dispatch(ModCallbacks.MC_POST_FIRE_TEAR, nil, tear)
tear.Position = Vector(590, 0)
far:TakeDamage(10, 0, EntityRef(tear), 0)
check(far.damageTaken > 10, "eye black boosts long-range hits")

-- Receiver Gloves catch + throw back
p.items[Items.GLOVES] = 1
p.rng.value = 0.0
local shot = newProjectile(p.Position)
check(dispatch(ModCallbacks.MC_PRE_PROJECTILE_COLLISION, nil, shot, p, false) == true, "gloves catch a shot")
tick()
local before = #world.entities
local t2 = p:FireTear(p.Position, Vector(10, 0))
dispatch(ModCallbacks.MC_POST_FIRE_TEAR, nil, t2)
check(#world.entities == before + 2, "caught ball is thrown back with the next shot")

-- Shoulder Pads deflect (aiming, so gloves stay out of it; facemask faces down)
p.aim = Vector(1, 0)
local shot2 = newProjectile(p.Position + Vector(-5, 0))
p.rng.value = 0.1
check(dispatch(ModCallbacks.MC_PRE_PROJECTILE_COLLISION, nil, shot2, p, false) == true, "pads deflect")
check(shot2:HasProjectileFlags(ProjectileFlags.HIT_ENEMIES), "deflected shot hits enemies")
p.aim = Vector(0, 0)

-- Mouthguard reduces the first big hit, then pads pop
p.items[Items.MOUTHGUARD] = 1
p.rng.value = 0.99 -- pants don't trigger
local hitter = newEnemy(p.Position + Vector(500, 0))
local dmgBefore = p.damageTaken
p:TakeDamage(2, 0, EntityRef(newProjectile(p.Position)), 0)
check(p.damageTaken - dmgBefore == 1, "mouthguard reduces a full-heart hit to half")
p:TakeDamage(2, 0, EntityRef(newProjectile(p.Position)), 0)
check(p.damageTaken - dmgBefore == 3, "mouthguard only once per room")
p.flags = EntityFlag.FLAG_FEAR
tick()
check(not p:HasEntityFlags(EntityFlag.FLAG_FEAR), "mouthguard clears fear")

-- Kicking Tee field goal
newRoom(false)
dispatch(ModCallbacks.MC_POST_NEW_ROOM)
p.Position, p.Velocity, p.aim = Vector(0, 0), Vector(0, 0), Vector(1, 0)
local weak = newEnemy(Vector(Cfg.KICK_RANGE, 0), 5)
local hpBefore = p.damageTaken
dispatch(ModCallbacks.MC_USE_ITEM, Items.KICKING_TEE, Items.KICKING_TEE, p.rng, p)
tick(Cfg.KICK_FLIGHT + 1)
check(weak.damageTaken > 0, "kick explosion hits enemies")
check(p.damageTaken == hpBefore, "kick doesn't hurt the kicker")
local coins = 0
for _, e in ipairs(world.spawned) do if e.Type == EntityType.ENTITY_PICKUP then coins = coins + 1 end end
check(coins == Cfg.FIELD_GOAL_COINS, "field goal spawns coins")

-- Pigskin fumble + touchdown
newRoom(false)
dispatch(ModCallbacks.MC_POST_NEW_ROOM)
p.Position, p.aim = Vector(0, 0), Vector(1, 0)
local chaser = newEnemy(Vector(Cfg.FUMBLE_RANGE + 100, 0))
dispatch(ModCallbacks.MC_USE_ITEM, Items.PIGSKIN, Items.PIGSKIN, p.rng, p)
tick(Cfg.FUMBLE_FLIGHT + 1)
tick(Cfg.FUMBLE_PICKUP_GRACE + 1)
check(chaser.Velocity.X < 0, "enemies scramble toward the fumble")
p:EvaluateItems()
local dmgNoTD = p.Damage
p.Position = Vector(Cfg.FUMBLE_RANGE, 0)
tick()
p:EvaluateItems()
check(p.Damage > dmgNoTD, "recovering the fumble scores a touchdown")

-- Eye Black curse removal
local cursed = LevelCurse.CURSE_OF_DARKNESS | LevelCurse.CURSE_OF_THE_LOST
local after = dispatch(ModCallbacks.MC_POST_CURSE_EVAL, nil, cursed)
check(after == LevelCurse.CURSE_OF_THE_LOST, "eye black removes Curse of Darkness only")

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then os.exit(1) end
