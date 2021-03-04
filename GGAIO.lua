local Version = 1.94
local Name = 'GGAIO'

Callback.Add('Load', function()
    GGUpdate:New({
        version = Version,
        scriptName = Name,
        scriptPath = SCRIPT_PATH .. Name .. ".lua",
        scriptUrl = "https://raw.githubusercontent.com/gamsteron/GG/master/" .. Name .. ".lua",
        versionPath = SCRIPT_PATH .. Name .. ".version",
        versionUrl = "https://raw.githubusercontent.com/gamsteron/GG/master/" .. Name .. ".version"
    })
end)

if not FileExist(COMMON_PATH .. "GGPrediction.lua") then
    DownloadFileAsync("https://raw.githubusercontent.com/gamsteron/GG/master/GGPrediction.lua", COMMON_PATH .. "GGPrediction.lua", function() end)
    print('GGPrediction - downloaded! Please 2xf6!')
    return
end
require('GGPrediction')

local Menu, Utils, Champion

local GG_Target, GG_Orbwalker, GG_Buff, GG_Damage, GG_Spell, GG_Object, GG_Attack, GG_Data, GG_Cursor

local HITCHANCE_NORMAL = 2
local HITCHANCE_HIGH = 3
local HITCHANCE_IMMOBILE = 4

local DAMAGE_TYPE_PHYSICAL = 0
local DAMAGE_TYPE_MAGICAL = 1
local DAMAGE_TYPE_TRUE = 2

local ORBWALKER_MODE_NONE = -1
local ORBWALKER_MODE_COMBO = 0
local ORBWALKER_MODE_HARASS = 1
local ORBWALKER_MODE_LANECLEAR = 2
local ORBWALKER_MODE_JUNGLECLEAR = 3
local ORBWALKER_MODE_LASTHIT = 4
local ORBWALKER_MODE_FLEE = 5

local TEAM_JUNGLE = 300
local TEAM_ALLY = myHero.team
local TEAM_ENEMY = 300 - myHero.team

local math_huge = math.huge
local math_pi = math.pi
local math_sqrt = assert(math.sqrt)
local math_abs = assert(math.abs)
local math_ceil = assert(math.ceil)
local math_min = assert(math.min)
local math_max = assert(math.max)
local math_pow = assert(math.pow)
local math_atan = assert(math.atan)
local math_acos = assert(math.acos)
local math_random = assert(math.random)
local table_sort = assert(table.sort)
local table_remove = assert(table.remove)
local table_insert = assert(table.insert)

local myHero = myHero
local os = os
local math = math
local Game = Game
local Vector = Vector
local Control = Control
local Draw = Draw
local table = table
local pairs = pairs
local GetTickCount = GetTickCount

local function IsInRange(v1, v2, range)
    v1 = v1.pos or v1
    v2 = v2.pos or v2
    local dx = v1.x - v2.x
    local dz = (v1.z or v1.y) - (v2.z or v2.y)
    if dx * dx + dz * dz <= range * range then
        return true
    end
    return false
end

local function GetDistance(v1, v2)
    v1 = v1.pos or v1
    v2 = v2.pos or v2
    local dx = v1.x - v2.x
    local dz = (v1.z or v1.y) - (v2.z or v2.y)
    return math.sqrt(dx * dx + dz * dz)
end

Menu = {}
do
    Menu.m = MenuElement({name = "GG " .. myHero.charName, id = 'GG' .. myHero.charName, type = _G.MENU})
    Menu.q = Menu.m:MenuElement({name = 'Q', id = 'q', type = _G.MENU})
    Menu.w = Menu.m:MenuElement({name = 'W', id = 'w', type = _G.MENU})
    Menu.e = Menu.m:MenuElement({name = 'E', id = 'e', type = _G.MENU})
    Menu.r = Menu.m:MenuElement({name = 'R', id = 'r', type = _G.MENU})
    Menu.d = Menu.m:MenuElement({name = 'Drawings', id = 'd', type = _G.MENU})
    Menu.m:MenuElement({name = '', type = _G.SPACE, id = 'VersionSpaceA'})
    Menu.m:MenuElement({name = 'Version  ' .. Version, type = _G.SPACE, id = 'VersionSpaceB'})
end

Utils = {}
do
    -- can use spell
    Utils.CanUseSpell = true
    -- interruptable spells
    Utils.InterruptableSpells =
    {
        ["CaitlynAceintheHole"] = true,
        ["Crowstorm"] = true,
        ["DrainChannel"] = true,
        ["GalioIdolOfDurand"] = true,
        ["ReapTheWhirlwind"] = true,
        ["KarthusFallenOne"] = true,
        ["KatarinaR"] = true,
        ["LucianR"] = true,
        ["AlZaharNetherGrasp"] = true,
        ["Meditate"] = true,
        ["MissFortuneBulletTime"] = true,
        ["AbsoluteZero"] = true,
        ["PantheonRJump"] = true,
        ["PantheonRFall"] = true,
        ["ShenStandUnited"] = true,
        ["Destiny"] = true,
        ["UrgotSwap2"] = true,
        ["VelkozR"] = true,
        ["InfiniteDuress"] = true,
        ["XerathLocusOfPower2"] = true
    }
    -- draw text on hero
    function Utils:DrawTextOnHero(hero, text, color)
        local pos2D = hero.pos:To2D()
        local posX = pos2D.x - 50
        local posY = pos2D.y
        Draw.Text(text, 50, posX + 50, posY - 15, color)
    end
    -- cached distance
    Utils.CachedDistance = {}
    -- get enemy heroes
    function Utils:GetEnemyHeroes(range, bbox)
        local result = {}
        if not self.CanUseSpell then
            return result
        end
        for i, unit in ipairs(Champion.EnemyHeroes) do
            if self.CachedDistance[i] == nil then
                self.CachedDistance[i] = unit.distance
            end
            local extrarange = bbox and unit.boundingRadius or 0
            if self.CachedDistance[i] < range + extrarange then
                table_insert(result, unit)
            end
        end
        return result
    end
    -- get enemy heroes inside polygon
    function Utils:GetEnemyHeroesInsidePolygon(range, polygon, bbox)
        local result = {}
        if not self.CanUseSpell then
            return result
        end
        for i, unit in ipairs(Champion.EnemyHeroes) do
            if self.CachedDistance[i] == nil then
                self.CachedDistance[i] = unit.distance
            end
            local extrarange = bbox and unit.boundingRadius or 0
            if self.CachedDistance[i] < range + extrarange and self:InsidePolygon(polygon, unit) then
                table_insert(result, unit)
            end
        end
        return result
    end
    -- cast
    function Utils:Cast(spell, target, spellprediction, hitchance)
        if not self.CanUseSpell and (target or spellprediction) then
            return false
        end
        if spellprediction == nil then
            if target == nil then
                Control.KeyDown(spell)
                Control.KeyUp(spell)
                return true
            end
            Control.CastSpell(spell, target)
            self.CanUseSpell = false
            return true
        end
        if target == nil then
            return false
        end
        spellprediction:GetPrediction(target, myHero)
        if spellprediction:CanHit(hitchance or HITCHANCE_HIGH) then
            Control.CastSpell(spell, spellprediction.CastPosition)
            self.CanUseSpell = false
            return true
        end
        return false
    end
    -- check wall
    function Utils:CheckWall(from, to, distance)
        local pos1 = to + (to - from):Normalized() * 50
        local pos2 = pos1 + (to - from):Normalized() * (distance - 50)
        local point1 = {x = pos1.x, z = pos1.z}
        local point2 = {x = pos2.x, z = pos2.z}
        if MapPosition:intersectsWall(point1, point2) or (MapPosition:inWall(point1) and MapPosition:inWall(point2)) then
            return true
        end
        return false
    end
    -- inside polygon
    function Utils:InsidePolygon(polygon, point)
        local result = false
        local j = #polygon
        point = point.pos or point
        local pointx = point.x
        local pointz = point.z or point.y
        for i = 1, #polygon do
            if (polygon[i].z < pointz and polygon[j].z >= pointz or polygon[j].z < pointz and polygon[i].z >= pointz) then
                if (polygon[i].x + (pointz - polygon[i].z) / (polygon[j].z - polygon[i].z) * (polygon[j].x - polygon[i].x) < pointx) then
                    result = not result
                end
            end
            j = i
        end
        return result
    end
end

if Champion == nil and myHero.charName == 'Twitch' then
    -- constants
    local TIMER_COLOR = Draw.Color(200, 65, 255, 100)
    local INV_CIRCLE_COLOR = Draw.Color(200, 255, 0, 0)
    local NOT_CIRCLE_COLOR = Draw.Color(200, 188, 77, 26)
    
    -- menu
    Menu.q_combo = Menu.q:MenuElement({id = 'combo', name = 'Combo', value = false})
    Menu.q_harass = Menu.q:MenuElement({id = 'harass', name = 'Harass', value = false})
    Menu.q:MenuElement({id = "recall", name = "Recall", type = _G.MENU})
    Menu.q_recall_key = Menu.q.recall:MenuElement({id = 'key', name = 'Invisible Recall Key', key = string.byte('P'), value = false, toggle = true})
    Menu.q_recall_note = Menu.q.recall:MenuElement({id = 'note', name = 'Note: Key should be diffrent than recall key', type = _G.SPACE})
    Menu.q_recall_key:Value(false)
    
    Menu.w_combo = Menu.w:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.w_harass = Menu.w:MenuElement({id = 'harass', name = 'Harass', value = false})
    Menu.w_stopq = Menu.w:MenuElement({id = 'stopq', name = 'Stop using W when has Q', value = true})
    Menu.w_stopr = Menu.w:MenuElement({id = 'stopr', name = 'Stop using W when has R', value = false})
    Menu.w_hitchance = Menu.w:MenuElement({id = 'hitchance', name = 'Hitchance', value = 2, drop = {'normal', 'high', 'immobile'}})
    
    Menu.e_combo = Menu.e:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.e_harass = Menu.e:MenuElement({id = 'harass', name = 'Harass', value = true})
    Menu.e_xstacks = Menu.e:MenuElement({id = 'xstacks', name = 'X Stacks', value = 6, min = 1, max = 6, step = 1})
    Menu.e_xenemies = Menu.e:MenuElement({id = 'xenemies', name = 'X Enemies', value = 1, min = 1, max = 5, step = 1})
    Menu.e:MenuElement({id = "ks", name = "Killsteal", type = _G.MENU})
    Menu.e_ks_enabled = Menu.e.ks:MenuElement({id = 'enabled', name = 'Enabled', value = true})
    
    Menu.r_combo = Menu.r:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.r_harass = Menu.r:MenuElement({id = 'harass', name = 'Harass', value = false})
    Menu.r_xrange = Menu.r:MenuElement({id = 'xrange', name = 'X Distance', value = 750, min = 300, max = 1500, step = 50})
    Menu.r_xenemies = Menu.r:MenuElement({id = 'xenemies', name = 'X Enemies', value = 3, min = 1, max = 5, step = 1})
    
    Menu.d_qtimer = Menu.d:MenuElement({id = 'qtimer', name = 'Q Timer', value = true})
    Menu.d_qinvisible = Menu.d:MenuElement({id = 'qinvisible', name = 'Q Invisible Range', value = true})
    Menu.d_qnotification = Menu.d:MenuElement({id = 'qnotification', name = 'Q Notification Range', value = true})
    
    -- locals
    local EBuffs = {}
    local Recall = true
    local LastPreInvisible = 0
    local WPrediction = GGPrediction:SpellPrediction({Delay = 0.25, Radius = 50, Range = 950, Speed = 1400, Type = GGPrediction.SPELLTYPE_CIRCLE})
    
    -- champion
    Champion =
    {
        CanAttackCb = function()
            return GG_Spell:CanTakeAction({q = 0, w = 0.33, e = 0.33, r = 0})
        end,
        CanMoveCb = function()
            return GG_Spell:CanTakeAction({q = 0, w = 0.23, e = 0.23, r = 0})
        end,
        OnPostAttackTick = function(PostAttackTimer)
            Champion:PreTick()
            Champion:ELogic()
            Champion:WLogic()
        end,
    }
    -- tick
    function Champion:OnTick()
        self:EBuffManager()
        if not self.IsAttacking then
            self:ELogic()
        end
        self:RLogic()
        self:QLogic()
        if self.IsAttacking or self.CanAttackTarget or self.AttackTarget then
            return
        end
        self:WLogic()
    end
    -- draw
    function Champion:OnDraw()
        self:DrawTimer()
        self:DrawInvisibleCircles()
    end
    -- q logic
    function Champion:QLogic()
        if not GG_Spell:IsReady(_Q, {q = 1, w = 0, e = 0, r = 0}) then
            return
        end
        self:QRecall()
        self:QCombo()
    end
    -- w logic
    function Champion:WLogic()
        if not GG_Spell:IsReady(_W, {q = 0, w = 1, e = 0.33, r = 0}) then
            return
        end
        self:WCombo()
    end
    -- e logic
    function Champion:ELogic()
        if not GG_Spell:IsReady(_E, {q = 0, w = 0.33, e = 1, r = 0}) then
            return
        end
        self.ETargets = Utils:GetEnemyHeroes(1200 - 35)
        self:EKS()
        self:ECombo()
    end
    -- r logic
    function Champion:RLogic()
        if not GG_Spell:IsReady(_R, {q = 0, w = 0, e = 0, r = 1}) then
            return
        end
        self:RCombo()
    end
    -- q recall
    function Champion:QRecall()
        if Menu.q_recall_key:Value() == Recall then
            Control.KeyDown(HK_Q)
            Control.KeyUp(HK_Q)
            Control.KeyDown(string.byte("B"))
            Control.KeyUp(string.byte("B"))
            Recall = not Recall
        end
    end
    -- q combo
    function Champion:QCombo()
        if not((self.IsCombo and Menu.q_combo:Value()) or (self.IsHarass and Menu.q_harass:Value())) then
            return
        end
        if self.AttackTarget then
            Utils:Cast(HK_Q)
        end
    end
    -- w combo
    function Champion:WCombo()
        if not((self.IsCombo and Menu.w_combo:Value()) or (self.IsHarass and Menu.w_harass:Value())) then
            return
        end
        if Menu.w_stopq:Value() and GG_Buff:HasBuff(myHero, "globalcamouflage") then
            return
        end
        if Menu.w_stopr:Value() and self.Timer < GG_Spell.RkTimer + 5.45 then
            return
        end
        local target = self.AttackTarget ~= nil and self.AttackTarget or GG_Target:GetTarget(Utils:GetEnemyHeroes(950), DAMAGE_TYPE_PHYSICAL)
        Utils:Cast(HK_W, target, WPrediction, Menu.w_hitchance:Value() + 1)
    end
    -- e buffmanager
    function Champion:EBuffManager()
        local enemies = Utils:GetEnemyHeroes(2000)
        for _, hero in ipairs(enemies) do
            local id = hero.networkID
            if EBuffs[id] == nil then EBuffs[id] = {count = 0, duration = 0} end
            local ebuff = GG_Buff:GetBuff(hero, 'twitchdeadlyvenom')
            if ebuff and ebuff.count > 0 and ebuff.duration > 0 then
                if EBuffs[id].count < 6 and ebuff.duration > EBuffs[id].duration then
                    EBuffs[id].count = EBuffs[id].count + 1
                end
                EBuffs[id].duration = ebuff.duration
            else
                EBuffs[id].count = 0
                EBuffs[id].duration = 0
            end
        end
    end
    -- e ks
    function Champion:EKS()
        if not Menu.e_ks_enabled:Value() then
            return
        end
        for _, hero in ipairs(self.ETargets) do
            if EBuffs[hero.networkID] then
                local ecount = EBuffs[hero.networkID].count
                if ecount > 0 then
                    local elvl = myHero:GetSpellData(_E).level
                    local basedmg = 10 + (elvl * 10)
                    local perstack = (10 + (5 * elvl)) * ecount
                    local bonusAD = myHero.bonusDamage * 0.35 * ecount
                    local physdmg = GG_Damage:CalculateDamage(myHero, hero, DAMAGE_TYPE_PHYSICAL, basedmg + perstack + bonusAD)
                    local magicdmg = GG_Damage:CalculateDamage(myHero, hero, DAMAGE_TYPE_MAGICAL, myHero.ap * 0.333 * ecount)
                    if physdmg + magicdmg >= hero.health + (1.5 * hero.hpRegen) then
                        Utils:Cast(HK_E)
                        break
                    end
                end
            end
        end
    end
    -- e combo
    function Champion:ECombo()
        if not((self.IsCombo and Menu.e_combo:Value()) or (self.IsHarass and Menu.e_harass:Value())) then
            return
        end
        local xenemies = 0
        for _, hero in ipairs(self.ETargets) do
            if EBuffs[hero.networkID] then
                local ecount = EBuffs[hero.networkID].count
                if ecount > 0 and ecount >= Menu.e_xstacks:Value() then
                    xenemies = xenemies + 1
                end
            end
        end
        if xenemies >= Menu.e_xenemies:Value() then
            Utils:Cast(HK_E)
        end
    end
    -- r combo
    function Champion:RCombo()
        if not((self.IsCombo and Menu.r_combo:Value()) or (self.IsHarass and Menu.r_harass:Value())) then
            return
        end
        local enemies = Utils:GetEnemyHeroes(Menu.r_xrange:Value())
        if #enemies >= Menu.r_xenemies:Value() then
            Utils:Cast(HK_R)
        end
    end
    -- draw timer
    function Champion:DrawTimer()
        if not Menu.d_qtimer:Value() then
            return
        end
        local preInvisibleDuration = 1.35 - (self.Timer - GG_Spell.QkTimer)
        if preInvisibleDuration > 0 then
            Utils:DrawTextOnHero(myHero, tostring(math.floor(preInvisibleDuration * 1000)), TIMER_COLOR)
            return
        end
        local invisibleDuration = GG_Buff:GetBuffDuration(myHero, "globalcamouflage")
        if invisibleDuration > 0 then
            Utils:DrawTextOnHero(myHero, tostring(math.floor(invisibleDuration * 1000)), TIMER_COLOR)
        end
    end
    -- draw invisible circles
    function Champion:DrawInvisibleCircles()
        if not GG_Buff:HasBuff(myHero, "globalcamouflage") then
            return
        end
        if Menu.d_qinvisible:Value() then
            Draw.Circle(myHero.pos, 500, 1, INV_CIRCLE_COLOR)
        end
        if Menu.d_qnotification:Value() then
            Draw.Circle(myHero.pos, 800, 1, NOT_CIRCLE_COLOR)
        end
    end
end

