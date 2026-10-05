-- 농장 서버 핵심: 접속/퇴장, 주기 계산, 엔티티 관리, 보호

local TICK = 5

local CLASS_OF = { cow = "farm_cow", feeder = "farm_feeder" }

function FARM.SpawnPosFor(ply, dist)
    local start = ply:EyePos()
    local dir = ply:GetAimVector()
    dir.z = 0
    dir:Normalize()
    local tr = util.TraceLine({ start = start, endpos = start + dir * dist, filter = ply })
    local pos = tr.HitPos - dir * 20
    local down = util.TraceLine({ start = pos + Vector(0, 0, 10), endpos = pos - Vector(0, 0, 300), filter = ply })
    return down.HitPos, Angle(0, ply:EyeAngles().y + 180, 0)
end

function FARM.UpdateEntity(ent, obj)
    if obj.kind == "cow" then
        ent:SetGrade(obj.grade)
        ent:SetFemale(obj.female)
        ent:SetFed(obj.fed and true or false)
        ent:SetPregnant(obj.pregnant and true or false)
        ent:SetPregProgress(obj.preg or 0)
        ent:SetGrowth(obj.growth)
        ent:SetUdder(obj.udder)
        ent:SetAge(obj.age)
        ent:SetMilkStock(obj.milkStock)
        ent:SetCowName(FARM.CowName(obj))
    elseif obj.kind == "feeder" then
        ent:SetFeed(obj.feed)
    end
    if ent.ApplyLook then ent:ApplyLook() end
end

function FARM.SpawnObjectEntity(farm, obj)
    local class = CLASS_OF[obj.kind]
    if not class or not IsValid(farm.ply) then return end

    local ent = ents.Create(class)
    if not IsValid(ent) then return end
    ent.FarmId = obj.id
    ent.FarmSid = farm.sid
    ent:SetPos(FARM.UnpackVec(obj.pos))
    ent:SetAngles(Angle(0, tonumber(obj.yaw) or 0, 0))
    ent:SetFarmOwner(farm.ply)
    if obj.home then ent.FarmHome = FARM.UnpackVec(obj.home) end
    ent:Spawn()
    ent:Activate()
    if ent.CPPISetOwner then ent:CPPISetOwner(farm.ply) end

    farm.ents[obj.id] = ent
    FARM.UpdateEntity(ent, obj)
    return ent
end

-- 엔티티가 움직인 위치를 데이터에 반영한다.
function FARM.PullEntityState(farm)
    for id, ent in pairs(farm.ents) do
        local obj = farm.objects[id]
        if IsValid(ent) and obj then
            obj.pos = FARM.PackVec(ent:GetPos())
            obj.yaw = math.Round(ent:GetAngles().y, 1)
            if ent.FarmHome then obj.home = FARM.PackVec(ent.FarmHome) end
        end
    end
end

-- 현재 맵에 있어야 할 엔티티를 만들고, 상태를 갱신한다.
function FARM.SyncEntities(farm)
    local map = game.GetMap()
    for id, obj in pairs(farm.objects) do
        if obj.map == map and CLASS_OF[obj.kind] then
            local ent = farm.ents[id]
            if IsValid(ent) then
                FARM.UpdateEntity(ent, obj)
            else
                FARM.SpawnObjectEntity(farm, obj)
            end
        end
    end
    for id, ent in pairs(farm.ents) do
        local obj = farm.objects[id]
        if not obj or obj.map ~= map then
            if IsValid(ent) then
                ent.FarmRemoving = true
                ent:Remove()
            end
            farm.ents[id] = nil
        end
    end
end

local SEX = { [true] = "암컷", [false] = "수컷" }

local function EventMessage(e)
    if e.t == "born" then
        return string.format("[%s] 송아지를 낳았습니다! (%s, %s등급)", e.mother, SEX[e.female], FARM.GradeName(e.grade))
    elseif e.t == "grown" then
        return string.format("[%s] 다 자랐습니다.", e.name)
    elseif e.t == "pregnant" then
        return string.format("[%s] 임신했습니다.", e.name)
    elseif e.t == "died" then
        return string.format("[%s] 수명을 다했습니다. 소고기 %d개(%s등급)가 보관함에 들어갔습니다.",
            e.name, e.beef, FARM.GradeName(e.grade))
    elseif e.t == "feeder_empty" then
        return "사료통 하나가 비었습니다."
    end
