-- Smoke test: runs main.lua against a mock of the Isaac Lua API.
-- It can't prove game feel, but it catches typos, nil errors and broken
-- callback wiring, and checks that item names / costume paths / sprite paths /
-- sound names line up with the XML and files on disk.
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
        local gfx = attrs:match('gfx="(.-)"')
        local dir = tag == "trinket" and "trinkets" or "collectibles"
        check(readFile("resources/gfx/items/" .. dir .. "/" .. gfx) ~= nil, "item sprite missing: " .. gfx)
    end
end

local costumesXml = assert(readFile("content/costumes2.xml"))
local costumePaths, costumeCount = {}, 0
for path in costumesXml:gmatch('anm2path="(.-)"') do
    costumeCount = costumeCount + 1
    costumePaths["gfx/" .. path] = costumeCount
    check(readFile("resources/gfx/" .. path) ~= nil, "costume anm2 missing: " .. path)
end

local soundsXml = assert(readFile("content/sounds.xml"))
local soundIds, soundCount = {}, 0
for name, body in soundsXml:gmatch('<sound name="(.-)">(.-)</sound>') do
    soundCount = soundCount + 1
    soundIds[name] = 5000 + soundCount
    local path = body:match('path="(.-)"')
    check(readFile("resources/sfx/" .. path) ~= nil, "sound file missing: " .. path)
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
RoomType = { ROOM_DEFAULT = 1, ROOM_BOSS = 5 }
Direction = { LEFT = 0, UP = 1, RIGHT = 2, DOWN = 3 }
EntityType = { ENTITY_PLAYER = 1, ENTITY_TEAR = 2, ENTITY_PROJECTILE = 9, ENTITY_PICKUP = 5,
    ENTITY_EFFECT = 1000, ENTITY_GAPER = 10 }
REPENTANCE = true
Options = { HUDOffset = 0 }

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
function KColor(r, g, b, a) return { Red = r, Green = g, Blue = b, Alpha = a } end