if Champion == nil and myHero.charName == 'Morgana' then
    -- menu
    Menu.q_combo = Menu.q:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.q_harass = Menu.q:MenuElement({id = 'harass', name = 'Harass', value = true})
    Menu.q_hitchance = Menu.q:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"Normal", "High", "Immobile"}})
    Menu.q_useon = Menu.q:MenuElement({id = "useon", name = "Use on", type = _G.MENU})
    Menu.q:MenuElement({id = "auto", name = "Auto", type = _G.MENU})
    Menu.q_auto_enabled = Menu.q.auto:MenuElement({id = "enabled", name = "Enabled", value = true})
    Menu.q_auto_hitchance = Menu.q.auto:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"Normal", "High", "Immobile"}})
    Menu.q_auto_useon = Menu.q.auto:MenuElement({id = "useon", name = "Use on", type = _G.MENU})
    Menu.q:MenuElement({id = "ks", name = "Killsteal", type = _G.MENU})
    Menu.q_ks_enabled = Menu.q.ks:MenuElement({id = "enabled", name = "Enabled", value = false})
    Menu.q_ks_hitchance = Menu.q.ks:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"Normal", "High", "Immobile"}})
    Menu.q:MenuElement({id = "interrupter", name = "Interrupter", type = _G.MENU})
    Menu.q_interrupter_enabled = Menu.q.interrupter:MenuElement({id = "enabled", name = "Enabled", value = true})
    Menu.q:MenuElement({id = "attack", name = "DisableAttack", type = _G.MENU})
    Menu.q_attack_disable = Menu.q.attack:MenuElement({id = "disable", name = "Disable attack if ready or almostReady", value = false})
    
    Menu.w_combo = Menu.w:MenuElement({id = 'combo', name = 'Combo', value = false})
    Menu.w_harass = Menu.w:MenuElement({id = 'harass', name = 'Harass', value = false})
    Menu.w_hitchance = Menu.w:MenuElement({id = "hitchance", name = "Hitchance", value = 3, drop = {"Normal", "High", "Immobile"}})
    Menu.w:MenuElement({id = "auto", name = "Auto", type = _G.MENU})
    Menu.w_auto_enabled = Menu.w.auto:MenuElement({id = "enabled", name = "Enabled", value = true})
    Menu.w_auto_hitchance = Menu.w.auto:MenuElement({id = "hitchance", name = "Hitchance", value = 3, drop = {"Normal", "High", "Immobile"}})
    Menu.w:MenuElement({id = "lane", name = "LaneClear", type = _G.MENU})
    Menu.w_lane_enabled = Menu.w.lane:MenuElement({id = "enabled", name = "Enabled", value = false})
    Menu.w_lane_count = Menu.w.lane:MenuElement({id = "count", name = "LaneClear Minions", value = 3, min = 1, max = 5, step = 1})
    Menu.w:MenuElement({id = "ks", name = "Killsteal", type = _G.MENU})
    Menu.w_ks_enabled = Menu.w.ks:MenuElement({id = "enabled", name = "Enabled", value = true})
    Menu.w_ks_hitchance = Menu.w.ks:MenuElement({id = "hitchance", name = "Hitchance", value = 1, drop = {"Normal", "High", "Immobile"}})
    
    Menu.e_enabled = Menu.e:MenuElement({id = "enabled", name = "Enabled", value = true})
    Menu.e_ally = Menu.e:MenuElement({id = "ally", name = "Use on ally", value = true})
    Menu.e_selfish = Menu.e:MenuElement({id = "selfish", name = "Use on yourself", value = true})
    
    Menu.r_combo = Menu.r:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.r_harass = Menu.r:MenuElement({id = 'harass', name = 'Harass', value = false})
    Menu.r_xenemies = Menu.r:MenuElement({id = "xenemies", name = "X Enemies", value = 2, min = 1, max = 5, step = 1})
    Menu.r_xrange = Menu.r:MenuElement({id = "xrange", name = "X Distance", value = 550, min = 300, max = 600, step = 50})
    Menu.r:MenuElement({id = "auto", name = "Auto", type = _G.MENU})
    Menu.r_auto_enabled = Menu.r.auto:MenuElement({id = "enabled", name = "Enabled", value = true})
    Menu.r_auto_xenemies = Menu.r.auto:MenuElement({id = "xenemies", name = "X Enemies", value = 3, min = 1, max = 5, step = 1})
    Menu.r_auto_xrange = Menu.r.auto:MenuElement({id = "xrange", name = "X Distance", value = 550, min = 300, max = 600, step = 50})
    Menu.r:MenuElement({id = "ks", name = "Killsteal", type = _G.MENU})
    Menu.r_ks_enabled = Menu.r.ks:MenuElement({id = "enabled", name = "Enabled", value = true})
    
    -- locals
    local QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1175, Speed = 1200, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_MINION}})
    local WPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 100, Range = 900, Speed = math.huge})
    local EPrediction = {Range = 800}
    local RPrediction = {Range = 625}
    
    -- champion
    Champion =
    {
        CanAttackCb = function()
            if not GG_Spell:CanTakeAction({q = 0.33, w = 0.33, e = 0.33, r = 0.33}) then
                return false
            end
            -- LastHit, LaneClear
            if not GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and not GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] then
                return true
            end
            -- Q
            local qdata = myHero:GetSpellData(_Q)
            if Menu.q_attack_disable:Value() and qdata.level > 0 and myHero.mana > qdata.mana and (Game.CanUseSpell(_Q) == 0 or qdata.currentCd < 1) then
                return false
            end
            return true
        end,
        CanMoveCb = function()
            return GG_Spell:CanTakeAction({q = 0.25, w = 0.25, e = 0.25, r = 0.25})
        end,
    }
    -- load
    function Champion:OnLoad()
        GG_Object:OnEnemyHeroLoad(function(args)
            Menu.q_auto_useon:MenuElement({id = args.charName, name = args.charName, value = true})
            Menu.q_useon:MenuElement({id = args.charName, name = args.charName, value = true})
        end)
    end
    -- tick
    function Champion:OnTick()
        self:QLogic()
        self:WLogic()
        self:ELogic()
        self:RLogic()
    end
    -- q logic
    function Champion:QLogic()
        if not GG_Spell:IsReady(_Q, {q = 1, w = 0.3, e = 0.3, r = 0.3}) then
            return
        end
        self.QTargets = Utils:GetEnemyHeroes(QPrediction.Range)
        self:QKS()
        self:QInterrupter()
        self:QAuto()
        self:QCombo()
    end
    -- w logic
    function Champion:WLogic()
        if not GG_Spell:IsReady(_W, {q = 0.3, w = 1, e = 0.3, r = 0.3}) then
            return
        end
        self.WTargets = Utils:GetEnemyHeroes(WPrediction.Range)
        self:WKS()
        self:WAuto()
        self:WCombo()
        self:WLaneClear()
    end
    -- e logic
    function Champion:ELogic()
        if not GG_Spell:IsReady(_E, {q = 0.3, w = 0.3, e = 1, r = 0.3}) then
            return
        end
        if not Menu.e_enabled:Value() then
            return
        end
        if not Menu.e_ally:Value() and not Menu.e_selfish:Value() then
            return
        end
        self.ETargets = Utils:GetEnemyHeroes(2500)
        self.EAllies = GG_Object:GetAllyHeroes(EPrediction.Range)
        self:EAuto()
    end
    -- r logic
    function Champion:RLogic()
        if not GG_Spell:IsReady(_R, {q = 0.33, w = 0.33, e = 0.33, r = 1}) then
            return
        end
        self.RTargets = Utils:GetEnemyHeroes(RPrediction.Range)
        self:RKS()
        self:RAuto()
        self:RCombo()
    end
    -- q ks
    function Champion:QKS()
        if not Menu.q_ks_enabled:Value() then
            return
        end
        local baseDmg = 25
        local lvlDmg = 55 * myHero:GetSpellData(_Q).level
        local apDmg = myHero.ap * 0.9
        local qDmg = baseDmg + lvlDmg + apDmg
        if qDmg < 100 then
            return
        end
        for i, unit in ipairs(self.QTargets) do
            local health = unit.health
            if health > 100 and health < GG_Damage:CalculateDamage(myHero, unit, DAMAGE_TYPE_MAGICAL, qDmg) then
                Utils:Cast(HK_Q, unit, QPrediction, Menu.q_ks_hitchance:Value() + 1)
            end
        end
    end
    -- q interrupter
    function Champion:QInterrupter()
        if not Menu.q_interrupter_enabled:Value() then
            return
        end
        for i, unit in ipairs(self.QTargets) do
            local spell = unit.activeSpell
            if spell and spell.valid and Utils.InterruptableSpells[spell.name] and spell.castEndTime - self.Timer > 0.33 then
                Utils:Cast(HK_Q, unit, QPrediction, HITCHANCE_NORMAL)
            end
        end
    end
    -- q auto
    function Champion:QAuto()
        if not Menu.q_auto_enabled:Value() then
            return
        end
        local enemies = {}
        for i, unit in ipairs(self.QTargets) do
            local canuse = Menu.q_auto_useon[unit.charName]
            if canuse and canuse:Value() then
                table_insert(enemies, unit)
            end
        end
        Utils:Cast(HK_Q, GG_Target:GetTarget(enemies, DAMAGE_TYPE_MAGICAL), QPrediction, Menu.q_auto_hitchance:Value() + 1)
    end
    -- q combo
    function Champion:QCombo()
        if not((self.IsCombo and Menu.q_combo:Value()) or (self.IsHarass and Menu.q_harass:Value())) then
            return
        end
        local enemies = {}
        for i, unit in ipairs(self.QTargets) do
            local canuse = Menu.q_useon[unit.charName]
            if canuse and canuse:Value() then
                table_insert(enemies, unit)
            end
        end
        Utils:Cast(HK_Q, GG_Target:GetTarget(enemies, DAMAGE_TYPE_MAGICAL), QPrediction, Menu.q_hitchance:Value() + 1)
    end
    -- w ks
    function Champion:WKS()
        if not Menu.w_ks_enabled:Value() then
            return
        end
        local basedmg = 10
        local lvldmg = 14 * myHero:GetSpellData(_W).level
        local apdmg = myHero.ap * 0.22
        local dmg = basedmg + lvldmg + apdmg
        if dmg < 100 then
            return
        end
        for i, unit in ipairs(self.WTargets) do
            local health = unit.health
            if health > 100 and health < GG_Damage:CalculateDamage(myHero, unit, DAMAGE_TYPE_MAGICAL, dmg) then
                Utils:Cast(HK_W, unit, WPrediction, Menu.w_ks_hitchance:Value() + 1)
            end
        end
    end
    -- w auto
    function Champion:WAuto()
        if not Menu.w_auto_enabled:Value() then
            return
        end
        for i, unit in ipairs(self.WTargets) do
            Utils:Cast(HK_W, unit, WPrediction, Menu.w_auto_hitchance:Value() + 1)
        end
    end
    -- w combo
    function Champion:WCombo()
        if not((self.IsCombo and Menu.w_combo:Value()) or (self.IsHarass and Menu.w_harass:Value())) then
            return
        end
        for i, unit in ipairs(self.WTargets) do
            Utils:Cast(HK_W, unit, WPrediction, Menu.w_hitchance:Value() + 1)
        end
    end
    -- w laneclear
    function Champion:WLaneClear()
        if not(self.IsLaneClear and Menu.w_lane_enabled:Value()) then
            return
        end
        local target = nil
        local BestHit = 0
        local CurrentCount = 0
        self.WEnemyMinions = GG_Object:GetEnemyMinions(WPrediction.Range + 250)
        for i, unit in ipairs(self.WEnemyMinions) do
            if unit.distance < WPrediction.Range then
                CurrentCount = 0
                local minionPos = unit.pos
                for j, unit2 in ipairs(self.WEnemyMinions) do
                    if minionPos:DistanceTo(unit2.pos) < 250 then
                        CurrentCount = CurrentCount + 1
                    end
                end
                if CurrentCount > BestHit then
                    BestHit = CurrentCount
                    target = unit
                end
            end
        end
        if target and BestHit >= Menu.w_lane_count:Value() then
            Utils:Cast(HK_W, target)
        end
    end
    -- e auto
    function Champion:EAuto()
        for i, unit in ipairs(self.ETargets) do
            local heroPos = unit.pos
            local s = unit.activeSpell
            if s and s.valid and unit.isChanneling then
                for j, ally in ipairs(self.EAllies) do
                    if (Menu.e_selfish:Value() and ally.isMe) or (Menu.e_ally:Value() and not ally.isMe) then
                        local canUse = false
                        if s.target == ally.handle then
                            canUse = true
                        else
                            local allyPos = ally.pos
                            local spellPos = s.placementPos
                            local width = ally.boundingRadius + 100
                            if s.width > 0 then width = width + s.width end
                            local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(allyPos, spellPos, heroPos)
                            if isOnSegment and IsInRange(point, allyPos, width) then
                                canUse = true
                            end
                        end
                        if canUse then
                            Utils:Cast(HK_E, ally)
                        end
                    end
                end
            end
        end
    end
    -- r ks
    function Champion:RKS()
        if not Menu.r_ks_enabled:Value() then
            return
        end
        local basedmg = 75
        local lvldmg = 75 * myHero:GetSpellData(_R).level
        local apdmg = myHero.ap * 0.7
        local rdmg = basedmg + lvldmg + apdmg
        if rdmg < 100 then
            return
        end
        for i, unit in ipairs(self.RTargets) do
            local health = unit.health
            if health > 100 and health < GG_Damage:CalculateDamage(myHero, unit, DAMAGE_TYPE_MAGICAL, rdmg) then
                Utils:Cast(HK_R)
            end
        end
    end
    -- r auto
    function Champion:RAuto()
        if not Menu.r_auto_enabled:Value() then
            return
        end
        local count = 0
        for i, unit in ipairs(self.RTargets) do
            if unit.distance < Menu.r_auto_xrange:Value() then
                count = count + 1
            end
        end
        if count >= Menu.r_auto_xenemies:Value() then
            Utils:Cast(HK_R)
        end
    end
    -- r combo
    function Champion:RCombo()
        if not((self.IsCombo and Menu.r_combo:Value()) or (self.IsHarass and Menu.r_harass:Value())) then
            return
        end
        local count = 0
        for i, unit in ipairs(self.RTargets) do
            if unit.distance < Menu.r_xrange:Value() then
                count = count + 1
            end
        end
        if count >= Menu.r_xenemies:Value() then
            Utils:Cast(HK_R)
        end
    end
end