end

function FARM.HandleEvents(farm, events)
    local changedInv = false
    for _, e in ipairs(events) do
        local msg = EventMessage(e)
        if msg then FARM.Notify(farm.ply, msg) end
        if e.t == "died" then changedInv = true end
    end
    if changedInv then FARM.SyncInventory(farm) end
end

-- 재접속 시 자리를 비운 동안의 요약
local function SendSummary(farm, events, realAway)
    local count = {}
    for _, e in ipairs(events) do count[e.t] = (count[e.t] or 0) + 1 end

    local parts = {}
    if count.born then parts[#parts + 1] = string.format("송아지 %d마리 탄생", count.born) end
    if count.grown then parts[#parts + 1] = string.format("%d마리 성장", count.grown) end
    if count.pregnant then parts[#parts + 1] = string.format("%d마리 임신", count.pregnant) end
    if count.died then parts[#parts + 1] = string.format("%d마리 수명 다함 (소고기는 보관함에)", count.died) end
    if count.feeder_empty then parts[#parts + 1] = "사료통이 비었음" end

    local full = 0
    for _, o in pairs(farm.objects) do
        if o.kind == "cow" and o.female and o.growth >= 1 and o.udder >= FARM.UdderCap(o.grade) - 0.01 then
            full = full + 1
        end
    end
    if full > 0 then parts[#parts + 1] = string.format("젖이 가득 찬 소 %d마리", full) end

    if #parts == 0 then return end
    FARM.Notify(farm.ply, string.format("자리를 비운 %s 동안: %s",
        FARM.FormatTime(realAway * FARM.TimeScale()), table.concat(parts, ", ")))
end

function FARM.PlayerJoin(ply)
    if not IsValid(ply) or FARM.GetFarm(ply) then return end
    local farm = FARM.LoadFarm(ply)
    local away = os.time() - farm.lastSim
    local events = FARM.Advance(farm)
    FARM.SyncEntities(farm)
    FARM.SyncInventory(farm)
    FARM.SaveFarm(farm)
    if away > 60 then SendSummary(farm, events, away) end
end

-- 바닥에 남은 소고기는 주인 보관함으로 넣는다.
local function CollectBeef(farm)
    for _, ent in ipairs(ents.FindByClass("farm_beef")) do
        if ent.FarmSid == farm.sid then
            local g = ent:GetGrade()
            farm.inv.beef[g] = (farm.inv.beef[g] or 0) + 1
            ent:Remove()
        end
    end
end

function FARM.PlayerLeave(ply)
    local sid = ply:SteamID64()
    local farm = FARM.Farms[sid]
    if not farm then return end
    FARM.PullEntityState(farm)
    FARM.Advance(farm)
    CollectBeef(farm)
    for _, ent in pairs(farm.ents) do
        if IsValid(ent) then
            ent.FarmRemoving = true
            ent:Remove()
        end
    end
    FARM.SaveFarm(farm)
    FARM.Farms[sid] = nil
end

hook.Add("PlayerInitialSpawn", "farm_join", function(ply)
    timer.Simple(3, function() FARM.PlayerJoin(ply) end)
end)

hook.Add("PlayerDisconnected", "farm_leave", FARM.PlayerLeave)

timer.Create("farm_tick", TICK, 0, function()
    for _, farm in pairs(FARM.Farms) do
        if IsValid(farm.ply) then
            FARM.PullEntityState(farm)
            local events = FARM.Advance(farm)
            FARM.SyncEntities(farm)
            FARM.HandleEvents(farm, events)
        end
    end
end)

timer.Create("farm_save", 120, 0, function()
    for _, farm in pairs(FARM.Farms) do
        FARM.PullEntityState(farm)
        FARM.SaveFarm(farm)
    end
end)

hook.Add("ShutDown", "farm_shutdown", function()
    FARM.ShuttingDown = true
    for _, farm in pairs(FARM.Farms) do
        FARM.PullEntityState(farm)
        FARM.Advance(farm)
        CollectBeef(farm)
        FARM.SaveFarm(farm)
    end
end)

hook.Add("InitPostEntity", "farm_shops", function()
    FARM.LoadShops()
end)

-- 맵 정리(Clean up) 후에도 농장이 다시 나타나게 한다.
hook.Add("PreCleanupMap", "farm_cleanup", function()
    FARM.CleaningUp = true
    for _, farm in pairs(FARM.Farms) do
        FARM.PullEntityState(farm)
        CollectBeef(farm)
    end
end)

hook.Add("PostCleanupMap", "farm_cleanup", function()
    FARM.CleaningUp = false
    for _, farm in pairs(FARM.Farms) do
        farm.ents = {}
        FARM.SyncEntities(farm)
        FARM.SyncInventory(farm)
    end
    FARM.LoadShops()
end)

-- 보호: 주인(또는 관리자)만 물리건으로 옮길 수 있고, 툴건/우클릭 메뉴로는 지울 수 없다.
local function CanHandle(ply, ent)
    if ent:GetClass() == "farm_shop" then return ply:IsAdmin() end
    return ent:GetFarmOwner() == ply or ply:IsAdmin()
end

hook.Add("PhysgunPickup", "farm_protect", function(ply, ent)
    if not FARM.IsFarmEntity(ent) then return end
    if ent:GetClass() == "farm_beef" then return ent:GetFarmOwner() == ply end
    return CanHandle(ply, ent)
end)

hook.Add("OnPhysgunPickup", "farm_held", function(ply, ent)
    if FARM.IsFarmEntity(ent) then ent.FarmHeld = true end
end)

hook.Add("PhysgunDrop", "farm_drop", function(ply, ent)
    if not FARM.IsFarmEntity(ent) or ent:GetClass() == "farm_beef" then return end
    ent.FarmHeld = false
    timer.Simple(0, function()
        if IsValid(ent) and ent.OnPlaced then ent:OnPlaced() end
    end)
end)

hook.Add("CanPlayerUnfreeze", "farm_protect", function(ply, ent)
    if FARM.IsFarmEntity(ent) and ent:GetClass() ~= "farm_beef" then return false end
end)

hook.Add("CanTool", "farm_protect", function(ply, tr, tool)
    local ent = tr.Entity
    if not FARM.IsFarmEntity(ent) then return end
    if ent:GetClass() == "farm_shop" and ply:IsAdmin() and tool == "remover" then return end
    return false
end)

hook.Add("CanProperty", "farm_protect", function(ply, prop, ent)
    if not FARM.IsFarmEntity(ent) then return end
    if ent:GetClass() == "farm_shop" and ply:IsAdmin() then return end
    return false
end)

hook.Add("GravGunPickupAllowed", "farm_protect", function(ply, ent)
    if FARM.IsFarmEntity(ent) and ent:GetClass() ~= "farm_beef" then return false end
end)

hook.Add("GravGunPunt", "farm_protect", function(ply, ent)
    if FARM.IsFarmEntity(ent) and ent:GetClass() ~= "farm_beef" then return false end
end)

-- 관리자용: 코인 지급
concommand.Add("farm_givecoins", function(ply, _, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local amount = tonumber(args[1]) or 0
    local target = IsValid(ply) and ply or nil
    if args[2] then
        for _, p in ipairs(player.GetAll()) do
            if string.find(string.lower(p:Nick()), string.lower(args[2]), 1, true) then target = p break end
        end
    end
    local farm = FARM.GetFarm(target)
    if not farm then return end
    farm.coins = math.max(0, farm.coins + amount)
    FARM.SyncInventory(farm)
    FARM.Notify(target, string.format("코인 %d이 지급되었습니다.", amount))
end)

-- 이미 접속한 플레이어 (애드온 리로드 대비)
for _, ply in ipairs(player.GetAll()) do
    if not FARM.GetFarm(ply) then FARM.PlayerJoin(ply) end
end
