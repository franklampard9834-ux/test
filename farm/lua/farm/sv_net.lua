-- 농장 메뉴 동작 처리 (클라이언트 요청은 모두 서버에서 다시 검사한다)

for _, name in ipairs({ "farm_cow_menu", "farm_cow_action", "farm_shop_menu", "farm_shop_buy",
    "farm_shop_sell", "farm_main_request", "farm_main_data", "farm_main_action" }) do
    util.AddNetworkString(name)
end

local USE_DIST = 200

local function RateLimited(ply)
    local now = CurTime()
    if (ply.FarmNextAction or 0) > now then return true end
    ply.FarmNextAction = now + 0.2
    return false
end

local function Near(ply, ent)
    return IsValid(ent) and ply:GetPos():DistToSqr(ent:GetPos()) <= (USE_DIST + 100) ^ 2
end

local function CowOf(ply, ent)
    if not IsValid(ent) or ent:GetClass() ~= "farm_cow" or ent:GetFarmOwner() ~= ply then return end
    if not Near(ply, ent) then return end
    local farm = FARM.GetFarm(ply)
    local obj = farm and farm.objects[ent.FarmId]
    if not obj then return end
    return farm, obj
end

-- 소 메뉴 열기 (엔티티 Use 에서 호출)
function FARM.OpenCowMenu(ply, ent)
    net.Start("farm_cow_menu")
        net.WriteEntity(ent)
    net.Send(ply)
end

function FARM.OpenShopMenu(ply, ent)
    net.Start("farm_shop_menu")
        net.WriteEntity(ent)
    net.Send(ply)
end

local function SpawnBeef(farm, pos, grade, count)
    for i = 1, count do
        local beef = ents.Create("farm_beef")
        if not IsValid(beef) then return end
        beef:SetPos(pos + Vector(math.Rand(-20, 20), math.Rand(-20, 20), 20 + i * 12))
        beef:SetAngles(Angle(0, math.Rand(0, 360), 0))
        beef:SetGrade(grade)
        beef:SetFarmOwner(farm.ply)
        beef.FarmSid = farm.sid
        beef:Spawn()
        if beef.CPPISetOwner then beef:CPPISetOwner(farm.ply) end
    end
end

net.Receive("farm_cow_action", function(_, ply)
    if RateLimited(ply) then return end
    local ent = net.ReadEntity()
    local action = net.ReadString()
    local farm, obj = CowOf(ply, ent)
    if not farm then return end
    local C = FARM.Config.Cow

    -- 최신 상태로 계산한 뒤 처리한다.
    FARM.PullEntityState(farm)
    FARM.HandleEvents(farm, FARM.Advance(farm))
    if not farm.objects[obj.id] then return end

    if action == "milk" then
        if not obj.female or obj.growth < 1 then return end
        local n = math.floor(obj.udder)
        if n < 1 then
            FARM.Notify(ply, "아직 짤 우유가 없습니다.")
            return
        end
        obj.udder = obj.udder - n
        farm.inv.milk = farm.inv.milk + n
        FARM.Notify(ply, string.format("우유 %d병을 짰습니다.", n))
        ent:EmitSound("ambient/water/water_spray1.wav", 60, 110)

    elseif action == "feed" then
        if obj.growth >= 1 then return end
        local per = C.CalfMilkHours * FARM.HOUR
        local space = math.floor((C.CalfMilkMax * per - obj.milkStock) / per)
        local give = math.min(space, farm.inv.milk)
        if give < 1 then
            FARM.Notify(ply, space < 1 and "송아지가 배부릅니다." or "우유가 없습니다. 상점에서 사거나 젖소에게서 짜 오세요.")
            return
        end
        farm.inv.milk = farm.inv.milk - give
        obj.milkStock = obj.milkStock + give * per
        FARM.Notify(ply, string.format("송아지에게 우유 %d병을 먹였습니다.", give))

    elseif action == "ship" then
        if obj.growth < 1 then return end
        local old = obj.age >= C.PrimeEnd
        local count = old and C.OldBeef or C.PrimeBeef
        local pos = ent:GetPos()
        local name = FARM.CowName(obj)
        local grade = obj.grade
        FARM.DeleteObject(farm, obj.id)
        SpawnBeef(farm, pos, grade, count)
        FARM.Notify(ply, string.format("[%s] 출하했습니다. 소고기 %d개(%s등급)가 나왔습니다. E로 주우세요.",
            name, count, FARM.GradeName(grade)))

    elseif action == "rename" then
        local name = string.gsub(net.ReadString(), "[%c\"\\]", "")
        name = string.Trim(name)
        if utf8.len(name) and utf8.len(name) > 20 then
            name = string.sub(name, 1, utf8.offset(name, 21) - 1)
        end
        obj.name = name
        FARM.Notify(ply, "이름을 바꿨습니다.")
    else
        return
    end

    FARM.SyncEntities(farm)
    FARM.SyncInventory(farm)
end)

local function ShopNear(ply, ent)
    return IsValid(ent) and ent:GetClass() == "farm_shop" and Near(ply, ent)
end

local function Pay(farm, price)
    if farm.coins < price then
        FARM.Notify(farm.ply, "코인이 부족합니다.")
        return false
    end
    farm.coins = farm.coins - price
    return true
end