if Champion == nil and myHero.charName == 'Ezreal' then
    -- menu
    Menu.q_combo = Menu.q:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.q_harass = Menu.q:MenuElement({id = 'harass', name = 'Harass', value = true})
    Menu.q_hitchance = Menu.q:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high", "immobile"}})
    Menu.q:MenuElement({id = "auto", name = "Auto", type = _G.MENU})
    Menu.q_auto_enabled = Menu.q.auto:MenuElement({id = "enabled", name = "Enabled", value = true, key = string.byte("T"), toggle = true})
    Menu.q_auto_hitchance = Menu.q.auto:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high", "immobile"}})
    Menu.q_auto_mana = Menu.q.auto:MenuElement({id = "mana", name = "Minimum Mana Percent", value = 50, min = 0, max = 100, step = 1})
    Menu.q:MenuElement({id = "lane", name = "LaneClear", type = _G.MENU})
    Menu.q_lh_enabled = Menu.q.lane:MenuElement({id = "lhenabled", name = "LastHit Enabled", value = true})
    Menu.q_lh_mana = Menu.q.lane:MenuElement({id = "lhmana", name = "LastHit Min. Mana %", value = 50, min = 0, max = 100, step = 5})
    Menu.q_lc_enabled = Menu.q.lane:MenuElement({id = "lcenabled", name = "LaneClear Enabled", value = false})
    Menu.q_lc_mana = Menu.q.lane:MenuElement({id = "lcmana", name = "LaneClear Min. Mana %", value = 75, min = 0, max = 100, step = 5})
    
    Menu.w_combo = Menu.w:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.w_harass = Menu.w:MenuElement({id = 'harass', name = 'Harass', value = true})
    Menu.w_hitchance = Menu.w:MenuElement({id = "hitchance", name = "Hitchance", value = 1, drop = {"normal", "high", "immobile"}})
    Menu.w_mana = Menu.w:MenuElement({id = "mana", name = "Min. Mana %", value = 5, min = 0, max = 100, step = 1})
    
    Menu.e_fake = Menu.e:MenuElement({id = "efake", name = "Key to use", value = false, key = string.byte("E")})
    Menu.e_lol = Menu.e:MenuElement({id = "elol", name = "key in game", value = false, key = string.byte("L")})
    
    Menu.r_combo = Menu.r:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.r_harass = Menu.r:MenuElement({id = 'harass', name = 'Harass', value = false})
    Menu.r_auto = Menu.r:MenuElement({id = 'auto', name = 'Auto', value = false})
    Menu.r_stopaa = Menu.r:MenuElement({id = "stopaa", name = "Don't when enemy in attack range", value = true})
    Menu.r_stopxrange = Menu.r:MenuElement({id = "stopxrange", name = "Don't when enemies in x range", value = 600, min = 0, max = 1000, step = 100})
    Menu.r_xenemies = Menu.r:MenuElement({id = "xenemies", name = "When can hit x enemies", value = 2, min = 1, max = 5, step = 1})
    Menu.r_xtime = Menu.r:MenuElement({id = "xtime", name = "When time to hit < x", value = 3.0, min = 1.0, max = 10.0, step = 0.5})
    Menu.r_hitchance = Menu.r:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high", "immobile"}})
    Menu.r:MenuElement({name = "Extras", id = "extras", type = _G.MENU})
    Menu.r_extras_ks = Menu.r.extras:MenuElement({id = 'ks', name = 'KS', value = false})
    Menu.r_extras_immobile = Menu.r.extras:MenuElement({id = 'immobile', name = 'Immobile', value = false})
    Menu.r:MenuElement({name = "Semi Manual", id = "semi", type = _G.MENU})
    Menu.r_semi_key = Menu.r.semi:MenuElement({name = "Semi-Manual Key", id = "key", key = string.byte("T")})
    Menu.r_semi_xenemies = Menu.r.semi:MenuElement({id = "xenemies", name = "When can hit x enemies", value = 1, min = 1, max = 5, step = 1})
    Menu.r_semi_xtime = Menu.r.semi:MenuElement({id = "xtime", name = "When time to hit < x", value = 6.0, min = 1.0, max = 10.0, step = 0.5})
    Menu.r_semi_hitchance = Menu.r.semi:MenuElement({id = "hitchance", name = "Hitchance", value = 1, drop = {"normal", "high", "immobile"}})
    
    Menu.d:MenuElement({name = "Auto Q", id = "autoq", type = _G.MENU})
    Menu.d_autoq_enabled = Menu.d.autoq:MenuElement({id = "enabled", name = "Enabled", value = true})
    Menu.d_autoq_size = Menu.d.autoq:MenuElement({id = "size", name = "Text Size", value = 25, min = 1, max = 64, step = 1})
    Menu.d_autoq_custom = Menu.d.autoq:MenuElement({id = "custom", name = "Custom Position", value = false})
    Menu.d_autoq_width = Menu.d.autoq:MenuElement({id = "posX", name = "Text Position Width", value = Game.Resolution().x * 0.5 - 150, min = 1, max = Game.Resolution().x, step = 1})
    Menu.d_autoq_height = Menu.d.autoq:MenuElement({id = "posY", name = "Text Position Height", value = Game.Resolution().y * 0.5, min = 1, max = Game.Resolution().y, step = 1})
    
    -- locals
    local LastEFake = 0
    local QPrediction = GGPrediction:SpellPrediction({Delay = 0.25, Radius = 60, Range = 1150, Speed = 2000, Collision = true, Type = GGPrediction.SPELLTYPE_LINE})
    local WPrediction = GGPrediction:SpellPrediction({Delay = 0.25, Radius = 60, Range = 1150, Speed = 1200, Collision = false, Type = GGPrediction.SPELLTYPE_LINE})
    local RPrediction = GGPrediction:SpellPrediction({Delay = 1, Radius = 160, Range = 20000, Speed = 2000, Collision = false, Type = GGPrediction.SPELLTYPE_LINE})
    
    -- champion
    Champion =
    {
        CanAttackCb = function()
            return GG_Spell:CanTakeAction({q = 0.33, w = 0.33, e = 0.33, r = 1.13})
        end,
        CanMoveCb = function()
            return GG_Spell:CanTakeAction({q = 0.23, w = 0.23, e = 0.23, r = 1})
        end,
        OnPostAttackTick = function(PostAttackTimer)
            Champion:PreTick()
            Champion.QWTargets = Utils:GetEnemyHeroes(QPrediction.Range)
            Champion:WLogic()
            Champion:QLogic()
            Champion:RLogic()
        end,
    }
    -- load
    function Champion:OnLoad()
        local getDamage = function()
            return ((25 * myHero:GetSpellData(_Q).level) - 10) + (1.1 * myHero.totalDamage) + (0.4 * myHero.ap)
        end
        local canLastHit = function()
            return Menu.q_lh_enabled:Value() and self.ManaPercent >= Menu.q_lh_mana:Value()
        end
        local canLaneClear = function()
            return Menu.q_lc_enabled:Value() and self.ManaPercent >= Menu.q_lc_mana:Value()
        end
        local isQReady = function()
            return GG_Spell:IsReady(_Q, {q = 0.33, w = 0.33, e = 0.2, r = 0.77})
        end
        GG_Spell:SpellClear(_Q, QPrediction, isQReady, canLastHit, canLaneClear, getDamage)
    end
    -- wnd msg
    function Champion:OnWndMsg(msg, wParam)
        if wParam == Menu.e_fake:Key() then
            LastEFake = os.clock()
        end
    end
    -- tick
    function Champion:OnTick()
        self:ELogic()
        if self.IsAttacking or self.CanAttackTarget or self.AttackTarget then
            return
        end
        self.QWTargets = Utils:GetEnemyHeroes(QPrediction.Range)
        self:WLogic()
        self:QLogic()
        self:RLogic()
    end
    -- q logic
    function Champion:QLogic()
        if not GG_Spell:IsReady(_Q, {q = 1, w = 0.33, e = 0.33, r = 1.13}) then
            return
        end
        self:QAuto()
        self:QCombo()
    end
    -- w logic
    function Champion:WLogic()
        if not GG_Spell:IsReady(_W, {q = 0.33, w = 1, e = 0.33, r = 1.13}) then
            return
        end
        self:WCombo()
    end
    -- e logic
    function Champion:ELogic()
        local timer = GetTickCount()
        if self.EHelper ~= nil then
            if GG_Cursor.Step == 0 then
                GG_Cursor:Add(self.EHelper, myHero.pos:Extended(Vector(mousePos), 600))
                self.EHelper = nil
            end
            return
        end
        if not(os.clock() < LastEFake + 0.5 and Game.CanUseSpell(_E) == 0 and not Control.IsKeyDown(HK_LUS) and not myHero.dead and not Game.IsChatOpen() and Game.IsOnTop()) then
            return
        end
        if self.LastE and timer < self.LastE + 1000 then
            return
        end
        if timer < LastChatOpenTimer + 1000 then
            return
        end
        if timer < LevelUpKeyTimer + 1000 then
            return
        end
        self.LastE = timer
        if GG_Cursor.Step == 0 then
            GG_Cursor:Add(Menu.e_lol:Key(), myHero.pos:Extended(Vector(mousePos), 600))
            return
        end
        self.EHelper = Menu.e_lol:Key()
    end
    -- r logic
    function Champion:RLogic()
        if not GG_Spell:IsReady(_R, {q = 0.33, w = 0.33, e = 0.33, r = 1}) then
            return
        end
        if Menu.r_stopaa:Value() and self.AttackTarget then
            return
        end
        local enemies = Utils:GetEnemyHeroes(Menu.r_stopxrange:Value())
        if #enemies > 0 then
            return
        end
        self.RCasted = false
        self.IsRAuto = Menu.r_auto:Value()
        self.IsRKS = Menu.r_extras_ks:Value()
        self.IsRImmobile = Menu.r_extras_immobile:Value()
        self.IsRSemiKey = Menu.r_semi_key:Value()
        self.IsRCombo = self.IsCombo and Menu.r_combo:Value()
        self.IsRHarass = self.IsHarass and Menu.r_harass:Value()
        self.RHitChance = Menu.r_hitchance:Value() + 1
        self.RAOE = {}
        if self.IsRAuto or self.IsRCombo or self.IsRHarass or self.IsRSemiKey or self.IsRKS or self.IsRImmobile then
            self.RAOE = RPrediction:GetAOEPrediction(myHero)
        end
        if #self.RAOE == 0 then
            return
        end
        self:RCombo()
        self:RSemiManual()
        self:RImmobile()
        self:RKS()
    end
    -- r combo/harass/auto
    function Champion:RCombo()
        if not(Menu.r_auto:Value() or (self.IsCombo and Menu.r_combo:Value()) or (self.IsHarass and Menu.r_harass:Value())) then
            return
        end
        local hitchance = Menu.r_hitchance:Value() + 1
        local minenemies = Menu.r_xenemies:Value()
        local timetohit = Menu.r_xtime:Value()
        local bestaoe = nil
        local bestcount = 0
        local bestdistance = 1000
        for i = 1, #self.RAOE do
            local aoe = self.RAOE[i]
            if aoe.HitChance >= hitchance and aoe.TimeToHit <= timetohit and aoe.Count >= minenemies then
                if aoe.Count > bestcount or (aoe.Count == bestcount and aoe.Distance < bestdistance) then
                    bestdistance = aoe.Distance
                    bestcount = aoe.Count
                    bestaoe = aoe
                end
            end
        end
        if bestaoe then
            Control.CastSpell(HK_R, bestaoe.CastPosition)
            self.RCasted = true
        end
    end
    -- r semi manual
    function Champion:RSemiManual()
        if self.RCasted or not Menu.r_semi_key:Value() then
            return
        end
        local hitchance = Menu.r_semi_hitchance:Value() + 1
        local minenemies = Menu.r_semi_xenemies:Value()
        local timetohit = Menu.r_semi_xtime:Value()
        local bestaoe = nil
        local bestcount = 0
        local bestdistance = 1000
        for i = 1, #self.RAOE do
            local aoe = self.RAOE[i]
            if aoe.HitChance >= hitchance and aoe.TimeToHit <= timetohit and aoe.Count >= minenemies then
                if aoe.Count > bestcount or (aoe.Count == bestcount and aoe.Distance < bestdistance) then
                    bestdistance = aoe.Distance
                    bestcount = aoe.Count
                    bestaoe = aoe
                end
            end
        end
        if bestaoe then
            Control.CastSpell(HK_R, bestaoe.CastPosition)
            self.RCasted = true
        end
    end
    -- r immobile
    function Champion:RImmobile()
        if self.RCasted or not Menu.r_extras_immobile:Value() then
            return
        end
        local hitchance = HITCHANCE_IMMOBILE
        local minenemies = 1
        local bestaoe = nil
        local bestcount = 0
        local bestdistance = 1000
        for i = 1, #self.RAOE do
            local aoe = self.RAOE[i]
            if aoe.HitChance >= hitchance and aoe.Count >= minenemies then
                if aoe.Count > bestcount or (aoe.Count == bestcount and aoe.Distance < bestdistance) then
                    bestdistance = aoe.Distance
                    bestcount = aoe.Count
                    bestaoe = aoe
                end
            end
        end
        if bestaoe then
            Control.CastSpell(HK_R, bestaoe.CastPosition)
            self.RCasted = true
        end
    end
    -- r ks
    function Champion:RKS()
        if self.RCasted or not Menu.r_extras_ks:Value() then
            return
        end
        local rdata = myHero:GetSpellData(_R)
        local rDamage = 200 + myHero.bonusDamage + (0.9 * myHero.ap) + (150 * rdata.level)
        local hitchance = HITCHANCE_HIGH
        local minenemies = 1
        local bestaoe = nil
        local bestcount = 0
        local bestdistance = 1000
        for i = 1, #self.RAOE do
            local aoe = self.RAOE[i]
            if aoe.HitChance >= hitchance and aoe.TimeToHit <= 3.0 and aoe.Count >= minenemies then
                local health = aoe.Unit.health
                if GG_Damage:CalculateDamage(myHero, aoe.Unit, DAMAGE_TYPE_MAGICAL, rDamage) > health and not aoe.Unit.dead and aoe.Unit.alive then
                    local ok = true
                    local allies = GG_Object:GetAllyHeroes(RPrediction.Range)
                    for j = 1, #allies do
                        local ally = allies[j]
                        if not ally.isMe then
                            if GGPrediction:GetDistance(ally.pos, aoe.Unit.pos) < 600 and ally.health > 600 then
                                ok = false
                            end
                        end
                    end
                    if ok then
                        if aoe.Count > bestcount or (aoe.Count == bestcount and aoe.Distance < bestdistance) then
                            bestdistance = aoe.Distance
                            bestcount = aoe.Count
                            bestaoe = aoe
                        end
                    end
                end
            end
        end
        if bestaoe then
            Control.CastSpell(HK_R, bestaoe.CastPosition)
            self.RCasted = true
        end
    end
    -- q auto
    function Champion:QAuto()
        if not Menu.q_auto_enabled:Value() then
            return
        end
        if self.ManaPercent < Menu.q_auto_mana:Value() then
            return
        end
        for i, unit in ipairs(self.QWTargets) do
            Utils:Cast(HK_Q, unit, QPrediction, Menu.q_auto_hitchance:Value() + 1)
        end
    end
    -- q combo
    function Champion:QCombo()
        if not((self.IsCombo and Menu.q_combo:Value()) or (self.IsHarass and Menu.q_harass:Value())) then
            return
        end
        local target = self.AttackTarget ~= nil and self.AttackTarget or GG_Target:GetTarget(self.QWTargets, DAMAGE_TYPE_PHYSICAL)
        Utils:Cast(HK_Q, target, QPrediction, Menu.q_hitchance:Value() + 1)
    end
    -- w combo
    function Champion:WCombo()
        if not((self.IsCombo and Menu.w_combo:Value()) or (self.IsHarass and Menu.w_harass:Value())) then
            return
        end
        if self.ManaPercent < Menu.w_mana:Value() then
            return
        end
        local target = self.AttackTarget ~= nil and self.AttackTarget or GG_Target:GetTarget(self.QWTargets, DAMAGE_TYPE_PHYSICAL)
        Utils:Cast(HK_W, target, WPrediction, Menu.w_hitchance:Value() + 1)
    end
    -- draw
    function Champion:OnDraw()
        if Menu.d_autoq_enabled:Value() then
            local posX, posY
            if Menu.d_autoq_custom:Value() then
                posX = Menu.d_autoq_width:Value()
                posY = Menu.d_autoq_height:Value()
            else
                local mePos = myHero.pos:To2D()
                posX = mePos.x - 50
                posY = mePos.y
            end
            if Menu.q_auto_enabled:Value() then
                Draw.Text("Auto Q Enabled", Menu.d_autoq_size:Value(), posX, posY, Draw.Color(255, 000, 255, 000))
            else
                Draw.Text("Auto Q Disabled", Menu.d_autoq_size:Value(), posX, posY, Draw.Color(255, 255, 000, 000))
            end
        end
    end
end

if Champion == nil and myHero.charName == 'KogMaw' then
    --menu
    Menu.q_combo = Menu.q:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.q_harass = Menu.q:MenuElement({id = 'harass', name = 'Harass', value = true})
    Menu.q_hitchance = Menu.q:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high", "immobile"}})
    
    Menu.w_combo = Menu.w:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.w_harass = Menu.w:MenuElement({id = 'harass', name = 'Harass', value = false})
    Menu.w_stopq = Menu.w:MenuElement({id = "stopq", name = "Stop using Q when has W", value = false})
    Menu.w_stope = Menu.w:MenuElement({id = "stope", name = "Stop using E when has W", value = false})
    Menu.w_stopr = Menu.w:MenuElement({id = "stopr", name = "Stop using R when has W", value = false})
    
    Menu.e_combo = Menu.e:MenuElement({id = "combo", name = "Combo", value = true})
    Menu.e_harass = Menu.e:MenuElement({id = "harass", name = "Harass", value = false})
    Menu.e_mana = Menu.e:MenuElement({id = "mana", name = "Minimum Mana %", value = 20, min = 1, max = 100, step = 1})
    Menu.e_hitchance = Menu.e:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high", "immobile"}})
    
    Menu.r_combo = Menu.r:MenuElement({id = "combo", name = "Combo", value = true})
    Menu.r_harass = Menu.r:MenuElement({id = "harass", name = "Harass", value = false})
    Menu.r_onlylow = Menu.r:MenuElement({id = "onlylow", name = "Only 0-40 % HP enemies", value = true})
    Menu.r_xstacks = Menu.r:MenuElement({id = "xstacks", name = "Stop at x stacks", value = 3, min = 1, max = 9, step = 1})
    Menu.r_mana = Menu.r:MenuElement({id = "mana", name = "Minimum Mana %", value = 20, min = 1, max = 100, step = 1})
    Menu.r_hitchance = Menu.r:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high", "immobile"}})
    Menu.r:MenuElement({name = "KS", id = "ks", type = _G.MENU})
    Menu.r_ks_enabled = Menu.r.ks:MenuElement({id = "enabled", name = "Enabled", value = true})
    Menu.r_ks_stack = Menu.r.ks:MenuElement({id = "stack", name = "Check for R stacks", value = false})
    Menu.r_ks_hitchance = Menu.r.ks:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high", "immobile"}})
    Menu.r:MenuElement({name = "Semi Manual", id = "semi", type = _G.MENU})
    Menu.r_semi_key = Menu.r.semi:MenuElement({name = "Semi-Manual Key", id = "key", key = string.byte("T")})
    Menu.r_semi_stack = Menu.r.semi:MenuElement({name = "Check R stacks", id = "stack", value = false})
    Menu.r_semi_onlylow = Menu.r.semi:MenuElement({name = "Only 0-40 % HP enemies", id = "onlylow", value = false})
    Menu.r_semi_hitchance = Menu.r.semi:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high", "immobile"}})
    Menu.r_semi_useon = Menu.r.semi:MenuElement({name = "Use on", id = "useon", type = _G.MENU})
    
    -- locals
    local LastW = 0
    local QPrediction = GGPrediction:SpellPrediction({Delay = 0.25, Radius = 70, Range = 1175, Speed = 1650, Collision = true, Type = GGPrediction.SPELLTYPE_LINE})
    local EPrediction = GGPrediction:SpellPrediction({Delay = 0.25, Radius = 120, Range = 1280, Speed = 1350, Collision = false, Type = GGPrediction.SPELLTYPE_LINE})
    local RPrediction = GGPrediction:SpellPrediction({Delay = 1.3, Radius = 90, Range = 0, Speed = math.huge, Collision = false, Type = GGPrediction.SPELLTYPE_CIRCLE})
    
    -- champion
    Champion =
    {
        CanAttackCb = function()
            if Game.CanUseSpell(_W) == 0 and Game.Timer() < GG_Spell.WTimer + 0.33 then
                return
            end
            return GG_Spell:CanTakeAction({q = 0.33, w = 0, e = 0.33, r = 0.33})
        end,
        CanMoveCb = function()
            return GG_Spell:CanTakeAction({q = 0.23, w = 0, e = 0.23, r = 0.23})
        end,
        OnPreAttack = function(args)
            Champion:PreTick()
            if Game.CanUseSpell(_W) ~= 0 then
                return
            end
            if not((Champion.IsCombo and Menu.w_combo:Value()) or (Champion.IsHarass and Menu.w_harass:Value())) then
                return
            end
            local enemies = GG_Object:GetEnemyHeroes(610 + (20 * myHero:GetSpellData(_W).level) + myHero.boundingRadius - 35, true, true, true)
            if #enemies > 0 then
                Utils:Cast(HK_W)
                LastW = GetTickCount()
            end
        end,
        OnPostAttackTick = function(PostAttackTimer)
            Champion:PreTick()
            Champion:QLogic()
            Champion:ELogic()
            Champion:RLogic()
        end,
    }
    function Champion:QLaneClear()
        local getQDamage = function()
            local level = myHero:GetSpellData(_Q).level
            local adratio = (37.5 + (7.5 * level)) / 100
            return 20 + (25 * level) + (adratio * myHero.totalDamage) + (0.6 * myHero.ap)
        end
        local canQLastHit = function()
            return true
        end
        local canQLaneClear = function()
            return true
        end
        local isQReady = function()
            return GG_Spell:IsReady(_Q, {q = 0.33, w = 0.77, e = 0.33, r = 0.77})
        end
        GG_Spell:SpellClear(_Q, QPrediction, isQReady, canQLastHit, canQLaneClear, getQDamage)
    end
    function Champion:ELaneClear()
        local getQDamage = function()
            local level = myHero:GetSpellData(_Q).level
            local adratio = (37.5 + (7.5 * level)) / 100
            return 20 + (25 * level) + (adratio * myHero.totalDamage) + (0.6 * myHero.ap)
        end
        local canQLastHit = function()
            return true
        end
        local canQLaneClear = function()
            return true
        end
        local isQReady = function()
            return GG_Spell:IsReady(_E, {q = 0.33, w = 0.77, e = 0.33, r = 0.77})
        end
        GG_Spell:SpellClear(_E, EPrediction, isQReady, canQLastHit, canQLaneClear, getQDamage)
    end
    
    -- load
    function Champion:OnLoad()
        --self:QLaneClear()
        --self:ELaneClear()
        GG_Object:OnEnemyHeroLoad(function(args) Menu.r_semi_useon:MenuElement({id = args.charName, name = args.charName, value = true}) end)
    end
    -- tick
    function Champion:OnTick()
        self.WMana = myHero.mana - 40 - (myHero:GetSpellData(_W).currentCd * myHero.mpRegen)
        if not self.IsAttacking then
            self:RKS()
        end
        self:WLogic()
        if self.IsAttacking or self.CanAttackTarget or self.AttackTarget then
            return
        end
        self.HasWBuff = GG_Buff:HasBuff(myHero, "KogMawBioArcaneBarrage")
        if GetTickCount() < LastW + 300 or self.Timer < GG_Spell.WkTimer + 0.3 then
            return
        end
        self:QLogic()
        self:ELogic()
        self:RLogic()
    end
    -- q logic
    function Champion:QLogic()
        if not GG_Spell:IsReady(_Q, {q = 0.33, w = 0, e = 0.33, r = 0.33}) then
            return
        end
        if self.WMana < myHero:GetSpellData(_Q).mana then
            return
        end
        self:QCombo()
    end
    -- w logic
    function Champion:WLogic()
        if Game.CanUseSpell(_W) ~= 0 then
            return
        end
        --normal game:
        self:WCombo()
        --urf:
        --if self.IsCombo or self.IsLaneClear then Utils:Cast(HK_W) end
    end
    -- e logic
    function Champion:ELogic()
        if not GG_Spell:IsReady(_E, {q = 0.33, w = 0, e = 0.33, r = 0.33}) then
            return
        end
        if self.WMana < myHero:GetSpellData(_E).mana then
            return
        end
        self:ECombo()
    end
    -- r logic
    function Champion:RLogic()
        if not GG_Spell:IsReady(_R, {q = 0.33, w = 0, e = 0.33, r = 1}) then
            return
        end
        if self.WMana < myHero:GetSpellData(_R).mana then
            return
        end
        RPrediction.Range = 900 + 300 * myHero:GetSpellData(_R).level
        self.RTargets = Utils:GetEnemyHeroes(RPrediction.Range)
        self.RStacks = GG_Buff:GetBuffCount(myHero, "kogmawlivingartillerycost")
        self:RSemiManual()
        self:RCombo()
    end
    -- q combo
    function Champion:QCombo()
        if not((self.IsCombo and Menu.q_combo:Value()) or (self.IsHarass and Menu.q_harass:Value())) then
            return
        end
        if Menu.w_stopq:Value() and self.HasWBuff then
            return
        end
        local target = self.AttackTarget ~= nil and self.AttackTarget or GG_Target:GetTarget(Utils:GetEnemyHeroes(1175), DAMAGE_TYPE_MAGICAL)
        Utils:Cast(HK_Q, target, QPrediction, Menu.q_hitchance:Value() + 1)
    end
    -- w combo
    function Champion:WCombo()
        if not((self.IsCombo and Menu.w_combo:Value()) or (self.IsHarass and Menu.w_harass:Value())) then
            return
        end
        if self.AttackTarget then
            return
        end
        local enemies = GG_Object:GetEnemyHeroes(610 + (20 * myHero:GetSpellData(_W).level) + myHero.boundingRadius - 35, true, true, true)
        if #enemies > 0 then
            Utils:Cast(HK_W)
            LastW = GetTickCount()
        end
    end
    -- e combo
    function Champion:ECombo()
        if not((self.IsCombo and Menu.e_combo:Value()) or (self.IsHarass and Menu.e_harass:Value())) then
            return
        end
        if Menu.w_stope:Value() and self.HasWBuff then
            return
        end
        if self.ManaPercent < Menu.e_mana:Value() then
            return
        end
        local target = self.AttackTarget ~= nil and self.AttackTarget or GG_Target:GetTarget(Utils:GetEnemyHeroes(1280), DAMAGE_TYPE_MAGICAL)
        Utils:Cast(HK_E, target, EPrediction, Menu.e_hitchance:Value() + 1)
    end
    -- r combo
    function Champion:RCombo()
        if not((self.IsCombo and Menu.r_combo:Value()) or (self.IsHarass and Menu.r_harass:Value())) then
            return
        end
        if Menu.w_stopr:Value() and self.HasWBuff then
            return
        end
        if self.ManaPercent < Menu.r_mana:Value() then
            return
        end
        if self.RStacks >= Menu.r_xstacks:Value() then
            return
        end
        local enemies = {}
        local target = self.AttackTarget
        if Menu.r_onlylow:Value() then
            if target and target.health * 100 / target.maxHealth >= 40 then
                target = nil
            end
            if target == nil then
                for i, unit in ipairs(self.RTargets) do
                    if ((unit.health + (unit.hpRegen * 3)) * 100) / unit.maxHealth < 40 then
                        table_insert(enemies, unit)
                    end
                end
            end
        elseif target == nil then
            enemies = self.RTargets
        end
        Utils:Cast(HK_R, target ~= nil and target or GG_Target:GetTarget(enemies, DAMAGE_TYPE_MAGICAL), RPrediction, Menu.r_hitchance:Value() + 1)
    end
    -- r ks
    function Champion:RKS()
        if not GG_Spell:IsReady(_R, {q = 0.33, w = 0, e = 0.33, r = 1}) then
            return
        end
        if self.WMana < myHero:GetSpellData(_R).mana then
            return
        end
        RPrediction.Range = 900 + 300 * myHero:GetSpellData(_R).level
        self.RTargets = Utils:GetEnemyHeroes(RPrediction.Range)
        self.RStacks = GG_Buff:GetBuffCount(myHero, "kogmawlivingartillerycost")
        if not Menu.r_ks_enabled:Value() then
            return
        end
        if Menu.r_ks_stack:Value() and self.RStacks >= Menu.r_xstacks:Value() then
            return
        end
        local baseRDmg = 60 + (40 * myHero:GetSpellData(_R).level) + (myHero.bonusDamage * 0.65) + (myHero.ap * 0.25)
        for i, unit in ipairs(self.RTargets) do
            local health = unit.health
            local hpRegen = unit.hpRegen
            local rMultipier = math.floor(100 - (((health + (hpRegen * 3)) * 100) / unit.maxHealth))
            local rDmg = rMultipier > 60 and baseRDmg * 2 or baseRDmg * (1 + (rMultipier * 0.00833))
            if GG_Damage:CalculateDamage(myHero, unit, DAMAGE_TYPE_MAGICAL, rDmg) > health + (hpRegen * 2) then
                if Utils:Cast(HK_R, GG_Target:GetTarget(enemies, DAMAGE_TYPE_MAGICAL), RPrediction, Menu.r_ks_hitchance:Value() + 1) then
                    break
                end
            end
        end
    end
    -- r semi manual
    function Champion:RSemiManual()
        if not Menu.r_semi_key:Value() then
            return
        end
        if Menu.r_semi_stack:Value() and self.RStacks >= Menu.r_xstacks:Value() then
            return
        end
        local enemies = {}
        if Menu.r_semi_onlylow:Value() then
            for i, unit in ipairs(self.RTargets) do
                if ((unit.health + (unit.hpRegen * 3)) * 100) / unit.maxHealth < 40 then
                    table_insert(enemies, unit)
                end
            end
        else
            enemies = self.RTargets
        end
        local useonenemies = {}
        for i, unit in ipairs(enemies) do
            local canuse = Menu.r_semi_useon[unit.charName]
            if canuse and canuse:Value() then
                table_insert(useonenemies, unit)
            end
        end
        Utils:Cast(HK_R, GG_Target:GetTarget(useonenemies, DAMAGE_TYPE_MAGICAL), RPrediction, Menu.r_semi_hitchance:Value() + 1)
    end