local drawnText = {}
function Font()
    local f = { loaded = false }
    function f:Load(path) self.loaded = path == "font/luaminioutlined.fnt" or path == "font/terminus.fnt" end
    function f:IsLoaded() return self.loaded end
    function f:GetLineHeight() return 8 end
    function f:DrawString(str) drawnText[#drawnText + 1] = str end
    function f:DrawStringScaled(str) drawnText[#drawnText + 1] = str end
    return f
end

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

-- Modules: include / json / Dead Sea Scrolls -------------------------------------------
function include(name)
    if name == "scripts.dssmenucore" then
        -- The real DSS core is a large UI library; stand in for it and check the provider.
        return {
            init = function(modName, provider)
                for _, fn in ipairs({ "SaveSaveData", "GetPaletteSetting", "SavePaletteSetting",
                    "GetHudOffsetSetting", "SaveHudOffsetSetting", "GetGamepadToggleSetting",
                    "SaveGamepadToggleSetting", "GetMenuKeybindSetting", "SaveMenuKeybindSetting",
                    "GetMenuHintSetting", "SaveMenuHintSetting", "GetMenuBuzzerSetting",
                    "SaveMenuBuzzerSetting", "GetMenusNotified", "SaveMenusNotified",
                    "GetMenusPoppedUp", "SaveMenusPoppedUp" }) do
                    check(type(provider[fn]) == "function", "DSS MenuProvider missing " .. fn)
                end
                DeadSeaScrollsMenu = DeadSeaScrollsMenu or {
                    menus = {},
                    AddMenu = function(menuName, t) DeadSeaScrollsMenu.menus[menuName] = t end,
                }
                return { runMenu = function() end, openMenu = function() end, closeMenu = function() end,
                    changelogsButton = {}, menuOpenToolTip = {}, gamepadToggleButton = {},
                    menuKeybindButton = {}, paletteButton = {}, menuHintButton = {}, menuBuzzerButton = {} }
            end,
        }
    end
    local path = name:gsub("%.", "/") .. ".lua"
    local chunk = assert(loadfile(path), "include: cannot load " .. path)
    return chunk()
end

local function serialize(v)
    local t = type(v)
    if t == "table" then
        local parts = {}
        for k, val in pairs(v) do
            parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(val)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif t == "string" then
        return string.format("%q", v)
    elseif t == "number" or t == "boolean" or t == "nil" then
        return tostring(v)
    end
    error("cannot serialize " .. t)
end
package.preload["json"] = function()
    return {
        encode = function(v) return "return " .. serialize(v) end,
        decode = function(s) return assert(load(s))() end,
    }
end

-- World -------------------------------------------------------------------------------
local world = { entities = {}, frame = 0, roomClear = false, roomType = RoomType.ROOM_DEFAULT,
    spawned = {}, hudText = {}, modData = nil }
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
    function e:ToEffect() return self.Type == EntityType.ENTITY_EFFECT and self or nil end
    function e:IsEnemy() return self.isEnemy == true end
    function e:IsVulnerableEnemy() return self.isEnemy == true end
    function e:IsActiveEnemy() return self.isEnemy == true and self.exists end
    function e:IsBoss() return self.boss == true end
    function e:Exists() return self.exists end
    function e:AddVelocity(v) self.Velocity = self.Velocity + v end
    function e:AddConfusion() self.confused = true end
    function e:AddFreeze() self.frozen = true end
    function e:AddSlowing() self.slowed = true end
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

local STAT_FLAGS = { "CACHE_DAMAGE", "CACHE_SPEED", "CACHE_LUCK", "CACHE_FIREDELAY", "CACHE_RANGE",
    "CACHE_SHOTSPEED", "CACHE_TEARFLAG" }

local function newPlayer(ptype)
    local p = newEntity({ isPlayer = true, Type = EntityType.ENTITY_PLAYER, Size = 10, ControllerIndex = 0 })
    p.items, p.trinkets, p.nullCostumes, p.aim = {}, {}, {}, Vector(0, 0)
    p.rng = newRng(0.0)
    p.ptype = ptype or 0
    p.hearts, p.maxHearts, p.soul = 6, 6, 0
    function p:HasCollectible(id) return (self.items[id] or 0) > 0 end
    function p:GetCollectibleNum(id) return self.items[id] or 0 end
    function p:AddCollectible(id) self.items[id] = (self.items[id] or 0) + 1 end
    function p:HasTrinket(id) return self.trinkets[id] == true end
    function p:AddTrinket(id) self.trinkets[id] = true end
    function p:GetTrinketMultiplier() return 1 end
    function p:GetTrinketRNG() return self.rng end
    function p:GetCollectibleRNG() return self.rng end
    function p:GetHeadDirection() return Direction.DOWN end
    function p:GetAimDirection() return self.aim end
    function p:GetPlayerType() return self.ptype end
    function p:GetHearts() return self.hearts end
    function p:GetEffectiveMaxHearts() return self.maxHearts end
    function p:AddHearts(n) self.hearts = math.min(self.maxHearts, self.hearts + n) end
    function p:AddSoulHearts(n) self.soul = self.soul + n end
    function p:SetMinDamageCooldown() end
    function p:AddNullCostume(id) check(type(id) == "number" and id > 0, "bad null costume id"); self.nullCostumes[id] = true end
    function p:TryRemoveNullCostume(id) self.nullCostumes[id] = nil end
    function p:AddCacheFlags() end
    function p:EvaluateItems()
        self.Damage, self.MoveSpeed, self.Luck, self.MaxFireDelay = 3.5, 1, 0, 10
        self.TearRange, self.ShotSpeed, self.TearFlags = 260, 1, 0
        for _, name in ipairs(STAT_FLAGS) do
            dispatch(ModCallbacks.MC_EVALUATE_CACHE, nil, self, CacheFlag[name])
        end
    end
    function p:FireTear(pos, vel, _, _, _, _, mult)
        local t = newEntity({ Type = EntityType.ENTITY_TEAR, Position = pos, Velocity = vel,
            CollisionDamage = 3.5 * (mult or 1), Scale = 1, SpawnerEntity = self })
        function t:AddTearFlags(f) self.tearFlags = (self.tearFlags or 0) | f end
        return t
    end
    p:EvaluateItems()
    return p
end

local function newEnemy(pos, hp, boss)
    return newEntity({ isEnemy = true, Type = EntityType.ENTITY_GAPER, Position = pos, HitPoints = hp or 10, boss = boss })
end

local function newProjectile(pos, spawner)
    local pr = newEntity({ isProjectile = true, Type = EntityType.ENTITY_PROJECTILE, Position = pos, SpawnerEntity = spawner })
    pr.pflags = 0
    function pr:HasProjectileFlags(f) return self.pflags & f ~= 0 end
    function pr:AddProjectileFlags(f) self.pflags = self.pflags | f end
    return pr
end

local players = {}

-- Global API ---------------------------------------------------------------------
function RegisterMod(name)
    local m = { Name = name, callbacks = {} }
    function m:AddCallback(cb, fn, filter)
        assert(cb ~= nil, "AddCallback with nil callback id")
        assert(type(fn) == "function", "AddCallback with non-function")
        self.callbacks[cb] = self.callbacks[cb] or {}
        table.insert(self.callbacks[cb], { fn = fn, filter = filter })
    end
    if name == "Gridiron" then mod = m end
    return m
end

local room = {
    IsClear = function() return world.roomClear end,
    GetType = function() return world.roomType end,
    GetClampedPosition = function(_, pos) return pos end,
    FindFreePickupSpawnPosition = function(_, pos) return pos end,
    GetRenderMode = function() return 0 end,
}
local hud = { ShowItemText = function(_, a) world.hudText[#world.hudText + 1] = a end }

function Game()
    return {
        GetNumPlayers = function() return #players end,
        GetRoom = function() return room end,
        GetHUD = function() return hud end,
        GetLevel = function() return { GetStage = function() return 2 end } end,
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
local soundsPlayed = {}
function SFXManager() return { Play = function(_, id) soundsPlayed[id] = true end } end

Isaac = {
    GetItemIdByName = function(name) return itemIds[name] or -1 end,
    GetTrinketIdByName = function(name) return trinketIds[name] or -1 end,
    GetCostumeIdByPath = function(path) return costumePaths[path] or -1 end,
    GetSoundIdByName = function(name) return soundIds[name] or 0 end,
    GetPlayer = function(i) return players[(i or 0) + 1] end,
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
    HasModData = function() return world.modData ~= nil end,
    LoadModData = function() return world.modData end,
    SaveModData = function(_, s) world.modData = s end,
}

local eidEntries = 0
EID = {
    addCollectible = function(_, id) check(id and id > 0, "EID for unknown collectible"); eidEntries = eidEntries + 1 end,
    addTrinket = function(_, id) check(id and id > 0, "EID for unknown trinket"); eidEntries = eidEntries + 1 end,
}

-- Load the mod ------------------------------------------------------------------------
dofile("main.lua")
local Items, Trinkets, Cfg = mod.Items, mod.Trinkets, mod.Cfg

for key, id in pairs(Items) do check(id > 0, "item name not found in items.xml: " .. key) end
for key, id in pairs(Trinkets) do check(id > 0, "trinket name not found in items.xml: " .. key) end
for key, id in pairs(mod.Sounds) do check(id > 0, "sound not found in sounds.xml: " .. key) end
local itemCount, trinketCount = 0, 0
for _ in pairs(itemIds) do itemCount = itemCount + 1 end
for _ in pairs(trinketIds) do trinketCount = trinketCount + 1 end
check(eidEntries >= itemCount + trinketCount, "every item and trinket has an EID description")
check(DeadSeaScrollsMenu and DeadSeaScrollsMenu.menus["Gridiron"], "DSS menu registered")

local function tick(n)
    for _ = 1, n or 1 do
        world.frame = world.frame + 1
        for _, p in ipairs(players) do dispatch(ModCallbacks.MC_POST_PEFFECT_UPDATE, nil, p) end
        dispatch(ModCallbacks.MC_POST_UPDATE)
        dispatch(ModCallbacks.MC_POST_RENDER)
        for _, p in ipairs(players) do dispatch(ModCallbacks.MC_POST_PLAYER_RENDER, nil, p, Vector(0, 0)) end
    end
end

local function newRoom(clear, roomType)
    world.entities = {}
    for _, p in ipairs(players) do world.entities[#world.entities + 1] = p end
    world.roomClear = clear
    world.roomType = roomType or RoomType.ROOM_DEFAULT
    dispatch(ModCallbacks.MC_POST_NEW_ROOM)
end

local function costumeOn(p, name) return p.nullCostumes[costumePaths["gfx/characters/gridiron_" .. name .. ".anm2"]] end

local function findButton(page, label)
    for _, b in ipairs(mod.MenuDirectory[page].buttons) do
        if b.str == label then return b end
    end
    error("no menu button " .. label .. " on " .. page)
end

-- Scenarios -------------------------------------------------------------------------
local p = newPlayer()
players[1] = p
dispatch(ModCallbacks.MC_POST_GAME_STARTED, nil, false)
newRoom(true)
tick()

-- costumes follow gear
p.items[Items.HELMET] = 1
p.items[Items.JERSEY] = 1
p.items[Items.PADS] = 1
p.items[Items.PANTS] = 1
tick()
check(costumeOn(p, "helmet"), "helmet costume applied")
check(costumeOn(p, "torso_jerseypads"), "jersey+pads costume applied")
check(costumeOn(p, "legs_pants"), "pants costume applied")
p.items[Items.CLEATS] = 1
tick()
check(costumeOn(p, "legs_pantscleats"), "pants+cleats costume applied")
check(not costumeOn(p, "legs_pants"), "old legs costume removed")
newRoom(true)
check(costumeOn(p, "helmet") and costumeOn(p, "legs_pantscleats"), "costumes re-applied after room change")

-- Suited Up (3+ pieces) and stats
p:EvaluateItems()
check(math.abs(p.Damage - (3.5 + Cfg.SUITED_UP_DAMAGE)) < 1e-6, "Suited Up damage bonus")
check(math.abs(p.MoveSpeed - (1 + Cfg.CLEATS_SPEED)) < 1e-6, "Cleats speed")
p.items[Items.EYE_BLACK] = 1
p:EvaluateItems()
check(p.Luck == Cfg.EYE_BLACK_LUCK, "Eye Black luck")

-- Team Jersey pre-snap freeze (enemy must exist before the room callback)
world.entities = { p }
world.roomClear = false
local frozen = newEnemy(Vector(200, 0))
dispatch(ModCallbacks.MC_POST_NEW_ROOM)
check(frozen.frozen, "pre-snap freeze on room entry")

-- Cleats first downs + HUD readout
p.Velocity = Vector(5, 0)
drawnText = {}
tick(Cfg.YARD_UNITS * Cfg.FIRST_DOWN_YARDS / 5 + 1)
p:EvaluateItems()
check(p.Damage > 3.5 + Cfg.SUITED_UP_DAMAGE, "first down adds damage")
local sawDowns = false
for _, line in ipairs(drawnText) do if line:find("&") then sawDowns = true end end
check(sawDowns, "HUD shows down and distance")
newRoom(false)
p:EvaluateItems()
check(math.abs(p.Damage - (3.5 + Cfg.SUITED_UP_DAMAGE)) < 1e-6, "first downs reset on new room")

-- Helmet tackle (Suited Up halves the windup)
p.Position, p.Velocity = Vector(0, 0), Vector(5, 0)
tick(math.floor(Cfg.TACKLE_WINDUP / 2) + 2)
local victim = newEnemy(p.Position + Vector(20, 0), 100)
tick()
check(victim.damageTaken > 0 and victim.confused, "tackle damages and confuses")
local function sawText(t) for _, line in ipairs(drawnText) do if line == t then return true end end return false end
drawnText = {}
tick()
check(sawText("TACKLE!"), "tackle shows a callout")
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
local dmgBefore = p.damageTaken
p:TakeDamage(2, 0, EntityRef(newProjectile(p.Position)), 0)
check(p.damageTaken - dmgBefore == 1, "mouthguard reduces a full-heart hit to half")
p:TakeDamage(2, 0, EntityRef(newProjectile(p.Position)), 0)
check(p.damageTaken - dmgBefore == 3, "mouthguard only once per room")
p.flags = EntityFlag.FLAG_FEAR
tick()
check(not p:HasEntityFlags(EntityFlag.FLAG_FEAR), "mouthguard clears fear")

-- Referee Flag penalizes whoever shot you
p.trinkets[Trinkets.FLAG] = true
local shooter = newEnemy(Vector(300, 0), 100)
p:TakeDamage(1, 0, EntityRef(newProjectile(p.Position, shooter)), 0)
check(shooter.damageTaken > 0 and shooter.slowed, "referee flag penalizes the shooter")
check(soundsPlayed[mod.Sounds.WHISTLE], "flag blows the whistle")

-- Kicking Tee field goal
newRoom(false)
p.Position, p.Velocity, p.aim = Vector(0, 0), Vector(0, 0), Vector(1, 0)
local weak = newEnemy(Vector(Cfg.KICK_RANGE, 0), 5)
local hpBefore = p.damageTaken
dispatch(ModCallbacks.MC_USE_ITEM, Items.KICKING_TEE, Items.KICKING_TEE, p.rng, p)
tick(Cfg.KICK_FLIGHT + 1)
check(weak.damageTaken > 0, "kick explosion hits enemies")
check(p.damageTaken == hpBefore, "kick doesn't hurt the kicker")
world.frame = world.frame + 1
check(dispatch(ModCallbacks.MC_ENTITY_TAKE_DMG, EntityType.ENTITY_PLAYER, p, 2, DamageFlag.DAMAGE_EXPLOSION,
    EntityRef(p), 0) == false, "a late blast from your own kick is ignored too")
drawnText = {}
tick()
check(sawText("IT'S GOOD!"), "field goal callout")
local coins = 0
for _, e in ipairs(world.spawned) do if e.Type == EntityType.ENTITY_PICKUP then coins = coins + 1 end end
check(coins == Cfg.FIELD_GOAL_COINS, "field goal spawns coins")

-- Pigskin fumble + touchdown
newRoom(false)
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

-- Playbook cycles plays, each changes the right stats
newRoom(false)
p:EvaluateItems()
local baseDelay, baseRange = p.MaxFireDelay, p.TearRange
dispatch(ModCallbacks.MC_USE_ITEM, Items.PLAYBOOK, Items.PLAYBOOK, p.rng, p)
p:EvaluateItems()
check(p.MaxFireDelay < baseDelay, "blitz raises tears")
dispatch(ModCallbacks.MC_USE_ITEM, Items.PLAYBOOK, Items.PLAYBOOK, p.rng, p)
p:EvaluateItems()
check(p.TearRange > baseRange and p.TearFlags & TearFlags.TEAR_PIERCING ~= 0, "hail mary adds range and piercing")
check(p.MaxFireDelay == baseDelay, "blitz ends when the play changes")
dispatch(ModCallbacks.MC_USE_ITEM, Items.PLAYBOOK, Items.PLAYBOOK, p.rng, p)
p.items[Items.JERSEY] = 0
local trick = p:FireTear(p.Position, Vector(10, 0))
dispatch(ModCallbacks.MC_POST_FIRE_TEAR, nil, trick)
check(trick.data.GridironFootball ~= nil, "trick play throws footballs")
p.items[Items.JERSEY] = 1
newRoom(false)
p:EvaluateItems()
check(p.TearRange == baseRange and mod.pdata(p).play == nil, "plays end on room change")

-- Coach's Whistle
newRoom(false)
p.Position = Vector(0, 0)
local grunt = newEnemy(Vector(50, 0))
local boss = newEnemy(Vector(-50, 0), 500, true)
local bullet = newProjectile(Vector(30, 30))
dispatch(ModCallbacks.MC_USE_ITEM, Items.WHISTLE, Items.WHISTLE, p.rng, p)
check(grunt.Velocity.X > 0 and grunt.slowed, "whistle shoves and slows enemies")
check(boss.damageTaken > 0, "whistle damages bosses")
check(not bullet.exists, "whistle clears enemy shots")

-- Gatorade Bucket
p.items[Items.GATORADE] = 1
p.hearts = 2
for _ = 1, Cfg.GATORADE_FILLS do
    newRoom(false)
    dispatch(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, nil, p.rng, Vector(0, 0))
end
check(p.hearts == 4, "gatorade shower heals after clean rooms")
newRoom(false)
p.rng.value = 0.99
p:TakeDamage(1, 0, EntityRef(newProjectile(p.Position)), 0)
dispatch(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, nil, p.rng, Vector(0, 0))
check(mod.pdata(p).bucket == 0, "getting hit doesn't fill the bucket")
newRoom(false, RoomType.ROOM_BOSS)
dispatch(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, nil, p.rng, Vector(0, 0))
check(p.hearts == 6, "no-hit boss room is an instant shower")

-- Padded Pants: shrug off a contact hit and stiff-arm the enemy
newRoom(false)
p.Position, p.Velocity, p.aim = Vector(0, 0), Vector(0, 0), Vector(0, 0)
tick()
p.rng.value = 0.0
local bully = newEnemy(Vector(5, 0))
local taken = p.damageTaken
p:TakeDamage(1, 0, EntityRef(bully), 0)
check(p.damageTaken == taken and bully.Velocity.X > 0, "padded pants ignore contact and shove the enemy")
p.rng.value = 0.99

-- Eye Black curse removal
local cursed = LevelCurse.CURSE_OF_DARKNESS | LevelCurse.CURSE_OF_THE_LOST
local after = dispatch(ModCallbacks.MC_POST_CURSE_EVAL, nil, cursed)
check(after == LevelCurse.CURSE_OF_THE_LOST, "eye black removes Curse of Darkness only")

-- Menu settings apply to Cfg and costumes
findButton("gameplay", "glove catch").store(80)
check(math.abs(Cfg.GLOVES_CATCH_CHANCE - 0.8) < 1e-9, "menu changes glove catch chance")
check(findButton("gameplay", "glove catch").load() == 80, "menu reads back the setting")
findButton("gameplay", "tackle windup").store(5)
check(Cfg.TACKLE_WINDUP == 60, "menu changes tackle windup")
findButton("visuals", "costumes").store(2)
check(not costumeOn(p, "helmet"), "costumes can be turned off")
findButton("visuals", "costumes").store(1)
check(costumeOn(p, "helmet"), "costumes come back on")
findButton("character", "helmet").store(2)
check(not costumeOn(p, "helmet") and costumeOn(p, "eyeblack"), "helmet hidden for this character only")
p.ptype = 3
tick()
check(costumeOn(p, "helmet"), "other characters still show the helmet")
p.ptype = 0
tick()
check(not costumeOn(p, "helmet"), "hide rule sticks for the original character")
findButton("character", "helmet").store(1)
check(costumeOn(p, "helmet"), "showing the helmet again for this character")

-- Console commands
local p2 = newPlayer()
players[1] = p2
world.entities = { p2 }
check(dispatch(ModCallbacks.MC_EXECUTE_CMD, nil, "gridiron", "give"):find("gave"), "give command")
local hasAll = true
for _, id in pairs(Items) do
    if not mod.ACTIVE_ITEMS[id] then hasAll = hasAll and p2:HasCollectible(id) end
end
check(hasAll, "give command hands out every passive")
local dropped = 0
for _, e in ipairs(world.spawned) do
    if e.Type == EntityType.ENTITY_PICKUP and (mod.ACTIVE_ITEMS[e.SubType] or e.Variant == PickupVariant.PICKUP_TRINKET) then
        dropped = dropped + 1
    end
end
check(dropped == 4 + trinketCount, "give command drops actives and trinkets")
check(p2:HasCollectible(Items.PANTS), "padded pants are a passive now")
check(dispatch(ModCallbacks.MC_EXECUTE_CMD, nil, "gridiron", "hide legs"):find("hiding"), "hide command")
check(mod.Settings.charRules["0"].legs == false, "hide command stores a rule")
dispatch(ModCallbacks.MC_EXECUTE_CMD, nil, "gridiron", "show legs")
check(mod.Settings.charRules["0"] == nil, "show command clears the rule")
check(dispatch(ModCallbacks.MC_EXECUTE_CMD, nil, "other", "") == nil, "ignores other commands")
dispatch(ModCallbacks.MC_EXECUTE_CMD, nil, "gridiron", "reset")
check(Cfg.GLOVES_CATCH_CHANCE == mod.Defaults.GLOVES_CATCH_CHANCE and Cfg.TACKLE_WINDUP == mod.Defaults.TACKLE_WINDUP,
    "reset restores defaults")

-- Save & continue
players[1] = p
world.entities = { p }
local d = mod.pdata(p)
d.caught, d.bucket, d.playIndex, d.jerseyShown = 2, 1, 2, true
dispatch(ModCallbacks.MC_PRE_GAME_EXIT, nil, true)
check(world.modData ~= nil, "exit writes save data")
local continued = newPlayer()
players[1] = continued
world.entities = { continued }
dispatch(ModCallbacks.MC_POST_NEW_LEVEL) -- may fire before GAME_STARTED; must not clobber the save
dispatch(ModCallbacks.MC_POST_GAME_STARTED, nil, true)
local cd = mod.pdata(continued)
check(cd.caught == 2 and cd.bucket == 1 and cd.playIndex == 2 and cd.jerseyShown, "continue restores run data")
dispatch(ModCallbacks.MC_PRE_GAME_EXIT, nil, false)
dispatch(ModCallbacks.MC_POST_GAME_STARTED, nil, false)
check(mod.GetSaveData().run == nil, "a new run starts clean")

-- Settings survive a restart (fresh load reads the stored blob)
findButton("gameplay", "kick damage").store(70)
mod.StoreSaveData()
local stored = world.modData
mod = nil
DeadSeaScrollsMenu = nil
dofile("main.lua")
world.modData = stored
check(mod.GetSaveData().settings.KICK_DAMAGE == 70, "settings persist across restarts")

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then os.exit(1) end