net.Receive("farm_shop_buy", function(_, ply)
    if RateLimited(ply) then return end
    local shop = net.ReadEntity()
    local item = net.ReadString()
    local amount = math.Clamp(net.ReadUInt(8), 1, 100)
    local farm = FARM.GetFarm(ply)
    if not farm or not ShopNear(ply, shop) then return end
    local def = FARM.Config.Shop.Buy[item]
    if not def then return end

    if item == "calf_f" or item == "calf_m" then
        if FARM.CountCattle(farm) >= FARM.MaxCattle() then
            FARM.Notify(ply, string.format("소는 최대 %d마리까지 키울 수 있습니다.", FARM.MaxCattle()))
            return
        end
        if not Pay(farm, def.price) then return end
        local cow = FARM.NewCow(item == "calf_f", FARM.Config.ShopGrade)
        cow.milkStock = FARM.Config.Cow.NewbornMilk * FARM.Config.Cow.CalfMilkHours * FARM.HOUR
        cow.fed = true
        local pos, ang = FARM.SpawnPosFor(ply, 120)
        cow.pos = FARM.PackVec(pos)
        cow.home = FARM.PackVec(pos)
        cow.yaw = ang.y
        FARM.NewObject(farm, cow)
        FARM.Notify(ply, string.format("%s를 샀습니다. 우유를 먹여 키우세요.", def.name))
    elseif item == "feeder" then
        if not Pay(farm, def.price) then return end
        farm.inv.feeder = farm.inv.feeder + 1
        FARM.Notify(ply, "사료통을 샀습니다. 농장 메뉴(!farm)에서 설치하세요.")
    else
        if not Pay(farm, def.price * amount) then return end
        farm.inv[item] = farm.inv[item] + def.amount * amount
        FARM.Notify(ply, string.format("%s x%d 을(를) 샀습니다.", def.name, amount))
    end

    FARM.SyncEntities(farm)
    FARM.SyncInventory(farm)
end)

net.Receive("farm_shop_sell", function(_, ply)
    if RateLimited(ply) then return end
    local shop = net.ReadEntity()
    local item = net.ReadString()
    local grade = net.ReadUInt(4)
    local all = net.ReadBool()
    local farm = FARM.GetFarm(ply)
    if not farm or not ShopNear(ply, shop) then return end

    local have, price
    if item == "milk" then
        have, price = farm.inv.milk, FARM.Config.Shop.SellMilk
    elseif item == "beef" and FARM.Config.Grades[grade] then
        have, price = farm.inv.beef[grade] or 0, FARM.Config.Grades[grade].beef
    else
        return
    end

    local n = all and have or math.min(1, have)
    if n < 1 then return end
    if item == "milk" then
        farm.inv.milk = have - n
    else
        farm.inv.beef[grade] = have - n
    end
    farm.coins = farm.coins + n * price
    FARM.Notify(ply, string.format("%d개를 %d코인에 팔았습니다.", n, n * price))
    FARM.SyncInventory(farm)
end)

-- 농장 메뉴 (!farm)
local function SendMainData(ply, farm)
    local map = game.GetMap()
    local list = {}
    for id, o in pairs(farm.objects) do
        if o.kind == "cow" then
            list[#list + 1] = {
                id = id, kind = "cow", name = FARM.CowName(o), female = o.female, grade = o.grade,
                stage = FARM.CowStage(o.growth, o.age), age = o.age, here = o.map == map, map = o.map,
                fed = o.fed, pregnant = o.pregnant,
            }
        elseif o.kind == "feeder" then
            list[#list + 1] = { id = id, kind = "feeder", feed = o.feed, here = o.map == map, map = o.map }
        end
    end
    net.Start("farm_main_data")
        net.WriteTable(list)
    net.Send(ply)
end

net.Receive("farm_main_request", function(_, ply)
    if RateLimited(ply) then return end
    local farm = FARM.GetFarm(ply)
    if not farm then return end
    FARM.SyncInventory(farm)
    SendMainData(ply, farm)
end)

net.Receive("farm_main_action", function(_, ply)
    if RateLimited(ply) then return end
    local action = net.ReadString()
    local id = net.ReadUInt(32)
    local farm = FARM.GetFarm(ply)
    if not farm then return end

    if action == "retrieve" then
        local obj = farm.objects[id]
        if not obj or obj.map == game.GetMap() then return end
        local pos, ang = FARM.SpawnPosFor(ply, 120)
        obj.map = game.GetMap()
        obj.pos = FARM.PackVec(pos)
        obj.home = FARM.PackVec(pos)
        obj.yaw = ang.y
        FARM.Notify(ply, "보관함에서 꺼냈습니다.")
    elseif action == "place_feeder" then
        if farm.inv.feeder < 1 then return end
        farm.inv.feeder = farm.inv.feeder - 1
        local pos, ang = FARM.SpawnPosFor(ply, 120)
        FARM.NewObject(farm, { kind = "feeder", feed = 0, map = game.GetMap(), pos = FARM.PackVec(pos), yaw = ang.y })
        FARM.Notify(ply, "사료통을 설치했습니다. E로 사료를 채우세요.")
    else
        return
    end

    FARM.SyncEntities(farm)
    FARM.SyncInventory(farm)
    SendMainData(ply, farm)
end)

local function OpenMain(ply)
    if not IsValid(ply) then return end
    ply:ConCommand("farm_menu")
end

hook.Add("PlayerSay", "farm_chat", function(ply, text)
    local t = string.lower(string.Trim(text))
    if t == "!farm" or t == "/farm" or t == "!농장" then
        OpenMain(ply)
        return ""
    end
end)