end

if Champion == nil and myHero.charName == 'Varus' then
    -- menu values
    local MENU_Q_COMBO = true
    local MENU_Q_HARASS = false
    local MENU_Q_WSTACKS = true
    local MENU_Q_SKIP_WSTACKS = false
    local MENU_Q_TIME = 0.5
    local MENU_Q_RANGE = 300
    local MENU_Q_HITCHANCE = 2
    local MENU_W_COMBO = true
    local MENU_W_HARASS = false
    local MENU_W_HP = 50
    local MENU_E_COMBO = true
    local MENU_E_HARASS = false
    local MENU_E_WSTACKS = true
    local MENU_E_SKIP_WSTACKS = false
    local MENU_E_HITCHANCE = 2
    local MENU_R_COMBO = true
    local MENU_R_HARASS = false
    local MENU_R_XHeroHP = 200
    local MENU_R_XEnemyHP = 600
    local MENU_R_XRANGE = 500
    local MENU_R_HITCHANCE = 2
    
    -- menu
    Menu.q:MenuElement({id = "combo", name = "Combo", value = MENU_Q_COMBO, callback = function(x) MENU_Q_COMBO = x end})
    Menu.q:MenuElement({id = "harass", name = "Harass", value = MENU_Q_HARASS, callback = function(x) MENU_Q_HARASS = x end})
    Menu.q:MenuElement({id = "wstacks", name = "when enemy has W buff x3", value = MENU_Q_WSTACKS, callback = function(x) MENU_Q_WSTACKS = x end})
    Menu.q:MenuElement({id = "wstacksskip", name = "skip W buff check if no attack target", value = MENU_Q_SKIP_WSTACKS, callback = function(x) MENU_Q_SKIP_WSTACKS = x end})
    Menu.q:MenuElement({id = "xtime", name = "minimum charging time", value = MENU_Q_TIME, min = 0.1, max = 1.4, step = 0.1, callback = function(x) MENU_Q_TIME = x end})
    Menu.q:MenuElement({id = "xrange", name = "charging time only if no enemies in aarange + x", value = MENU_Q_RANGE, min = 100, max = 600, step = 10, callback = function(x) MENU_Q_RANGE = x end})
    Menu.q:MenuElement({id = "hitchance", name = "Hitchance", value = MENU_Q_HITCHANCE, drop = {"normal", "high", "immobile"}, callback = function(x) MENU_Q_HITCHANCE = x end})
    Menu.w:MenuElement({id = "combo", name = "Combo", value = MENU_W_COMBO, callback = function(x) MENU_W_COMBO = x end})
    Menu.w:MenuElement({id = "harass", name = "Harass", value = MENU_W_HARASS, callback = function(x) MENU_W_HARASS = x end})
    Menu.w:MenuElement({id = "hp", name = "enemy %hp less than", value = MENU_W_HP, min = 1, max = 100, step = 1, callback = function(x) MENU_W_HP = x end})
    Menu.e:MenuElement({id = "combo", name = "Combo", value = MENU_E_COMBO, callback = function(x) MENU_E_COMBO = x end})
    Menu.e:MenuElement({id = "harass", name = "Harass", value = MENU_E_HARASS, callback = function(x) MENU_E_HARASS = x end})
    Menu.e:MenuElement({id = "wstacks", name = "when enemy has W buff x3", value = MENU_E_WSTACKS, callback = function(x) MENU_E_WSTACKS = x end})
    Menu.e:MenuElement({id = "wstacksskip", name = "skip W buff check if no attack target", value = MENU_E_SKIP_WSTACKS, callback = function(x) MENU_E_SKIP_WSTACKS = x end})
    Menu.e:MenuElement({id = "hitchance", name = "Hitchance", value = MENU_E_HITCHANCE, drop = {"normal", "high", "immobile"}, callback = function(x) MENU_E_HITCHANCE = x end})
    Menu.r:MenuElement({id = "combo", name = "Use R Combo", value = MENU_R_COMBO, callback = function(x) MENU_R_COMBO = x end})
    Menu.r:MenuElement({id = "harass", name = "Use R Harass", value = MENU_R_HARASS, callback = function(x) MENU_R_HARASS = x end})
    Menu.r:MenuElement({id = "xherohp", name = "hero near to death hp", value = MENU_R_XHeroHP, min = 100, max = 1000, step = 50, callback = function(x) MENU_R_XHeroHP = x end})
    Menu.r:MenuElement({id = "xenemyhp", name = "enemy health above", value = MENU_R_XEnemyHP, min = 100, max = 1000, step = 50, callback = function(x) MENU_R_XEnemyHP = x end})
    Menu.r:MenuElement({id = "xrange", name = "enemy in range", value = MENU_R_XRANGE, min = 250, max = 1000, step = 50, callback = function(x) MENU_R_XRANGE = x end})
    Menu.r:MenuElement({id = "hitchance", name = "Hitchance", value = MENU_R_HITCHANCE, drop = {"normal", "high", "immobile"}, callback = function(x) MENU_R_HITCHANCE = x end})
    Menu.r:MenuElement({name = "Semi Manual", id = "semi", type = _G.MENU})
    Menu.r_semi_key = Menu.r.semi:MenuElement({name = "Semi-Manual Key", id = "key", key = string.byte("T")})
    Menu.r_semi_hitchance = Menu.r.semi:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high", "immobile"}})
    
    -- locals
    local QPrediction = GGPrediction:SpellPrediction({Delay = 0.1, Radius = 70, Range = 1650, Speed = 1900, Collision = false, Type = GGPrediction.SPELLTYPE_LINE})
    local EPrediction = GGPrediction:SpellPrediction({Delay = 0.5, Radius = 235, Range = 925, Speed = 1500, Collision = false, Type = GGPrediction.SPELLTYPE_CIRCLE})
    local RPrediction = GGPrediction:SpellPrediction({Delay = 0.25, Radius = 120, Range = 1075, Speed = 1950, Collision = false, Type = GGPrediction.SPELLTYPE_LINE})
    
    -- champion
    Champion =
    {
        CanAttackCb = function()
            return not Champion:HasQBuff() and GG_Spell:CanTakeAction({q = 0.33, w = 0, e = 0.33, r = 0.33})
        end,
        CanMoveCb = function()
            return GG_Spell:CanTakeAction({q = 0.2, w = 0, e = 0.2, r = 0.2})
        end,
    }
    -- has q buff
    function Champion:HasQBuff()
        return GG_Buff:HasBuff(myHero, "varusq") or self.Timer < GG_Spell.QTimer + 0.5
    end
    -- on tick
    function Champion:OnTick()
        if self:HasQBuff() then
            if not self.IsCombo and not self.IsHarass then
                return
            end
            self:QBuffLogic()
            return
        end
        if Control.IsKeyDown(HK_Q) and (self.IsCombo or self.IsHarass) and not GG_Buff:HasBuff(myHero, "varusq") and self.Timer > GG_Spell.QTimer + 0.5 and self.Timer > GG_Spell.QkTimer + 0.5 and Game.CanUseSpell(_Q) == 0 then
            Control.KeyUp(HK_Q)
        end
        if self.IsAttacking or self.CanAttackTarget then
            return
        end
        self.WSpellData = myHero:GetSpellData(_W)
        self:RLogic()
        self:ELogic()
        self:QLogic()
    end
    -- q can up
    function Champion:QCanUp(target)
        if target == nil then
            return false
        end
        QPrediction:GetPrediction(target, myHero)
        if QPrediction:CanHit(MENU_Q_HITCHANCE + 1) then
            --local pos = myHero.pos
            --if GGPrediction:GetDistance(pos, QPrediction.UnitPosition) > GGPrediction:GetDistance(pos, target.pos) + 75 then
            return true
            --end
        end
        return false
    end
    -- q buff logic
    function Champion:QBuffLogic()
        if not Control.IsKeyDown(HK_Q) then
            return
        end
        local qtimer = self.Timer - GG_Spell.QTimer
        if qtimer > 6 then
            return
        end
        local aaenemies = Utils:GetEnemyHeroes(myHero.range + MENU_Q_RANGE)
        if #aaenemies == 0 and qtimer < MENU_Q_TIME then
            return
        end
        QPrediction.Range = 925 + (qtimer * 0.5 * 700)
        local canusew = Game.CanUseSpell(_W) == 0 and ((self.IsCombo and MENU_W_COMBO) or (self.IsHarass and MENU_W_HARASS))
        local enemies = Utils:GetEnemyHeroes(QPrediction.Range)
        if self:QCanUp(self.AttackTarget) and GGPrediction:GetDistance(self.AttackTarget.pos, self.Pos) < QPrediction.Range - 50 then
            if canusew and 100 * self.AttackTarget.health / self.AttackTarget.maxHealth < MENU_W_HP then
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
            end
            Control.CastSpell(HK_Q, QPrediction.CastPosition)
            return
        end
        for i = 1, #enemies do
            local enemy = enemies[i]
            if self:QCanUp(enemy) and GGPrediction:GetDistance(enemy.pos, self.Pos) < QPrediction.Range - 50 then
                if canusew and 100 * enemy.health / enemy.maxHealth < MENU_W_HP then
                    Control.KeyDown(HK_W)
                    Control.KeyUp(HK_W)
                end
                Control.CastSpell(HK_Q, QPrediction.CastPosition)
                break
            end
        end
    end
    -- q logic
    function Champion:QLogic()
        if not GG_Spell:IsReady(_Q, {q = 0.33, w = 0, e = 0.6, r = 0.33}) then
            return
        end
        self:QCombo()
    end
    -- q combo
    function Champion:QCombo()
        if not((self.IsCombo and MENU_Q_COMBO) or (self.IsHarass and MENU_Q_HARASS)) then
            return
        end
        local enemies = Utils:GetEnemyHeroes(1500)
        for i = 1, #enemies do
            local enemy = enemies[i]
            if not MENU_Q_WSTACKS or self.WSpellData.level == 0 or GG_Buff:GetBuffCount(enemy, "varuswdebuff") == 3 or (MENU_Q_SKIP_WSTACKS and self.AttackTarget == nil) then
                Control.KeyDown(HK_Q)
                break
            end
        end
    end
    -- e logic
    function Champion:ELogic()
        if not GG_Spell:IsReady(_E, {q = 0.33, w = 0, e = 0.63, r = 0.33}) then
            return
        end
        self:ECombo()
    end
    -- e combo
    function Champion:ECombo()
        if not((self.IsCombo and MENU_E_COMBO) or (self.IsHarass and MENU_E_HARASS)) then
            return
        end
        if self.AttackTarget and (not MENU_E_WSTACKS or self.WSpellData.level == 0 or GG_Buff:GetBuffCount(self.AttackTarget, "varuswdebuff") == 3) then
            if Utils:Cast(HK_E, self.AttackTarget, EPrediction, MENU_E_HITCHANCE + 1) then
                return
            end
        end
        local enemies = Utils:GetEnemyHeroes(EPrediction.Range)
        for i = 1, #enemies do
            local enemy = enemies[i]
            if not MENU_E_WSTACKS or self.WSpellData.level == 0 or GG_Buff:GetBuffCount(enemy, "varuswdebuff") == 3 or (MENU_E_SKIP_WSTACKS and self.AttackTarget == nil) then
                if Utils:Cast(HK_E, enemy, EPrediction, MENU_E_HITCHANCE + 1) then
                    break
                end
            end
        end
    end
    -- r logic
    function Champion:RLogic()
        if not GG_Spell:IsReady(_R, {q = 0.33, w = 0, e = 0.63, r = 0.5}) then
            return
        end
        self:RCombo()
    end
    -- r combo
    function Champion:RCombo()
        if not((self.IsCombo and MENU_R_COMBO) or (self.IsHarass and MENU_R_HARASS)) then
            return
        end
        local nearToDeath = myHero.health <= MENU_R_XHeroHP
        if self.AttackTarget and GGPrediction:GetDistance(self.AttackTarget.pos, self.Pos) < 900 and (nearToDeath or self.AttackTarget.health >= MENU_R_XEnemyHP) then
            if Utils:Cast(HK_R, self.AttackTarget, RPrediction, MENU_R_HITCHANCE + 1) then
                return
            end
        end
        local enemies = Utils:GetEnemyHeroes(RPrediction.Range)
        for i = 1, #enemies do
            local enemy = enemies[i]
            if GGPrediction:GetDistance(enemy.pos, self.Pos) < 900 then
                if nearToDeath or enemy.health >= MENU_R_XEnemyHP then
                    if Utils:Cast(HK_R, enemy, RPrediction, MENU_R_HITCHANCE + 1) then
                        break
                    end
                end
            end
        end
    end
    -- r semi manual
    function Champion:RSemiManual()
        if not Menu.r_semi_key:Value() then
            return
        end
        local enemies = Utils:GetEnemyHeroes(RPrediction.Range)
        for i = 1, #enemies do
            local enemy = enemies[i]
            if Utils:Cast(HK_R, enemy, RPrediction, Menu.r_semi_hitchance:Value() + 1) then
                break
            end
        end
    end
end

if Champion == nil and myHero.charName == 'Quinn' then
    -- version
    local QuinnVersion = '1.01'
    -- hide ggaio menu
    Menu.m:Hide()
    -- premium pred
    if not FileExist(COMMON_PATH .. "PremiumPrediction.lua") then
        print("PremiumPrediction: Library not found! Please download it and put into Common folder!");
        return
    end
    print("Loading PremiumSeries...")
    require "PremiumPrediction"
    print("PremiumSeries successfully loaded!")
    -- mode
    local function GetOrbwalkerMode()
        if _G.SDK then
            return GG_Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] and "Combo"
            or GG_Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] and "Harass"
            or GG_Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] and "LaneClear"
            or nil
        elseif _G.PremiumOrbwalker then
            return _G.PremiumOrbwalker:GetMode()
        end
        return nil
    end
    -- champion
    Champion =
    {
        CanAttackCb = function()
            if not Champion.States[1] and GG_Orbwalker.LastTarget and GG_Orbwalker.LastTarget.type == Obj_AI_Hero then
                if GG_Spell:CanTakeAction({q = 1, w = 0, e = 0.5, r = 0}) and not Champion:HasPassive(GG_Orbwalker.LastTarget) then
                    local success = false
                    if Champion.States[3] then
                        success = Champion:CastQSpell(GG_Orbwalker.LastTarget, "Auto")
                        if not success then success = Champion:CastESpell(GG_Orbwalker.LastTarget, "Auto") end
                    else
                        success = Champion:CastESpell(GG_Orbwalker.LastTarget, "Auto")
                        if not success then success = Champion:CastQSpell(GG_Orbwalker.LastTarget, "Auto") end
                    end
                    if success then
                        return false
                    end
                end
            end
            return not myHero.pathing.isDashing and GG_Spell:CanTakeAction({q = 0.33, w = 0, e = 0.33, r = 0.33})
        end,
        CanMoveCb = function()
            return GG_Spell:CanTakeAction({q = 0.2, w = 0, e = 0.2, r = 0.2})
        end,
        OnPreAttack = function(args)
            Champion:OnPreAttackCb(args)
        end,
        OnPostAttackTick = function(timer)
            Champion:PreTick()
            Champion:OnPostAttackCb(timer)
        end,
    }
    -- init
    function Champion:Init()
        self.Window = {x = Game.Resolution().x * 0.5, y = Game.Resolution().y * 0.5}
        self.AllowMove, self.LastEnemy, self.States = nil, nil, {true, true, true}
        self.Q = {speed = 1550, range = 1025, delay = 0.25, radius = 60, collision = {"minion"}, type = "linear"}
        self.W, self.E = {range = 2100}, {range = 675}
        _G.PremiumPrediction:OnLoseVision(function(...) self:OnLoseVision(...) end)
    end
    Champion:Init()
    -- menu
    function Champion:CreateMenu()
        local Icons, Png = "https://raw.githubusercontent.com/Ark223/LoL-Icons/master/", ".png"
        self.QuinnMenu = MenuElement({type = MENU, id = "Quinn", name = "Premium Quinn v" .. QuinnVersion})
        self.QuinnMenu:MenuElement({id = "Auto", name = "Auto", type = MENU})
        self.QuinnMenu.Auto:MenuElement({id = "UseW", name = "W [Heightened Senses]", value = true, leftIcon = Icons.."QuinnW"..Png})
        self.QuinnMenu:MenuElement({id = "Combo", name = "Combo", type = MENU})
        self.QuinnMenu.Combo:MenuElement({id = "UseQ", name = "Q [Blinding Assault]", value = true, leftIcon = Icons.."QuinnQ"..Png})
        self.QuinnMenu.Combo:MenuElement({id = "UseE", name = "E [Vault]", value = true, leftIcon = Icons.."QuinnE"..Png})
        self.QuinnMenu:MenuElement({id = "Harass", name = "Harass", type = MENU})
        self.QuinnMenu.Harass:MenuElement({id = "UseQ", name = "Q [Blinding Assault]", value = true, leftIcon = Icons.."QuinnQ"..Png})
        self.QuinnMenu.Harass:MenuElement({id = "UseE", name = "E [Vault]", value = false, leftIcon = Icons.."QuinnE"..Png})
        self.QuinnMenu:MenuElement({id = "Interrupter", name = "Interrupter", type = MENU})
        self.QuinnMenu.Interrupter:MenuElement({id = "UseE", name = "E [Vault]", value = true, leftIcon = Icons.."QuinnE"..Png})
        self.QuinnMenu.Interrupter:MenuElement({id = "MeleeE", name = "E: Cast Against Melees", value = true})
        self.QuinnMenu.Interrupter:MenuElement({id = "DashE", name = "E: Cast Against Dashes", value = true})
        self.QuinnMenu.Interrupter:MenuElement({id = "Whitelist", name = "Whitelist:", type = MENU})
        self.QuinnMenu:MenuElement({id = "Drawings", name = "Drawings", type = MENU})
        self.QuinnMenu.Drawings:MenuElement({id = "DrawQ", name = "Q: Draw Range", value = true})
        self.QuinnMenu.Drawings:MenuElement({id = "DrawE", name = "E: Draw Range", value = true})
        self.QuinnMenu.Drawings:MenuElement({id = "Track", name = "Track Enemies", value = true})
        self.QuinnMenu:MenuElement({id = "Misc", name = "Misc", type = MENU})
        self.QuinnMenu.Misc:MenuElement({id = "AA", name = "AA Priority", key = string.byte("1")})
        self.QuinnMenu.Misc:MenuElement({id = "Block", name = "Block Spells On Passive", key = string.byte("2")})
        self.QuinnMenu.Misc:MenuElement({id = "Spell", name = "Spell Priority", key = string.byte("3")})
    end
    Champion:CreateMenu()
    -- METHODS
    -- has passive buff
    function Champion:HasPassive(target)
        if target and target.valid and target.visible and not target.dead then
            return GG_Buff:HasBuff(target, "QuinnW")
        end
        return false
    end
    --CastQSpell
    function Champion:CastQSpell(unit, mode)
        if not (mode == "Combo" and self.QuinnMenu.Combo.UseQ:Value() or (mode == "Harass" and self.QuinnMenu.Harass.UseQ:Value() or mode == "Auto")) then
            return false
        end
        if not GG_Object:IsValid(unit) or not IsInRange(myHero, unit, self.Q.range) or not GG_Spell:IsReady(_Q, {q = 0.33, w = 0, e = 0.33, r = 0.33}) then
            return false
        end
        local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, self.Q)
        if pred.CastPos and pred.HitChance > 0.25 and Utils:Cast(HK_Q, pred.CastPos) then
            return true
        end
        return false
    end
    --CastESpell
    function Champion:CastESpell(unit, mode)
        if not (mode == "Combo" and self.QuinnMenu.Combo.UseE:Value() or (mode == "Harass" and self.QuinnMenu.Harass.UseE:Value() or mode == "Auto")) then
            return false
        end
        if not GG_Object:IsValid(unit) or not IsInRange(myHero, unit, self.E.range) or not GG_Spell:IsReady(_E, {q = 0.33, w = 0, e = 0.33, r = 0.33}) then
            return false
        end
        if Utils:Cast(HK_E, unit.pos) then
            return true
        end
        return false
    end
    --IsInAutoAttackRange
    function Champion:IsInAutoAttackRange(unit)
        return unit and GG_Data:IsInAutoAttackRange(myHero, unit)
    end
    --IsInStatusBox
    function Champion:IsInStatusBox(pt)
        return pt.x >= self.Window.x and pt.x <= self.Window.x + 186 and pt.y >= self.Window.y and pt.y <= self.Window.y + 68
    end
    --GetTarget
    function Champion:GetTarget(range)
        local units = {}
        for i, enemy in ipairs(GG_Object:GetEnemyHeroes(range)) do
            if self:HasPassive(enemy) then
                table.insert(units, enemy)
            end
        end
        return GG_Target:GetTarget(units, DAMAGE_TYPE_PHYSICAL)
    end
    -- EVENTS
    -- on load
    function Champion:OnLoad()
        GG_Object:OnEnemyHeroLoad(function(args)
            self.QuinnMenu.Interrupter.Whitelist:MenuElement({id = args.charName, name = args.charName, value = true})
        end)
    end
    -- on wnd msg
    function Champion:OnWndMsg(msg, wParam)
        self.AllowMove = msg == 513 and wParam == 0 and self:IsInStatusBox(cursorPos) and {x = self.Window.x - cursorPos.x, y = self.Window.y - cursorPos.y} or nil
        if msg == 256 then
            if self.QuinnMenu.Misc.AA:Value() then
                self.States[1] = not self.States[1]
            elseif self.QuinnMenu.Misc.Block:Value() then
                self.States[2] = not self.States[2]
            elseif self.QuinnMenu.Misc.Spell:Value() then
                self.States[3] = not self.States[3]
            end
        end
    end
    --OnPreAttack
    function Champion:OnPreAttackCb(args)
        self.LastEnemy = args.Target
        if self.LastEnemy.type ~= Obj_AI_Hero then return end
        if myHero:GetSpellData(_R).name == "QuinnRFinale" and Utils:Cast(HK_R) then
            args.Process = false
            return
        end
    end
    --OnPostAttack
    function Champion:OnPostAttackCb()
        if not self.LastEnemy or self.LastEnemy.type ~= Obj_AI_Hero then
            return
        end
        local mode = GetOrbwalkerMode()
        if not (mode == "Combo" or mode == "Harass") then return end
        if self.States[2] then
            if not GG_Spell:CanTakeAction({q = 1, w = 0, e = 0.5, r = 0}) then
                return
            end
            if self:HasPassive(self.LastEnemy) then
                return
            end
        end
        if self.States[3] then
            local success = self:CastQSpell(self.LastEnemy, mode)
            if not success then self:CastESpell(self.LastEnemy, mode) end
        else
            local success = self:CastESpell(self.LastEnemy, mode)
            if not success then self:CastQSpell(self.LastEnemy, mode) end
        end
    end
    --OnLoseVision
    function Champion:OnLoseVision(unit)
        if not IsInRange(myHero.pos, unit.pos, myHero.range + myHero.boundingRadius * 2) then
            return
        end
        if GG_Spell:IsReady(_W, {q = 0, w = 0, e = 0, r = 0}) and self.QuinnMenu.Auto.UseW:Value() then
            Utils:Cast(HK_W)
        elseif GG_Spell:IsReady(_Q, {q = 0.33, w = 0, e = 0.33, r = 0.33}) and not _G.PremiumPrediction:IsColliding(myHero, unit.pos, self.Q, {"minion"}) then
            Utils:Cast(HK_Q, unit.pos)
        end
    end
    --OnTick
    function Champion:OnTick()
        self.MyPos = myHero.pos
        if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then
            return
        end
        if myHero:GetSpellData(_R).name == "QuinnRFinale" or GG_Orbwalker:IsAutoAttacking() then
            return
        end
        if self.QuinnMenu.Interrupter.UseE:Value() and GG_Spell:IsReady(_E, {q = 0.33, w = 0, e = 0.33, r = 0}) then
            for _, enemy in ipairs(GG_Object:GetEnemyHeroes(self.E.range)) do
                if enemy.pathing.isDashing then
                    if self.QuinnMenu.Interrupter.DashE:Value() and self.QuinnMenu.Interrupter.Whitelist[enemy.charName]:Value() and GetDistance(self.MyPos, enemy.pathing.endPos) < GetDistance(self.MyPos, enemy.pos) then
                        self:CastESpell(enemy, "Auto")
                        return
                    end
                elseif IsInRange(self.MyPos, enemy.pos, 275) and self.QuinnMenu.Interrupter.MeleeE:Value() then
                    self:CastESpell(enemy, "Auto")
                    return
                end
            end
        end
        local mode = GetOrbwalkerMode()
        if not (mode == "Combo" or mode == "Harass") then
            return
        end
        local t1, t2 = self:GetTarget(self.Q.range), self:GetTarget(self.E.range)
        if not t1 then
            return
        end
        if self.States[1] and self:IsInAutoAttackRange(t1) then
            return
        end
        if self.States[2] then
            if not GG_Spell:CanTakeAction({q = 1, w = 0, e = 0.5, r = 0}) then
                return
            end
            if t1 and self:HasPassive(t1) or t2 and self:HasPassive(t2) then
                return
            end
        end
        if self.States[3] then
            local success = self:CastQSpell(t1, mode)
            if not success then self:CastESpell(t2, mode) end
        else
            local success = self:CastESpell(t2, mode)
            if not success then self:CastQSpell(t1, mode) end
        end
    end
    --OnDraw
    local red, blue, green, white = Draw.Color(192, 220, 20, 60), Draw.Color(192, 0, 191, 255), Draw.Color(192, 50, 205, 50), Draw.Color(192, 255, 255, 255)
    function Champion:OnDraw()
        if Game.IsChatOpen() or myHero.dead then return end
        if self.AllowMove then
            self.Window = {x = cursorPos.x + self.AllowMove.x, y = cursorPos.y + self.AllowMove.y}
        end
        Draw.Rect(self.Window.x, self.Window.y, 186, 68, Draw.Color(224, 23, 23, 23))
        Draw.Text("AA Priority:", 15, self.Window.x + 10, self.Window.y + 5, white)
        Draw.Text(tostring(self.States[1]), 15, self.Window.x + 80, self.Window.y + 5, self.States[1] and green or red)
        Draw.Text("Block Spells On Passive:", 15, self.Window.x + 10, self.Window.y + 25, white)
        Draw.Text(tostring(self.States[2]), 15, self.Window.x + 153, self.Window.y + 25, self.States[2] and green or red)
        Draw.Text("Spell Priority:", 15, self.Window.x + 10, self.Window.y + 45, white)
        Draw.Text(self.States[3] and "Q" or "E", 15, self.Window.x + 92, self.Window.y + 45, blue)
        if self.QuinnMenu.Drawings.DrawQ:Value() then
            Draw.Circle(myHero.pos, self.Q.range, 1, Draw.Color(96, 135, 206, 235))
        end
        if self.QuinnMenu.Drawings.DrawE:Value() then
            Draw.Circle(myHero.pos, self.E.range, 1, Draw.Color(96, 65, 105, 225))
        end
        if self.QuinnMenu.Drawings.Track:Value() then
            for i, enemy in ipairs(GG_Object:GetEnemyHeroes()) do
                Draw.Line(myHero.pos:To2D(), enemy.pos:To2D(), 2.5,
                    IsInRange(myHero, enemy, 2000) and Draw.Color(128, 220, 20, 60)
                    or IsInRange(myHero, enemy, 4000) and Draw.Color(128, 240, 230, 140)
                or Draw.Color(128, 152, 251, 152))
            end
        end
    end
end

if Champion == nil and myHero.charName == 'Vayne' then
    -- requires
    require "MapPositionGOS"
    
    -- menu
    Menu.q_combo = Menu.q:MenuElement({id = "combo", name = "Combo", value = true})
    Menu.q_harass = Menu.q:MenuElement({id = "harass", name = "Harass", value = false})
    Menu.q_mode = Menu.q:MenuElement({id = "mode", name = "Q Cast Mode", value = 1, drop = {"To Side", "To Mouse"}})
    Menu.q_xdistance = Menu.q:MenuElement({id = "xdistance", name = "To Side - hold distance", value = 400, min = 200, max = 700, step = 50})
    Menu.e_combo = Menu.e:MenuElement({id = "combo", name = "Combo (Stun)", value = true})
    Menu.e_harass = Menu.e:MenuElement({id = "harass", name = "Harass (Stun)", value = false})
    Menu.e_hitchance = Menu.e:MenuElement({id = "hitchance", name = "Hitchance", value = 1, drop = {"normal", "high", "immobile"}})
    Menu.e_useon = Menu.e:MenuElement({name = "Use on", id = "useon", type = _G.MENU})
    Menu.e:MenuElement({name = "Anti melee", id = "antimelee", type = _G.MENU})
    Menu.e_antimelee_enabled = Menu.e.antimelee:MenuElement({id = "enabled", name = "Enabled", value = true})
    Menu.e_antimelee_xdistance = Menu.e.antimelee:MenuElement({id = "xdistance", name = "enemy distance from vayne", value = 250, min = 200, max = 600, step = 50})
    Menu.e_antimelee_useon = Menu.e.antimelee:MenuElement({name = "Use on", id = "useon", type = _G.MENU})
    Menu.e:MenuElement({name = "Extra Logic", id = "extra", type = _G.MENU})
    Menu.e_extra_antidash = Menu.e.extra:MenuElement({id = "antidash", name = "AntiDash - kha e, rangar r", value = true})
    Menu.e_extra_interrupter = Menu.e.extra:MenuElement({id = "interrupter", name = "Interrupt dangerous spells", value = true})
    Menu.r_combo = Menu.r:MenuElement({id = "combo", name = "Combo", value = true})
    Menu.r_harass = Menu.r:MenuElement({id = "harass", name = "Harass", value = false})
    Menu.r_xenemies = Menu.r:MenuElement({id = "xenemies", name = "minimum number of enemies near vayne", value = 3, min = 1, max = 5, step = 1})
    Menu.r_xdistance = Menu.r:MenuElement({id = "xdistance", name = "enemy distance from vayne", value = 500, min = 250, max = 750, step = 50})
    
    -- locals
    local EPrediction = GGPrediction:SpellPrediction({Delay = 0.5, Radius = 0, Range = 550, Speed = 2000, Collision = false, UseBoundingRadius = false, Type = GGPrediction.SPELLTYPE_LINE})
    
    -- champion
    Champion =
    {
        CanAttackCb = function()
            return GG_Spell:CanTakeAction({q = 0.3, w = 0, e = 0.5, r = 0})
        end,
        CanMoveCb = function()
            return GG_Spell:CanTakeAction({q = 0.2, w = 0, e = 0.4, r = 0})
        end,
        OnPostAttackTick = function(PostAttackTimer)
            Champion:PreTick()
            Champion:RLogic()
            Champion:ELogic()
            if Champion.Timer < PostAttackTimer + 0.3 then
                Champion:QLogic()
            end
        end,
    }
    
    -- on tick
    function Champion:OnTick()
        self:RLogic()
        self:ELogic()
        if self.IsAttacking or self.CanAttackTarget or self.AttackTarget then
            return
        end
        --self:ELogic()
        self:QLogic()
    end
    
    -- q logic
    function Champion:QLogic()
        if GG_Cursor.Step > 0 then
            return
        end
        if not GG_Spell:IsReady(_Q, {q = 1, w = 0, e = 0.5, r = 0}) then
            return
        end
        self:QCombo()
    end
    
    -- q combo
    function Champion:QCombo()
        if GG_Cursor.Step > 0 then
            return
        end
        if not ((self.IsCombo and Menu.q_combo:Value()) or (self.IsHarass and Menu.q_harass:Value())) then
            return
        end
        local enemies = GG_Object:GetEnemyHeroes(false, false, true, true)
        local enemiesaa = {}
        for i = 1, #enemies do
            local enemy = enemies[i]
            if enemy.distance < self.Range + enemy.boundingRadius - 35 then
                table_insert(enemiesaa, enemy)
            end
        end
        if #enemiesaa == 0 then
            local enemies2 = Utils:GetEnemyHeroes(self.Range + 300)
            local pos = Vector(_G.mousePos)
            if self.Pos:DistanceTo(pos) >= 300 then
                local extended = self.Pos:Extended(pos, 300)
                for i = 1, #enemies2 do
                    local enemy = enemies2[i]
                    if extended:DistanceTo(enemy.pos) < self.Range + enemy.boundingRadius - 35 then
                        Utils:Cast(HK_Q)
                        break
                    end
                end
            end
            return
        end
        local distance = 1000
        local closestEnemy = nil
        for i = 1, #enemiesaa do
            local enemy = enemiesaa[i]
            local d = enemy.distance
            if d < distance then
                distance = d
                closestEnemy = enemy
            end
        end
        if Menu.q_mode:Value() == 1 then
            local holdDistance = Menu.q_xdistance:Value()
            local pos = GGPrediction:CircleCircleIntersection(self.Pos, closestEnemy.pos, 300, holdDistance)
            if #pos > 0 and (GG_Object:IsFacing(closestEnemy, myHero, 60) or closestEnemy.distance < holdDistance) then
                if GGPrediction:GetDistance(pos[1], _G.mousePos) < GGPrediction:GetDistance(pos[2], _G.mousePos) then
                    Utils:Cast(HK_Q, {x = pos[1].x, y = 0, z = pos[1].z})
                else
                    Utils:Cast(HK_Q, {x = pos[2].x, y = 0, z = pos[2].z})
                end
            else
                Utils:Cast(HK_Q)
            end
        else
            Utils:Cast(HK_Q)
        end
    end
    
    -- e logic
    function Champion:ELogic()
        if GG_Cursor.Step > 0 then
            return
        end
        if not GG_Spell:IsReady(_E, {q = 0.5, w = 0, e = 1, r = 0}) then
            return
        end
        self:ECombo()
        self:EInterrupter()
        self:EAntimelee()
        self:EAntiDash()
    end
    
    -- e combo
    function Champion:ECombo()
        if GG_Cursor.Step > 0 then
            return
        end
        if not ((self.IsCombo and Menu.e_combo:Value()) or (self.IsHarass and Menu.e_harass:Value())) then
            return
        end
        local enemies = Utils:GetEnemyHeroes(EPrediction.Range + 200)
        for i = 1, #enemies do
            local enemy = enemies[i]
            if enemy.distance < EPrediction.Range + self.BoundingRadius + enemy.boundingRadius - 35 then
                local useon = Menu.e_useon[enemy.charName]
                if useon and useon:Value() then
                    EPrediction:GetPrediction(enemy, myHero)
                    if EPrediction:CanHit(Menu.e_hitchance:Value() + 1) and Utils:CheckWall(self.Pos, Vector(EPrediction.UnitPosition.x, 0, EPrediction.UnitPosition.z), 475) and Utils:CheckWall(self.Pos, enemy.pos, 475) then
                        Utils:Cast(HK_E, enemy)
                        break
                    end
                end
            end
        end
    end
    
    -- e anti melee
    function Champion:EAntimelee()
        if GG_Cursor.Step > 0 then
            return
        end
        if not Menu.e_antimelee_enabled:Value() then
            return
        end
        local melees = {}
        local enemies = Utils:GetEnemyHeroes(Menu.e_antimelee_xdistance:Value())
        for i = 1, #enemies do
            local enemy = enemies[i]
            local useon = Menu.e_antimelee_useon[enemy.charName]
            if enemy.range < 400 and useon and useon:Value() then
                table_insert(melees, enemy)
            end
        end
        if #melees > 0 then
            table.sort(melees, function(a, b)
                return a.health + (a.totalDamage * 2) + (a.attackSpeed * 100) > b.health + (b.totalDamage * 2) + (b.attackSpeed * 100)
            end)
            for i = 1, #melees do
                local target = melees[i]
                if GG_Object:IsFacing(target, myHero, 75) then
                    Utils:Cast(HK_E, target)
                    break
                end
            end
        end
    end
    
    -- e anti dash
    function Champion:EAntiDash()
        if GG_Cursor.Step > 0 then
            return
        end
        if not Menu.e_extra_antidash:Value() then
            return
        end
        local enemies = Utils:GetEnemyHeroes(EPrediction.Range + self.BoundingRadius + 100)
        for i = 1, #enemies do
            local enemy = enemies[i]
            local path = enemy.pathing
            if path and path.isDashing and enemy.posTo then
                if self.Pos:DistanceTo(enemy.posTo) < 400 and self.Pos:DistanceTo(enemy.pos) < EPrediction.Range + self.BoundingRadius + enemy.boundingRadius - 35 and GG_Object:IsFacing(enemy, myHero, 75) then
                    Utils:Cast(HK_E, enemy)
                    break
                end
            end
        end
    end
    
    -- e interrupter
    function Champion:EInterrupter()
        if GG_Cursor.Step > 0 then
            return
        end
        if not Menu.e_extra_interrupter:Value() then
            return
        end
        local enemies = Utils:GetEnemyHeroes(EPrediction.Range + self.BoundingRadius + 100)
        for i = 1, #enemies do
            local enemy = enemies[i]
            if enemy.distance < EPrediction.Range + self.BoundingRadius + enemy.boundingRadius - 35 then
                local spell = enemy.activeSpell
                if spell and spell.valid and Utils.InterruptableSpells[spell.name] and spell.castEndTime - self.Timer > 0.33 then
                    Utils:Cast(HK_E, enemy)
                    break
                end
            end
        end
    end
    
    -- r logic
    function Champion:RLogic()
        if not GG_Spell:IsReady(_R, {q = 0.5, w = 0, e = 0.5, r = 1}) then
            return
        end
        self:RCombo()
    end
    
    -- r combo
    function Champion:RCombo()
        if not ((self.IsCombo and Menu.r_combo:Value()) or (self.IsHarass and Menu.r_harass:Value())) then
            return
        end
        local enemies = Utils:GetEnemyHeroes(Menu.r_xdistance:Value())
        if #enemies >= Menu.r_xenemies:Value() then
            Utils:Cast(HK_R)
        end
    end
    
    -- on load
    function Champion:OnLoad()
        GG_Object:OnEnemyHeroLoad(function(args)
            Menu.e_useon:MenuElement({id = args.charName, name = args.charName, value = true})
            local notMelee = {
                ["Thresh"] = true,
                ["Azir"] = true,
                ["Velkoz"] = true
            }
            local x = GG_Data.HEROES[args.charName:lower()]
            if x and x[2] and not notMelee[args.charName] then
                Menu.e_antimelee_useon:MenuElement({id = args.charName, name = args.charName, value = true})
            end
        end)
    end
end

if Champion == nil and myHero.charName == 'Jhin' then
    
    -- menu
    Menu.q_combo = Menu.q:MenuElement({id = "combo", name = "Combo", value = true})
    Menu.q_harass = Menu.q:MenuElement({id = "harass", name = "Harass", value = false})
    Menu.q:MenuElement({id = "lane", name = "LaneClear", type = _G.MENU})
    Menu.q_lh_enabled = Menu.q.lane:MenuElement({id = "lhenabled", name = "LastHit Enabled", value = true})
    Menu.q_lh_mana = Menu.q.lane:MenuElement({id = "lhmana", name = "LastHit Min. Mana %", value = 50, min = 0, max = 100, step = 5})
    Menu.q_lc_enabled = Menu.q.lane:MenuElement({id = "lcenabled", name = "LaneClear Enabled", value = false})
    Menu.q_lc_mana = Menu.q.lane:MenuElement({id = "lcmana", name = "LaneClear Min. Mana %", value = 75, min = 0, max = 100, step = 5})
    
    Menu.w_combo = Menu.w:MenuElement({id = "combo", name = "Combo", value = true})
    Menu.w_harass = Menu.w:MenuElement({id = "harass", name = "Harass", value = false})
    Menu.w_noaatarget = Menu.w:MenuElement({id = "noaatarget", name = "Only when no attack target", value = true})
    Menu.w_onlypassive = Menu.w:MenuElement({id = "onlypassive", name = "Only when target has jhin buff", value = true})
    Menu.w_hitchance = Menu.w:MenuElement({id = "hitchance", name = "Hitchance", value = 1, drop = {"normal", "high", "immobile"}})
    Menu.w:MenuElement({id = "lane", name = "LaneClear", type = _G.MENU})
    Menu.w_lh_enabled = Menu.w.lane:MenuElement({id = "lhenabled", name = "LastHit Enabled", value = false})
    Menu.w_lh_mana = Menu.w.lane:MenuElement({id = "lhmana", name = "LastHit Min. Mana %", value = 50, min = 0, max = 100, step = 5})
    Menu.w_lc_enabled = Menu.w.lane:MenuElement({id = "lcenabled", name = "LaneClear Enabled", value = false})
    Menu.w_lc_mana = Menu.w.lane:MenuElement({id = "lcmana", name = "LaneClear Min. Mana %", value = 75, min = 0, max = 100, step = 5})
    
    Menu.e_combo = Menu.e:MenuElement({id = "combo", name = "Combo", value = true})
    Menu.e_harass = Menu.e:MenuElement({id = "harass", name = "Harass", value = false})
    Menu.e_hitchance = Menu.e:MenuElement({id = "hitchance", name = "Hitchance", value = 3, drop = {"normal", "high", "immobile"}})
    Menu.e:MenuElement({id = "lane", name = "LaneClear", type = _G.MENU})
    Menu.e_lh_enabled = Menu.e.lane:MenuElement({id = "lhenabled", name = "LastHit Enabled", value = false})
    Menu.e_lh_mana = Menu.e.lane:MenuElement({id = "lhmana", name = "LastHit Min. Mana %", value = 50, min = 0, max = 100, step = 5})
    Menu.e_lc_enabled = Menu.e.lane:MenuElement({id = "lcenabled", name = "LaneClear Enabled", value = false})
    Menu.e_lc_mana = Menu.e.lane:MenuElement({id = "lcmana", name = "LaneClear Min. Mana %", value = 75, min = 0, max = 100, step = 5})
    
    Menu.r_auto = Menu.r:MenuElement({id = "auto", name = "Auto - when jhin has r buff", value = true})
    Menu.r_hitchance = Menu.r:MenuElement({id = "hitchance", name = "Hitchance", value = 1, drop = {"normal", "high", "immobile"}})
    
    -- locals
    local QPrediction = {Delay = 0.25, Range = 550, Speed = 2500}
    local WPrediction = GGPrediction:SpellPrediction({Delay = 0.75, Range = 3000, Radius = 45, Speed = math.huge, Type = GGPrediction.SPELLTYPE_LINE})
    local EPrediction = GGPrediction:SpellPrediction({Delay = 0.25, Range = 750, Radius = 120, Speed = 1600, Type = GGPrediction.SPELLTYPE_CIRCLE})
    local RPrediction = GGPrediction:SpellPrediction({Delay = 0.25, Range = 3500, Radius = 80, Speed = 5000, Type = GGPrediction.SPELLTYPE_LINE})
    
    -- champion
    Champion =
    {
        CanAttackCb = function()
            return GG_Spell:CanTakeAction({q = 0.33, w = 0.77, e = 0.33, r = 0.77}) and not GG_Buff:HasBuff(myHero, "jhinpassivereload") and not Champion:HasRBuff()
        end,
        CanMoveCb = function()
            return GG_Spell:CanTakeAction({q = 0.2, w = 0.5, e = 0.2, r = 0.5}) and not Champion:HasRBuff()
        end,
    }
    
    -- on load
    function Champion:OnLoad()
        self:QLaneClear()
        self:WLaneClear()
        self:ELaneClear()
    end
    
    -- q LaneClear
    function Champion:QLaneClear()
        local getQDamage = function()
            local level = myHero:GetSpellData(_Q).level
            local adratio = (37.5 + (7.5 * level)) / 100
            return 20 + (25 * level) + (adratio * myHero.totalDamage) + (0.6 * myHero.ap)
        end
        local canQLastHit = function()
            return Menu.q_lh_enabled:Value() and self.ManaPercent >= Menu.q_lh_mana:Value()
        end
        local canQLaneClear = function()
            return Menu.q_lc_enabled:Value() and self.ManaPercent >= Menu.q_lc_mana:Value()
        end
        local isQReady = function()
            return GG_Spell:IsReady(_Q, {q = 0.33, w = 0.77, e = 0.33, r = 0.77})
        end
        GG_Spell:SpellClear(_Q, QPrediction, isQReady, canQLastHit, canQLaneClear, getQDamage)
    end
    
    -- w LaneClear
    function Champion:WLaneClear()
        local getWDamage = function()
            local level = myHero:GetSpellData(_W).level
            return 15 + (35 * level) + (0.5 * myHero.totalDamage)
        end
        local canWLastHit = function()
            return Menu.w_lh_enabled:Value() and self.ManaPercent >= Menu.w_lh_mana:Value()
        end
        local canWLaneClear = function()
            return Menu.w_lc_enabled:Value() and self.ManaPercent >= Menu.w_lc_mana:Value()
        end
        local isWReady = function()
            return GG_Spell:IsReady(_W, {q = 0.33, w = 0.77, e = 0.33, r = 0.77}) and GG_Buff:HasBuff(myHero, "jhinpassivereload")
        end
        GG_Spell:SpellClear(_W, WPrediction, isWReady, canWLastHit, canWLaneClear, getWDamage)
    end
    
    -- e LaneClear
    function Champion:ELaneClear()
        local getEDamage = function()
            local level = myHero:GetSpellData(_E).level
            return - 40 + (60 * level) + (1.2 * myHero.totalDamage) + (1.0 * myHero.ap)
        end
        local canELastHit = function()
            return Menu.e_lh_enabled:Value() and self.ManaPercent >= Menu.e_lh_mana:Value()
        end
        local canELaneClear = function()
            return Menu.e_lc_enabled:Value() and self.ManaPercent >= Menu.e_lc_mana:Value()
        end
        local isEReady = function()
            return GG_Spell:IsReady(_E, {q = 0.33, w = 0.77, e = 0.33, r = 0.77}) and GG_Buff:HasBuff(myHero, "jhinpassivereload")
        end
        GG_Spell:SpellClear(_E, EPrediction, isEReady, canELastHit, canELaneClear, getEDamage)
    end
    
    -- on draw
    function Champion:OnDraw()
        local spell = myHero.activeSpell
        if self:HasRBuff(spell) then
            local middlePos = Vector(spell.placementPos)
            local startPos = Vector(spell.startPos)
            local pos1 = startPos + (middlePos - startPos):Rotated(0, 30.6 * math.pi / 180, 0):Normalized() * 3500
            local pos2 = startPos + (middlePos - startPos):Rotated(0, -30.6 * math.pi / 180, 0):Normalized() * 3500
            local p1 = startPos:To2D()
            local p2 = pos1:To2D()
            local p3 = pos2:To2D()
            Draw.Line(p1.x, p1.y, p2.x, p2.y, 1, Draw.Color(255, 255, 255, 255))
            Draw.Line(p1.x, p1.y, p3.x, p3.y, 1, Draw.Color(255, 255, 255, 255))
        end
    end
    
    -- on tick
    function Champion:OnTick()
        self:RLogic()
        if self:HasRBuff() or self.IsAttacking then
            return
        end
        self:WLogic()
        self:QLogic()
        self:ELogic()
    end
    
    -- has r buff
    function Champion:HasRBuff(spell)
        local s = spell or myHero.activeSpell
        if s and s.valid and s.name:lower() == "jhinr" then
            return true
        end
        return false
    end
    
    -- r logic
    function Champion:RLogic()
        if GG_Cursor.Step > 0 then
            return
        end
        if not GG_Spell:IsReady(_R, {q = 0, w = 0, e = 0, r = 0.75}) then
            return
        end
        local spell = myHero.activeSpell
        if not self:HasRBuff(spell) then
            return
        end
        self.IsRAuto = Menu.r_auto:Value()
        if not self.IsRAuto then
            return
        end
        local middlePos = Vector(spell.placementPos)
        local startPos = Vector(spell.startPos)
        local pos1 = startPos + (middlePos - startPos):Rotated(0, 30.6 * math.pi / 180, 0):Normalized() * 3500
        local pos2 = startPos + (middlePos - startPos):Rotated(0, -30.6 * math.pi / 180, 0):Normalized() * 3500
        local polygon =
        {
            pos1 + (pos1 - startPos):Normalized() * 3500,
            pos2 + (pos2 - startPos):Normalized() * 3500,
            startPos
        }
        self.RTarget = GG_Target:GetTarget(Utils:GetEnemyHeroesInsidePolygon(3500, polygon), DAMAGE_TYPE_PHYSICAL)
        self:RAuto()
    end
    
    -- r auto
    function Champion:RAuto()
        if GG_Cursor.Step > 0 then
            return
        end
        if self.IsRAuto then
            Utils:Cast(HK_R, self.RTarget, RPrediction, Menu.r_hitchance:Value() + 1)
        end
    end
    
    -- q logic
    function Champion:QLogic()
        if GG_Cursor.Step > 0 then
            return
        end
        if not GG_Spell:IsReady(_Q, {q = 1, w = 0.75, e = 0.35, r = 0.5}) then
            return
        end
        self.IsQCombo = (self.IsCombo and Menu.q_combo:Value()) or (self.IsHarass and Menu.q_harass:Value())
        if not self.IsQCombo then
            return
        end
        self.QTarget = self.AttackTarget ~= nil and self.AttackTarget or GG_Target:GetTarget(Utils:GetEnemyHeroes(550 + self.BoundingRadius - 35, true), DAMAGE_TYPE_PHYSICAL)
        if self.QTarget == nil then
            return
        end
        self:QCombo()
    end
    
    -- q combo
    function Champion:QCombo()
        if GG_Cursor.Step > 0 then
            return
        end
        if self.IsQCombo then
            Utils:Cast(HK_Q, self.QTarget)
        end
    end
    
    -- w logic
    function Champion:WLogic()
        if GG_Cursor.Step > 0 then
            return
        end
        if Menu.w_noaatarget:Value() and self.AttackTarget then
            return
        end
        if not GG_Spell:IsReady(_W, {q = 0.35, w = 1, e = 0.35, r = 0.5}) then
            return
        end
        self.IsWCombo = (self.IsCombo and Menu.w_combo:Value()) or (self.IsHarass and Menu.w_harass:Value())
        if not self.IsWCombo then
            return
        end
        self.WTarget = self.AttackTarget ~= nil and self.AttackTarget or GG_Target:GetTarget(Utils:GetEnemyHeroes(3000), DAMAGE_TYPE_PHYSICAL)
        if self.WTarget == nil or (Menu.w_onlypassive:Value() and not GG_Buff:HasBuff(self.WTarget, "jhinespotteddebuff")) then
            return
        end
        self:WCombo()
    end
    
    -- w combo
    function Champion:WCombo()
        if GG_Cursor.Step > 0 then
            return
        end
        if self.IsWCombo then
            Utils:Cast(HK_W, self.WTarget, WPrediction, Menu.w_hitchance:Value() + 1)
        end
    end
    
    -- e logic
    function Champion:ELogic()
        if GG_Cursor.Step > 0 then
            return
        end
        if not GG_Buff:HasBuff(myHero, "jhinpassivereload") then
            return
        end
        if not GG_Spell:IsReady(_E, {q = 0.35, w = 0.75, e = 1, r = 0.5}) then
            return
        end
        self.IsECombo = (self.IsCombo and Menu.e_combo:Value()) or (self.IsHarass and Menu.e_harass:Value())
        if not self.IsECombo then
            return
        end
        self.ETarget = self.AttackTarget ~= nil and self.AttackTarget or GG_Target:GetTarget(Utils:GetEnemyHeroes(750), DAMAGE_TYPE_PHYSICAL)
        if self.ETarget == nil then
            return
        end
        self:ECombo()
    end
    
    -- w combo
    function Champion:ECombo()
        if GG_Cursor.Step > 0 then
            return
        end
        if self.IsECombo then
            Utils:Cast(HK_E, self.ETarget, EPrediction, Menu.e_hitchance:Value() + 1)
        end
    end
end

if Champion == nil and myHero.charName == 'Blitzcrank' then
    --menu
    
    Menu.q_combo = Menu.q:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.q_harass = Menu.q:MenuElement({id = 'harass', name = 'Harass', value = true})
    Menu.q_hitchance = Menu.q:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"Normal", "High", "Immobile"}})
    Menu.q_useon_combo = Menu.q:MenuElement({id = "useon_combo", name = "Combo Use on", type = _G.MENU})
    Menu.q_useon_harass = Menu.q:MenuElement({id = "useon_harass", name = "Harass Use on", type = _G.MENU})
    Menu.q:MenuElement({id = "auto", name = "Auto", type = _G.MENU})
    Menu.q_auto_enabled = Menu.q.auto:MenuElement({id = "enabled", name = "Enabled", value = false})
    Menu.q_auto_hitchance = Menu.q.auto:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"Normal", "High", "Immobile"}})
    Menu.q_auto_useon = Menu.q.auto:MenuElement({id = "useon", name = "Use on", type = _G.MENU})
    Menu.q:MenuElement({id = "ks", name = "Killsteal", type = _G.MENU})
    Menu.q_ks_enabled = Menu.q.ks:MenuElement({id = "enabled", name = "Enabled", value = false})
    Menu.q_ks_hitchance = Menu.q.ks:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"Normal", "High", "Immobile"}})
    Menu.q:MenuElement({id = "interrupter", name = "Interrupter", type = _G.MENU})
    Menu.q_interrupter_enabled = Menu.q.interrupter:MenuElement({id = "enabled", name = "Enabled", value = false})
    
    Menu.r_xenemies = Menu.r:MenuElement({id = "xenemies", name = "X Enemies", value = 2, min = 1, max = 5, step = 1})
    Menu.r_xrange = Menu.r:MenuElement({id = "xrange", name = "X Distance", value = 550, min = 300, max = 600, step = 50})
    Menu.r:MenuElement({id = "auto", name = "Auto", type = _G.MENU})
    Menu.r_auto_enabled = Menu.r.auto:MenuElement({id = "enabled", name = "Enabled", value = false})
    Menu.r_auto_xenemies = Menu.r.auto:MenuElement({id = "xenemies", name = "X Enemies", value = 3, min = 1, max = 5, step = 1})
    Menu.r_auto_xrange = Menu.r.auto:MenuElement({id = "xrange", name = "X Distance", value = 550, min = 300, max = 600, step = 50})
    Menu.r:MenuElement({id = "ks", name = "Killsteal", type = _G.MENU})
    Menu.r_ks_enabled = Menu.r.ks:MenuElement({id = "enabled", name = "Enabled", value = false})
    
    Menu.d_Draw_Q = Menu.d:MenuElement({id = "Draw_Q", name = "Draw Q", value = true})
    Menu.d_Draw_R = Menu.d:MenuElement({id = "Draw_R", name = "Draw R", value = true})
    -- locals
    local QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 140 / 2, Range = 1090, Speed = 1800, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}})
    local RPrediction = {Range = 590}
    
    -- champion
    Champion =
    {
        CanAttackCb = function()
            --[[local qdata = myHero:GetSpellData(_Q)
            if qdata.level > 0 and myHero.mana > qdata.mana and (Game.CanUseSpell(_Q) == 0 or qdata.currentCd < 1) then
                return false
            end]]
            return not myHero.isChanneling and GG_Spell:CanTakeAction({q = 0.33, w = 0, e = 0, r = 0.33})
        end,
        CanMoveCb = function()
            return GG_Spell:CanTakeAction({q = 0.2, w = 0, e = 0, r = 0.2})
        end,
    }
    -- load
    function Champion:OnLoad()
        GG_Object:OnEnemyHeroLoad(function(args)
            Menu.q_auto_useon:MenuElement({id = args.charName, name = args.charName, value = true})
            Menu.q_useon_combo:MenuElement({id = args.charName, name = args.charName, value = true})
            Menu.q_useon_harass:MenuElement({id = args.charName, name = args.charName, value = true})
        end)
    end
    -- tick
    function Champion:OnTick()
        self:ELogic()
        self:QLogic()
        self:RLogic()
    end
    
    --q logic
    function Champion:QLogic()
        if not GG_Spell:IsReady(_Q, {q = 0.33, w = 0, e = 0, r = 0.33}) then
            return
        end
        self.QTargets = Utils:GetEnemyHeroes(QPrediction.Range)
        self:QKS()
        self:QInterrupter()
        self:QAuto()
        self:QCombo()
        self:QHarass()
    end
    
    --e logic
    function Champion:ELogic()
        if not GG_Spell:IsReady(_E, {q = 0.33, w = 0, e = 1, r = 0.33}) then
            return
        end
        if self.AttackTarget or Game.Timer() < GG_Spell.QkTimer + 0.77 then
            Utils:Cast(HK_E)
        end
    end
    
    --r logic
    function Champion:RLogic()
        if not GG_Spell:IsReady(_R, {q = 0.33, w = 0, e = 0, r = 0.33}) then
            return
        end
        self.RTargets = Utils:GetEnemyHeroes(RPrediction.Range)
        self:RKS()
        self:RAuto()
    end
    
    -- q ks
    function Champion:QKS()
        if not Menu.q_ks_enabled:Value() then
            return
        end
        local baseDmg = 20
        local lvlDmg = 50 * myHero:GetSpellData(_Q).level
        local apDmg = myHero.ap
        local qDmg = baseDmg + lvlDmg + apDmg
        if qDmg < 100 then
            return
        end
        for i, unit in ipairs(self.QTargets) do
            local health = unit.health
            if health > 100 and health < GG_Damage:CalculateDamage(myHero, unit, DAMAGE_TYPE_MAGICAL, qDmg) then
                Utils:Cast(HK_Q, unit, QPrediction, Menu.q_ks_hitchance:Value() + 1)
            end
        end
    end
    -- q interrupter
    function Champion:QInterrupter()
        if not Menu.q_interrupter_enabled:Value() then
            return
        end
        for i, unit in ipairs(self.QTargets) do
            local spell = unit.activeSpell
            if spell and spell.valid and Utils.InterruptableSpells[spell.name] and spell.castEndTime - self.Timer > 0.33 then
                Utils:Cast(HK_Q, unit, QPrediction, HITCHANCE_NORMAL)
            end
        end
    end
    -- q auto
    function Champion:QAuto()
        if not Menu.q_auto_enabled:Value() then
            return
        end
        local enemies = {}
        for i, unit in ipairs(self.QTargets) do
            local canuse = Menu.q_auto_useon[unit.charName]
            if canuse and canuse:Value() then
                table_insert(enemies, unit)
            end
        end
        Utils:Cast(HK_Q, GG_Target:GetTarget(enemies, DAMAGE_TYPE_MAGICAL), QPrediction, Menu.q_auto_hitchance:Value() + 1)
    end
    -- q combo
    function Champion:QCombo()
        if not(self.IsCombo and Menu.q_combo:Value()) then
            return
        end
        local enemies = {}
        for i, unit in ipairs(self.QTargets) do
            local canuse = Menu.q_useon_combo[unit.charName]
            if canuse and canuse:Value() then
                table_insert(enemies, unit)
            end
        end
        Utils:Cast(HK_Q, GG_Target:GetTarget(enemies, DAMAGE_TYPE_MAGICAL), QPrediction, Menu.q_hitchance:Value() + 1)
    end
    -- q harass
    function Champion:QHarass()
        if not (self.IsHarass and Menu.q_harass:Value()) then
            return
        end
        local enemies = {}
        for i, unit in ipairs(self.QTargets) do
            local canuse = Menu.q_useon_harass[unit.charName]
            if canuse and canuse:Value() then
                table_insert(enemies, unit)
            end
        end
        Utils:Cast(HK_Q, GG_Target:GetTarget(enemies, DAMAGE_TYPE_MAGICAL), QPrediction, Menu.q_hitchance:Value() + 1)
    end
    -- r ks
    function Champion:RKS()
        if not Menu.r_ks_enabled:Value() then
            return
        end
        local basedmg = 125
        local lvldmg = 125 * myHero:GetSpellData(_R).level
        local apdmg = myHero.ap
        local rdmg = basedmg + lvldmg + apdmg
        if rdmg < 100 then
            return
        end
        for i, unit in ipairs(self.RTargets) do
            local health = unit.health
            if health > 100 and health < GG_Damage:CalculateDamage(myHero, unit, DAMAGE_TYPE_MAGICAL, rdmg) then
                Utils:Cast(HK_R)
            end
        end
    end
    -- r auto
    function Champion:RAuto()
        if not Menu.r_auto_enabled:Value() then
            return
        end
        local count = 0
        for i, unit in ipairs(self.RTargets) do
            if unit.distance < Menu.r_auto_xrange:Value() then
                count = count + 1
            end
        end
        if count >= Menu.r_auto_xenemies:Value() then
            Utils:Cast(HK_R)
        end
    end
    
    -- draw
    function Champion:OnDraw()
        if Menu.d_Draw_Q:Value() and GG_Spell:IsReady(_Q) then
            Draw.Circle(myHero.pos, 1090, Draw.Color(0, 128, 128))
        end
        if Menu.d_Draw_R:Value() and GG_Spell:IsReady(_R) then
            Draw.Circle(myHero.pos, 590, Draw.Color(0, 128, 123))
        end
    end
end

if Champion == nil and myHero.charName == 'Taric' then
    local inTimer, process, selected, data = 0, false, nil, {unit = nil, dir = nil, timer = 0}
    
    -- menu
    Menu.q_mana = Menu.q:MenuElement({id = "mana", name = "Min. Mana %", value = 50, min = 0, max = 100, step = 5})
    Menu.e_follow = Menu.e:MenuElement({id = "Follow", name = "Auto-Follow", value = true})
    
    -- champion
    Champion =
    {
        CanAttackCb = function()
            return true
        end,
        CanMoveCb = function()
            return true
        end,
    }
    
    -- Methods
    local function Distance(p1, p2)
        local dx, dy = p2.x - p1.x, p2.z - p1.z
        return math.sqrt(dx * dx + dy * dy)
    end
    
    local function GetPathCount(unit)
        local c = unit.pathing.pathCount
        return (not c or c < 0 or c > 20) and - 1 or c
    end
    
    local function GetPathIndex(unit)
        local i = unit.pathing.pathIndex
        return (not i or i < 0 or i > 20) and - 1 or i
    end
    
    local function GetWaypoints(unit)
        local result = {}
        table.insert(result, unit.pos)
        if unit.pathing.hasMovePath then
            local index, count = GetPathIndex(unit), GetPathCount(unit)
            if index == -1 or count == -1 then return result end
            for i = index, count do table.insert(result, unit:GetPath(i)) end
        end
        return result
    end
    
    local function PositionAfter(unit, time)
        if not (unit and unit.valid and
        unit.visible) then return nil end
        local path = GetWaypoints(unit)
        if #path == 1 then return path[1] end
        local moveSpeed = unit.pathing.isDashing and unit.pathing.dashSpeed or unit.ms
        local distance = moveSpeed * time
        for i = 1, #path - 1 do
            local a, b = path[i], path[i + 1]
            local dist = Distance(a, b)
            if dist >= distance then
                return a:Extended(b, distance)
            end
            distance = distance - dist
        end
        return path[#path]
    end
    
    local function IsComboMode()
        return (SDK and SDK.Orbwalker.Modes[SDK.ORBWALKER_MODE_COMBO]) or (PremiumOrbwalker and PremiumOrbwalker:GetMode() == "Combo")
    end
    
    local function IsValid(unit, range)
        if unit and unit.valid and unit.visible and unit.alive and unit.isTargetable and (range == nil or unit.distance < range) then
            return true
        end
        return false
    end
    
    local function GetTargets()
        local result = {}
        local count = 0
        for i = 1, Game.HeroCount() do
            local unit = Game.Hero(i)
            if IsValid(unit, 1000) and not unit.isAlly then
                count = count + 1
                result[count] = {unit.pos, unit.boundingRadius + 180}
            end
        end
        for i = 1, Game.MinionCount() do
            local unit = Game.Minion(i)
            if IsValid(unit, 1000) and not unit.isAlly then
                count = count + 1
                result[count] = {unit.pos, unit.boundingRadius + 120}
            end
        end
        for i = 1, Game.TurretCount() do
            local unit = Game.Turret(i)
            if IsValid(unit, 1000) and not unit.isAlly then
                count = count + 1
                result[count] = {unit.pos, unit.boundingRadius + 120}
            end
        end
        return result
    end
    
    local function IsCursorOnTarget(targets, pos)
        for i = 1, #targets do
            local item = targets[i]
            if pos:DistanceTo(item[1]) < item[2] then
                return true
            end
        end
        return false
    end
    
    local function SkipTargetsPos(pos)
        local i = 0
        local result = pos
        local dir = (pos - myHero.pos):Normalized()
        local targets = GetTargets()
        while (IsCursorOnTarget(targets, result)) do
            i = i + 50
            result = pos + dir * i
        end
        return result
    end
    
    local function OnPreAttack(args)
        if not process then args.Process = false end
    end
    
    local function OnPreMovement(args)
        if not process then args.Process = false end
    end
    
    local function IsEvading()
        if JustEvade and JustEvade:Evading() then
            return true
        end
        if ExtLibEvade and ExtLibEvade.Evading then
            return true
        end
        return false
    end
    
    local function CastE(unit, pos)
        if IsValid(unit, 600) and unit.isEnemy then
            local pred = PositionAfter(unit, 0.25)
            if pred and Distance(myHero.pos, pred) < 600 then
                Control.CastSpell(HK_E, pred)
                data.dir, data.timer, data.unit = Vector(pred - myHero.pos), Game.Timer(), unit
                process = false
                if SDK then
                    SDK.Orbwalker:ResetMovement()
                end
                return true
            end
        end
        return false
    end
    
    local function MoveToPred()
        local timer = Game.Timer()
        if Menu.e_follow:Value() and timer - data.timer <= 1 then
            if timer - inTimer > 0.1 then
                inTimer = timer
                local pred = PositionAfter(data.unit, 0.25)
                if pred then
                    local dirPos = Vector(pred - data.dir)
                    local pos = myHero.pos:Extended(dirPos, 100)
                    if Distance(pos, pred) > 600 then
                        pos = myHero.pos:Extended(dirPos, -100)
                    end
                    process = false
                    _G.Control.Move(SkipTargetsPos(pos))
                end
            end
            return
        end
        if not process then
            process = true
        end
    end
    
    -- load
    function Champion:OnLoad()
        if _G.SDK then
            _G.SDK.Orbwalker:OnPreAttack(function(...) OnPreAttack(...) end)
            _G.SDK.Orbwalker:OnPreMovement(function(...) OnPreMovement(...) end)
        elseif _G.PremiumOrbwalker then
            _G.PremiumOrbwalker:OnPreAttack(function(...) OnPreAttack(...) end)
            _G.PremiumOrbwalker:OnPreMovement(function(...) OnPreMovement(...) end)
        end
    end
    
    -- wnd msg
    function Champion:OnWndMsg(msg, wParam)
        if not (msg == 513 and wParam == 0) then
            return
        end
        for i = 1, Game.HeroCount() do
            local unit = Game.Hero(i)
            if IsValid(unit) and unit.isEnemy and Distance(unit.pos, mousePos) <= 150 then
                selected = unit
                return
            end
        end
        selected = nil
    end
    
    -- draw
    function Champion:OnDraw()
        if not IsEvading() then
            MoveToPred()
        end
        if IsValid(selected) then
            Draw.Circle(selected.pos, 115, 5, Draw.Color(192, 148, 0, 211))
        end
    end
    
    -- tick
    function Champion:OnTick()
        if IsEvading() or Game.IsChatOpen() or myHero.dead then
            return
        end
        MoveToPred()
        if not IsComboMode() or self.IsAttacking then
            return
        end
        local timer = Game.Timer()
        if Game.CanUseSpell(_Q) == 0 and self.AttackTarget and timer - data.timer > 1 and self.ManaPercent >= Menu.q_mana:Value() then
            Utils:Cast(HK_Q)
            return
        end
        if Game.CanUseSpell(_E) == 0 and GG_Spell:CanTakeAction({q = 0.33, w = 0, e = 0, r = 0.33}) then
            if SDK and SDK.Cursor.Step > 0 then
                return
            end
            if CastE(selected) then
                return
            end
            for i = 0, Game.HeroCount() do
                local unit = Game.Hero(i)
                if CastE(unit) then
                    break
                end
            end
        end
    end
end
--[[
if Champion == nil and myHero.charName == 'Karthus' then
    -- Q
    -- Disable Attack
    Menu.q_disaa = Menu.q:MenuElement({id = "disaa", name = "Disable attack", value = true})
    -- KS
    Menu.q_ks = Menu.q:MenuElement({name = "KS", id = "killsteal", type = _G.MENU})
    Menu.q_ks_enabled = Menu.q_ks:MenuElement({id = "enabled", name = "Enabled", value = true})
    Menu.q_ks_minhp = Menu.q_ks:MenuElement({id = "minhp", name = "minimum enemy hp", value = 200, min = 1, max = 300, step = 1})
    Menu.q_ks_hitchance = Menu.q_ks:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
    -- Auto
    Menu.q_auto = Menu.q:MenuElement({name = "Auto", id = "auto", type = _G.MENU})
    Menu.q_auto_enabled = Menu.q_auto:MenuElement({id = "enabled", name = "Enabled", value = true})
    Menu.q_auto_useon = Menu.q_auto:MenuElement({name = "Use on:", id = "useon", type = _G.MENU})
    Menu.q_auto_hitchance = Menu.q_auto:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
    -- Combo / Harass
    Menu.q_comhar = Menu.q:MenuElement({name = "Combo / Harass", id = "comhar", type = _G.MENU})
    Menu.q_comhar_combo = Menu.q_comhar:MenuElement({id = "combo", name = "Combo", value = true})
    Menu.q_comhar_harass = Menu.q_comhar:MenuElement({id = "harass", name = "Harass", value = false})
    Menu.q_comhar_hitchance = Menu.q_comhar:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
    -- W
    Menu.w_combo = Menu.w:MenuElement({id = "combo", name = "Combo", value = true})
    Menu.w_harass = Menu.w:MenuElement({id = "harass", name = "Harass", value = false})
    Menu.w_hitchance = Menu.w:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
    -- E
    Menu.e_auto = Menu.e:MenuElement({id = "auto", name = "Auto", value = true})
    Menu.e_combo = Menu.e:MenuElement({id = "combo", name = "Combo", value = true})
    Menu.e_harass = Menu.e:MenuElement({id = "harass", name = "Harass", value = false})
    Menu.e_minmp = Menu.e:MenuElement({id = "minmp", name = "minimum mana percent", value = 25, min = 1, max = 100, step = 1})
    --R
    Menu.r_killsteal = Menu.r:MenuElement({id = "killsteal", name = "Auto KS X enemies in passive form", value = true})
    Menu.r_kscount = Menu.r:MenuElement({id = "kscount", name = "^^^ X enemies ^^^", value = 2, min = 1, max = 5, step = 1})
    -- Drawings
    Menu.d_ksdraw = Menu.d:MenuElement({name = "Draw Kill Count", id = "ksdraw", type = _G.MENU})
    Menu.d_enabled = Menu.d:MenuElement({id = "enabled", name = "Enabled", value = true})
    Menu.d_size = Menu.d:MenuElement({id = "size", name = "Text Size", value = 25, min = 1, max = 64, step = 1})
 
    -- locals
    local QPrediction = GGPrediction:SpellPrediction({Delay = 1, Radius = 200, Range = 875, Speed = math.huge, Collision = false, Type = _G.SPELLTYPE_CIRCLE})
    local WPrediction = GGPrediction:SpellPrediction({Delay = 0.25, Radius = 1, Range = 1000, Speed = math.huge, Collision = false, Type = _G.SPELLTYPE_CIRCLE})
 
    -- champion
    Champion =
    {
        CanAttackCb = function()
            if not GG_Spell:CanTakeAction({q = 0.33, w = 0.33, e = 0.33, r = 3.23}) then
                return false
            end
            if not Menu.q_disaa:Value() then
                return true
            end
            if not GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and not GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] then
                return true
            end
            if myHero.mana > myHero:GetSpellData(_Q).mana then
                return false
            end
            return true
        end,
        CanMoveCb = function()
            if not GG_Spell:CanTakeAction({q = 0.2, w = 0.2, e = 0.2, r = 3.13}) then
                return false
            end
            return true
        end,
    }
    
    -- on load
    function Champion:OnLoad()
        GG_Object:OnEnemyHeroLoad(function(args)
            Menu.q_auto_useon:MenuElement({id = args.charName, name = args.charName, value = true})
        end)
    end
 
    function Champion:OnTick()
        if GG_Cursor.Step == 0 then
            self:QLogic()
            self:WLogic()
        end
        self:ELogic()
        self:RLogic()
    end
        -- Is Attacking
        if GG_Orbwalker:IsAutoAttacking() then
            return
        end
        -- Has Passive Buff
        local hasPassive = GG_Buff:HasBuff(myHero, "karthusdeathdefiedbuff")
        -- W
        if GG_Spell:IsReady(_W, {q = 0.33, w = 0.5, e = 0.33, r = 3.23}) then
            if (GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.wset.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.wset.harass:Value()) then
                local enemyList = AIO:GetEnemyHeroes(1000)
                AIO:Cast(HK_W, GG_Target:GetTarget(enemyList, 1), self.WData, Menu.wset.hitchance:Value() + 1)
            end
        end
        -- E
        if GG_Spell:IsReady(_E, {q = 0.33, w = 0.33, e = 0.5, r = 3.23}) and not hasPassive then
            if Menu.eset.auto:Value() or (GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.eset.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.eset.harass:Value()) then
                local enemyList = AIO:GetEnemyHeroes(425)
                local eBuff = GG_Buff:HasBuff(myHero, "karthusdefile")
                if eBuff and #enemyList == 0 and AIO:Cast(HK_E) then
                    return
                end
                local manaPercent = 100 * myHero.mana / myHero.maxMana
                if not eBuff and #enemyList > 0 and manaPercent > Menu.eset.minmp:Value() and AIO:Cast(HK_E) then
                    return
                end
            end
        end
        -- Q
        local qdata = myHero:GetSpellData(_Q);
        if (GG_Spell:IsReady(_Q, {q = 0.5, w = 0.33, e = 0.33, r = 3.23}) and qdata.ammoCd == 0 and qdata.ammoCurrentCd == 0 and qdata.ammo == 2 and qdata.ammoTime - Game.Timer() < 0) then
            -- KS
            if Menu.qset.killsteal.enabled:Value() then
                local qDmg = self:GetQDmg()
                local minHP = Menu.qset.killsteal.minhp:Value()
                if qDmg > minHP then
                    local enemyList = AIO:GetEnemyHeroes(875)
                    for i = 1, #enemyList do
                        local qTarget = enemyList[i]
                        if qTarget.health > minHP and qTarget.health < GG_Damage:CalculateDamage(myHero, qTarget, DAMAGE_TYPE_MAGICAL, self:GetQDmg()) then
                            AIO:Cast(HK_Q, qTarget, self.QData, Menu.qset.killsteal.hitchance:Value() + 1)
                        end
                    end
                end
            end
            -- Combo Harass
            if (GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.qset.comhar.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.qset.comhar.harass:Value()) then
                for i = 1, 3 do
                    local enemyList = AIO:GetEnemyHeroes(1000 - (i * 100))
                    AIO:Cast(HK_Q, GG_Target:GetTarget(enemyList, 1), self.QData, Menu.qset.comhar.hitchance:Value() + 1)
                end
                -- Auto
            elseif Menu.qset.auto.enabled:Value() then
                for i = 1, 3 do
                    local qList = {}
                    local enemyList = AIO:GetEnemyHeroes(1000 - (i * 100))
                    for i = 1, #enemyList do
                        local hero = enemyList[i]
                        local heroName = hero.charName
                        if Menu.qset.auto.useon[heroName] and Menu.qset.auto.useon[heroName]:Value() then
                            qList[#qList + 1] = hero
                        end
                    end
                    AIO:Cast(HK_Q, GG_Target:GetTarget(qList, 1), self.QData, Menu.qset.auto.hitchance:Value() + 1)
                end
            end
        end
        -- R
        if GG_Spell:IsReady(_R, {q = 0.33, w = 0.33, e = 0.33, r = 0.5}) and Menu.rset.killsteal:Value() and hasPassive then
            local rCount = 0
            local enemyList = AIO:GetEnemyHeroes()
            for i = 1, #enemyList do
                local rTarget = enemyList[i]
                if rTarget.health < GG_Damage:CalculateDamage(myHero, rTarget, DAMAGE_TYPE_MAGICAL, self:GetRDmg()) then
                    rCount = rCount + 1
                end
            end
            if rCount > Menu.rset.kscount:Value() and AIO:Cast(HK_R) then
                return
            end
        end
    end
 
    function Champion:OnDraw()
        if Menu.draws.ksdraw.enabled:Value() and Game.CanUseSpell(_R) == 0 then
            local rCount = 0
            local enemyList = AIO:GetEnemyHeroes()
            for i = 1, #enemyList do
                local rTarget = enemyList[i]
                if rTarget.health < GG_Damage:CalculateDamage(myHero, rTarget, DAMAGE_TYPE_MAGICAL, self:GetRDmg()) then
                    rCount = rCount + 1
                end
            end
            local mePos = myHero.pos:To2D()
            local posX = mePos.x - 50
            local posY = mePos.y
            if rCount > 0 then
                Draw.Text("Kill Count: "..rCount, Menu.draws.ksdraw.size:Value(), posX, posY, Draw.Color(255, 000, 255, 000))
            else
                Draw.Text("Kill Count: "..rCount, Menu.draws.ksdraw.size:Value(), posX, posY, Draw.Color(150, 255, 000, 000))
            end
        end
    end
 
    function Champion:GetQDmg()
        local qLvl = myHero:GetSpellData(_Q).level
        if qLvl == 0 then return 0 end
        local baseDmg = 30
        local lvlDmg = 20 * qLvl
        local apDmg = myHero.ap * 0.3
        return baseDmg + lvlDmg + apDmg
    end
 
    function Champion:GetRDmg()
        local rLvl = myHero:GetSpellData(_R).level
        if rLvl == 0 then return 0 end
        local baseDmg = 50
        local lvlDmg = 150 * rLvl
        local apDmg = myHero.ap * 0.75
        return baseDmg + lvlDmg + apDmg
    end
end
 
 
 
if Champion == nil and myHero.charName == 'Brand' then
    class "Brand"
 
    function Brand:__init()
        self.ETarget = nil
        self.QData = {Delay = 0.25, Radius = 60, Range = 1085, Speed = 1600, Collision = true, Type = _G.SPELLTYPE_LINE}
        self.WData = {Delay = 0.9, Radius = 260, Range = 880, Speed = math.huge, Collision = false, Type = _G.SPELLTYPE_CIRCLE}
    end
 
    function Brand:CreateMenu()
        Menu = MenuElement({name = "Gamsteron Brand", id = "Gamsteron_Brand", type = _G.MENU})
        -- Q
        Menu:MenuElement({name = "Q settings", id = "qset", type = _G.MENU})
        -- KS
        Menu.qset:MenuElement({name = "KS", id = "killsteal", type = _G.MENU})
        Menu.qset.killsteal:MenuElement({id = "enabled", name = "Enabled", value = true})
        Menu.qset.killsteal:MenuElement({id = "minhp", name = "minimum enemy hp", value = 200, min = 1, max = 300, step = 1})
        Menu.qset.killsteal:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- Auto
        Menu.qset:MenuElement({name = "Auto", id = "auto", type = _G.MENU})
        Menu.qset.auto:MenuElement({id = "stun", name = "Auto Stun", value = true})
        Menu.qset.auto:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- Combo / Harass
        Menu.qset:MenuElement({name = "Combo / Harass", id = "comhar", type = _G.MENU})
        Menu.qset.comhar:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.qset.comhar:MenuElement({id = "harass", name = "Harass", value = false})
        Menu.qset.comhar:MenuElement({id = "stun", name = "Only if will stun", value = true})
        Menu.qset.comhar:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- W
        Menu:MenuElement({name = "W settings", id = "wset", type = _G.MENU})
        Menu.wset:MenuElement({id = "disaa", name = "Disable attack if ready or almostReady", value = true})
        -- KS
        Menu.wset:MenuElement({name = "KS", id = "killsteal", type = _G.MENU})
        Menu.wset.killsteal:MenuElement({id = "enabled", name = "Enabled", value = true})
        Menu.wset.killsteal:MenuElement({id = "minhp", name = "minimum enemy hp", value = 200, min = 1, max = 300, step = 1})
        Menu.wset.killsteal:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- Auto
        Menu.wset:MenuElement({name = "Auto", id = "auto", type = _G.MENU})
        Menu.wset.auto:MenuElement({id = "enabled", name = "Enabled", value = true})
        Menu.wset.auto:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- Combo / Harass
        Menu.wset:MenuElement({name = "Combo / Harass", id = "comhar", type = _G.MENU})
        Menu.wset.comhar:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.wset.comhar:MenuElement({id = "harass", name = "Harass", value = false})
        Menu.wset.comhar:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- E
        Menu:MenuElement({name = "E settings", id = "eset", type = _G.MENU})
        Menu.eset:MenuElement({id = "disaa", name = "Disable attack if ready or almostReady", value = true})
        -- KS
        Menu.eset:MenuElement({name = "KS", id = "killsteal", type = _G.MENU})
        Menu.eset.killsteal:MenuElement({id = "enabled", name = "Enabled", value = true})
        Menu.eset.killsteal:MenuElement({id = "minhp", name = "minimum enemy hp", value = 100, min = 1, max = 300, step = 1})
        -- Auto
        Menu.eset:MenuElement({name = "Auto", id = "auto", type = _G.MENU})
        Menu.eset.auto:MenuElement({id = "stun", name = "If Q ready | no collision & W not ready $ mana for Q + E", value = true})
        Menu.eset.auto:MenuElement({id = "passive", name = "If Q not ready & W not ready $ enemy has passive buff", value = true})
        -- Combo / Harass
        Menu.eset:MenuElement({name = "Combo / Harass", id = "comhar", type = _G.MENU})
        Menu.eset.comhar:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.eset.comhar:MenuElement({id = "harass", name = "Harass", value = false})
        --R
        Menu:MenuElement({name = "R settings", id = "rset", type = _G.MENU})
        -- Auto
        Menu.rset:MenuElement({name = "Auto", id = "auto", type = _G.MENU})
        Menu.rset.auto:MenuElement({id = "enabled", name = "Enabled", value = true})
        Menu.rset.auto:MenuElement({id = "xenemies", name = ">= X enemies near target", value = 2, min = 1, max = 4, step = 1})
        Menu.rset.auto:MenuElement({id = "xrange", name = "< X distance enemies to target", value = 300, min = 100, max = 600, step = 50})
        -- Combo / Harass
        Menu.rset:MenuElement({name = "Combo / Harass", id = "comhar", type = _G.MENU})
        Menu.rset.comhar:MenuElement({id = "combo", name = "Use R Combo", value = true})
        Menu.rset.comhar:MenuElement({id = "harass", name = "Use R Harass", value = false})
        Menu.rset.comhar:MenuElement({id = "xenemies", name = ">= X enemies near target", value = 1, min = 1, max = 4, step = 1})
        Menu.rset.comhar:MenuElement({id = "xrange", name = "< X distance enemies to target", value = 300, min = 100, max = 600, step = 50})
    end
 
    function Brand:Tick()
        -- Is Attacking
        if GG_Orbwalker:IsAutoAttacking() then
            return
        end
        -- Q
        if GG_Spell:IsReady(_Q, {q = 0.5, w = 0.53, e = 0.53, r = 0.33}) then
            -- KS
            if Menu.qset.killsteal.enabled:Value() then
                local baseDmg = 50
                local lvlDmg = 30 * myHero:GetSpellData(_Q).level
                local apDmg = myHero.ap * 0.55
                local qDmg = baseDmg + lvlDmg + apDmg
                local minHP = Menu.qset.killsteal.minhp:Value()
                if qDmg > minHP then
                    local enemyList = AIO:GetEnemyHeroes(1050)
                    for i = 1, #enemyList do
                        local qTarget = enemyList[i]
                        if qTarget.health > minHP and qTarget.health < GG_Damage:CalculateDamage(myHero, qTarget, DAMAGE_TYPE_MAGICAL, qDmg) then
                            if AIO:Cast(HK_Q, qTarget, self.QData, Menu.qset.killsteal.hitchance:Value() + 1) then
                                return
                            end
                        end
                    end
                end
            end
            -- Combo Harass
            if (GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.qset.comhar.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.qset.comhar.harass:Value()) then
                if Game.Timer() < GG_Spell.EkTimer + 1 and Game.Timer() > GG_Spell.ETimer + 0.33 and AIO:IsValidHero(self.ETarget) and self.ETarget:GetCollision(self.QData.Radius, self.QData.Speed, self.QData.Delay) == 0 then
                    if AIO:Cast(HK_Q, self.ETarget, self.QData, Menu.qset.comhar.hitchance:Value() + 1) then
                        return
                    end
                end
                local blazeList = {}
                local enemyList = AIO:GetEnemyHeroes(1050)
                for i = 1, #enemyList do
                    local unit = enemyList[i]
                    if GG_Buff:GetBuffDuration(unit, "brandablaze") > 0.5 and unit:GetCollision(self.QData.Radius, self.QData.Speed, self.QData.Delay) == 0 then
                        blazeList[#blazeList + 1] = unit
                    end
                end
                if AIO:Cast(HK_Q, GG_Target:GetTarget(blazeList, 1), self.QData, Menu.qset.comhar.hitchance:Value() + 1) then
                    return
                end
                if not Menu.qset.comhar.stun:Value() and Game.Timer() > GG_Spell.WkTimer + 1.33 and Game.Timer() > GG_Spell.EkTimer + 0.77 and Game.Timer() > GG_Spell.RkTimer + 0.77 then
                    if AIO:Cast(HK_Q, GG_Target:GetTarget(AIO:GetEnemyHeroes(1050), 1), self.QData, Menu.qset.comhar.hitchance:Value() + 1) then
                        return
                    end
                end
                -- Auto
            elseif Menu.qset.auto.stun:Value() then
                if Game.Timer() < GG_Spell.EkTimer + 1 and Game.Timer() < GG_Spell.ETimer + 1 and AIO:IsValidHero(self.ETarget) and self.ETarget:GetCollision(self.QData.Radius, self.QData.Speed, self.QData.Delay) == 0 then
                    if AIO:Cast(HK_Q, self.ETarget, self.QData, Menu.qset.auto.hitchance:Value() + 1) then
                        return
                    end
                end
                local blazeList = {}
                local enemyList = AIO:GetEnemyHeroes(1050)
                for i = 1, #enemyList do
                    local unit = enemyList[i]
                    if unit and GG_Buff:GetBuffDuration(unit, "brandablaze") > 0.5 and unit:GetCollision(self.QData.Radius, self.QData.Speed, self.QData.Delay) == 0 then
                        blazeList[#blazeList + 1] = unit
                    end
                end
                if AIO:Cast(HK_Q, GG_Target:GetTarget(blazeList, 1), self.QData, Menu.qset.auto.hitchance:Value() + 1) then
                    return
                end
            end
        end
        -- E
        if GG_Spell:IsReady(_E, {q = 0.33, w = 0.53, e = 0.5, r = 0.33}) then
            -- antigap
            local enemyList = AIO:GetEnemyHeroes(635)
            for i = 1, #enemyList do
                local unit = enemyList[i]
                if unit and unit.distance < 300 and AIO:Cast(HK_E, unit) then
                    return
                end
            end
            -- KS
            if Menu.eset.killsteal.enabled:Value() then
                local baseDmg = 50
                local lvlDmg = 20 * myHero:GetSpellData(_E).level
                local apDmg = myHero.ap * 0.35
                local eDmg = baseDmg + lvlDmg + apDmg
                local minHP = Menu.eset.killsteal.minhp:Value()
                if eDmg > minHP then
                    for i = 1, #enemyList do
                        local unit = enemyList[i]
                        if unit and unit.health > minHP and unit.health < GG_Damage:CalculateDamage(myHero, unit, DAMAGE_TYPE_MAGICAL, eDmg) and AIO:Cast(HK_E, unit) then
                            return
                        end
                    end
                end
            end
            -- Combo / Harass
            if (GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.eset.comhar.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.eset.comhar.harass:Value()) then
                local blazeList = {}
                for i = 1, #enemyList do
                    local unit = enemyList[i]
                    if unit and GG_Buff:GetBuffDuration(unit, "brandablaze") > 0.33 then
                        blazeList[#blazeList + 1] = unit
                    end
                end
                local eTarget = GG_Target:GetTarget(blazeList, 1)
                if eTarget and AIO:Cast(HK_E, eTarget) then
                    self.ETarget = eTarget
                    return
                end
                if Game.Timer() > GG_Spell.QkTimer + 0.77 and Game.Timer() > GG_Spell.WkTimer + 1.33 and Game.Timer() > GG_Spell.RkTimer + 0.77 then
                    eTarget = GG_Target:GetTarget(enemyList, 1)
                    if eTarget and AIO:Cast(HK_E, eTarget) then
                        self.ETarget = eTarget
                        return
                    end
                end
                -- Auto
            elseif myHero:GetSpellData(_Q).level > 0 and myHero:GetSpellData(_W).level > 0 then
                -- EQ -> if Q ready | no collision & W not ready $ mana for Q + E
                if Menu.eset.auto.stun:Value() and myHero.mana > myHero:GetSpellData(_Q).mana + myHero:GetSpellData(_E).mana then
                    if (Game.CanUseSpell(_Q) == 0 or myHero:GetSpellData(_Q).currentCd < 0.75) and not(Game.CanUseSpell(_W) == 0 or myHero:GetSpellData(_W).currentCd < 0.75) then
                        local blazeList = {}
                        local enemyList = AIO:GetEnemyHeroes(635)
                        for i = 1, #enemyList do
                            local unit = enemyList[i]
                            if unit and GG_Buff:GetBuffDuration(unit, "brandablaze") > 0.33 then
                                blazeList[#blazeList + 1] = unit
                            end
                        end
                        local eTarget = GG_Target:GetTarget(blazeList, 1)
                        if eTarget and eTarget:GetCollision(self.QData.Radius, self.QData.Speed, self.QData.Delay) == 0 and AIO:Cast(HK_E, eTarget) then
                            return
                        end
                        if Game.Timer() > GG_Spell.QkTimer + 0.77 and Game.Timer() > GG_Spell.WkTimer + 1.33 and Game.Timer() > GG_Spell.RkTimer + 0.77 then
                            eTarget = GG_Target:GetTarget(enemyList, 1)
                            if eTarget and eTarget:GetCollision(self.QData.Radius, self.QData.Speed, self.QData.Delay) == 0 and AIO:Cast(HK_E, eTarget) then
                                self.ETarget = eTarget
                                return
                            end
                        end
                    end
                end
                -- Passive -> If Q not ready & W not ready $ enemy has passive buff
                if Menu.eset.auto.passive:Value() and not(Game.CanUseSpell(_Q) == 0 or myHero:GetSpellData(_Q).currentCd < 0.75) and not(Game.CanUseSpell(_W) == 0 or myHero:GetSpellData(_W).currentCd < 0.75) then
                    local blazeList = {}
                    local enemyList = AIO:GetEnemyHeroes(670)
                    for i = 1, #enemyList do
                        local unit = enemyList[i]
                        if unit and GG_Buff:GetBuffDuration(unit, "brandablaze") > 0.33 then
                            blazeList[#blazeList + 1] = unit
                        end
                    end
                    local eTarget = GG_Target:GetTarget(blazeList, 1)
                    if eTarget and AIO:Cast(HK_E, eTarget) then
                        self.ETarget = eTarget
                        return
                    end
                end
            end
        end
        -- W
        if GG_Spell:IsReady(_W, {q = 0.33, w = 0.5, e = 0.33, r = 0.33}) then
            -- KS
            if Menu.wset.killsteal.enabled:Value() then
                local baseDmg = 30
                local lvlDmg = 45 * myHero:GetSpellData(_W).level
                local apDmg = myHero.ap * 0.6
                local wDmg = baseDmg + lvlDmg + apDmg
                local minHP = Menu.wset.killsteal.minhp:Value()
                if wDmg > minHP then
                    local enemyList = AIO:GetEnemyHeroes(950)
                    for i = 1, #enemyList do
                        local wTarget = enemyList[i]
                        if wTarget and wTarget.health > minHP and wTarget.health < GG_Damage:CalculateDamage(myHero, wTarget, DAMAGE_TYPE_MAGICAL, wDmg) and AIO:Cast(HK_W, wTarget, self.WData, Menu.wset.killsteal.hitchance:Value() + 1) then
                            return;
                        end
                    end
                end
            end
            -- Combo / Harass
            if (GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.wset.comhar.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.wset.comhar.harass:Value()) then
                local blazeList = {}
                local enemyList = AIO:GetEnemyHeroes(950)
                for i = 1, #enemyList do
                    local unit = enemyList[i]
                    if GG_Buff:GetBuffDuration(unit, "brandablaze") > 1.33 then
                        blazeList[#blazeList + 1] = unit
                    end
                end
                local wTarget = GG_Target:GetTarget(blazeList, 1)
                if wTarget and AIO:Cast(HK_W, wTarget, self.WData, Menu.wset.comhar.hitchance:Value() + 1) then
                    return
                end
                if Game.Timer() > GG_Spell.QkTimer + 0.77 and Game.Timer() > GG_Spell.EkTimer + 0.77 and Game.Timer() > GG_Spell.RkTimer + 0.77 then
                    wTarget = GG_Target:GetTarget(enemyList, 1)
                    if wTarget and AIO:Cast(HK_W, wTarget, self.WData, Menu.wset.comhar.hitchance:Value() + 1) then
                        return
                    end
                end
                -- Auto
            elseif Menu.wset.auto.enabled:Value() then
                for i = 1, 3 do
                    local blazeList = {}
                    local enemyList = AIO:GetEnemyHeroes(1200 - (i * 100))
                    for j = 1, #enemyList do
                        local unit = enemyList[j]
                        if unit and GG_Buff:GetBuffDuration(unit, "brandablaze") > 1.33 then
                            blazeList[#blazeList + 1] = unit
                        end
                    end
                    local wTarget = GG_Target:GetTarget(blazeList, 1);
                    if wTarget then
                        if AIO:Cast(HK_W, wTarget, self.WData, Menu.wset.auto.hitchance:Value() + 1) then
                            return
                        end
                    end
                    if Game.Timer() > GG_Spell.QkTimer + 0.77 and Game.Timer() > GG_Spell.EkTimer + 0.77 and Game.Timer() > GG_Spell.RkTimer + 0.77 then
                        wTarget = GG_Target:GetTarget(enemyList, 1)
                        if wTarget then
                            if AIO:Cast(HK_W, wTarget, self.WData, Menu.wset.auto.hitchance:Value() + 1) then
                                return
                            end
                        end
                    end
                end
            end
        end
        -- R
        if GG_Spell:IsReady(_R, {q = 0.33, w = 0.33, e = 0.33, r = 0.5}) then
            -- Combo / Harass
            if (GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.rset.comhar.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.rset.comhar.harass:Value()) then
                local enemyList = AIO:GetEnemyHeroes(750)
                local xRange = Menu.rset.comhar.xrange:Value()
                local xEnemies = Menu.rset.comhar.xenemies:Value()
                for i = 1, #enemyList do
                    local count = 0
                    local rTarget = enemyList[i]
                    if rTarget then
                        for j = 1, #enemyList do
                            if i ~= j then
                                local unit = enemyList[j]
                                if unit and rTarget.pos:DistanceTo(unit.pos) < xRange then
                                    count = count + 1
                                end
                            end
                        end
                        if count >= xEnemies and AIO:Cast(HK_R, rTarget) then
                            return
                        end
                    end
                end
                -- Auto
            elseif Menu.rset.auto.enabled:Value() then
                local enemyList = AIO:GetEnemyHeroes(750)
                local xRange = Menu.rset.auto.xrange:Value()
                local xEnemies = Menu.rset.auto.xenemies:Value()
                for i = 1, #enemyList do
                    local count = 0
                    local rTarget = enemyList[i]
                    if rTarget then
                        for j = 1, #enemyList do
                            if i ~= j then
                                local unit = enemyList[j]
                                if unit and rTarget.pos:DistanceTo(unit.pos) < xRange then
                                    count = count + 1
                                end
                            end
                        end
                        if count >= xEnemies and AIO:Cast(HK_R, rTarget) then
                            return
                        end
                    end
                end
            end
        end
    end
 
    function Brand:CanMove()
        if not GG_Spell:CanTakeAction({q = 0.2, w = 0.2, e = 0.2, r = 0.2}) then
            return false
        end
        return true
    end
 
    function Brand:CanAttack()
        if not GG_Spell:CanTakeAction({q = 0.33, w = 0.33, e = 0.33, r = 0.33}) then
            return false
        end
        -- LastHit, LaneClear
        if not GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and not GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] then
            return true
        end
        -- W
        local wData = myHero:GetSpellData(_W);
        if Menu.wset.disaa:Value() and wData.level > 0 and myHero.mana > wData.mana and (Game.CanUseSpell(_W) == 0 or wData.currentCd < 1) then
            return false
        end
        -- E
        local eData = myHero:GetSpellData(_E);
        if Menu.eset.disaa:Value() and eData.level > 0 and myHero.mana > eData.mana and (Game.CanUseSpell(_E) == 0 or eData.currentCd < 1) then
            return false
        end
        return true
    end
end
]]

if Champion ~= nil then
    function Champion:PreTick()
        self.IsCombo = GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO]
        self.IsHarass = GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS]
        self.IsLaneClear = GG_Orbwalker.Modes[ORBWALKER_MODE_LANECLEAR]
        self.IsLastHit = GG_Orbwalker.Modes[ORBWALKER_MODE_LASTHIT]
        self.AttackTarget = nil
        self.CanAttackTarget = false
        self.IsAttacking = GG_Orbwalker:IsAutoAttacking()
        if not self.IsAttacking and (self.IsCombo or self.IsHarass) then
            self.AttackTarget = GG_Target:GetComboTarget()
            self.CanAttack = GG_Orbwalker:CanAttack()
            if self.AttackTarget and self.CanAttack then
                self.CanAttackTarget = true
            else
                self.CanAttackTarget = false
            end
        end
        self.Timer = Game.Timer()
        self.Pos = myHero.pos
        self.BoundingRadius = myHero.boundingRadius
        self.Range = myHero.range + self.BoundingRadius
        self.ManaPercent = 100 * myHero.mana / myHero.maxMana
        self.EnemyHeroes = GG_Object:GetEnemyHeroes(false, false, true)
        Utils.CachedDistance = {}
    end
    Callback.Add('Load', function()
        GG_Target = _G.SDK.TargetSelector
        GG_Orbwalker = _G.SDK.Orbwalker
        GG_Buff = _G.SDK.BuffManager
        GG_Damage = _G.SDK.Damage
        GG_Spell = _G.SDK.Spell
        GG_Object = _G.SDK.ObjectManager
        GG_Attack = _G.SDK.Attack
        GG_Data = _G.SDK.Data
        GG_Cursor = _G.SDK.Cursor
        GG_Orbwalker:CanAttackEvent(Champion.CanAttackCb)
        GG_Orbwalker:CanMoveEvent(Champion.CanMoveCb)
        if Champion.OnLoad then
            Champion:OnLoad()
        end
        if Champion.OnPreAttack then
            GG_Orbwalker:OnPreAttack(Champion.OnPreAttack)
        end
        if Champion.OnAttack then
            GG_Orbwalker:OnAttack(Champion.OnAttack)
        end
        if Champion.OnPostAttack then
            GG_Orbwalker:OnPostAttack(Champion.OnPostAttack)
        end
        if Champion.OnPostAttackTick then
            GG_Orbwalker:OnPostAttackTick(Champion.OnPostAttackTick)
        end
        if Champion.OnTick then
            table.insert(_G.SDK.OnTick, function()
                Champion:PreTick()
                Champion:OnTick()
                Utils.CanUseSpell = true
            end)
        end
        if Champion.OnDraw then
            table.insert(_G.SDK.OnDraw, function()
                Champion:OnDraw()
            end)
        end
        if Champion.OnWndMsg then
            table.insert(_G.SDK.OnWndMsg, function(msg, wParam)
                Champion:OnWndMsg(msg, wParam)
            end)
        end
    end)
    return
end
print(myHero.charName .. " not supported !")
