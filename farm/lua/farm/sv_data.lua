-- 농장 데이터 저장/불러오기 (서버 SQLite)
-- 플레이어 정보(코인, 인벤토리, 마지막 계산 시각)와 농장 오브젝트(소, 사료통)를 저장한다.
-- 데이터가 원본이고, 맵 위의 엔티티는 데이터를 보여주는 역할만 한다.

util.AddNetworkString("farm_sync")
util.AddNetworkString("farm_notify")

FARM.Farms = FARM.Farms or {}

sql.Query([[CREATE TABLE IF NOT EXISTS farm_players (
    sid TEXT PRIMARY KEY, coins INTEGER, inv TEXT, last_sim INTEGER)]])
sql.Query([[CREATE TABLE IF NOT EXISTS farm_objects (
    id INTEGER PRIMARY KEY AUTOINCREMENT, sid TEXT, data TEXT)]])
sql.Query([[CREATE TABLE IF NOT EXISTS farm_shops (map TEXT PRIMARY KEY, data TEXT)]])

local function NewInventory()
    return { feed = 0, milk = 0, feeder = 0, beef = { 0, 0, 0, 0, 0 } }
end

local function FixInventory(inv)
    inv = istable(inv) and inv or {}
    local fresh = NewInventory()
    for k, v in pairs(fresh) do
        if inv[k] == nil then inv[k] = v end
    end
    for i = 1, #FARM.Config.Grades do
        inv.beef[i] = tonumber(inv.beef[i]) or 0
    end
    return inv
end

function FARM.GetFarm(ply)
    if not IsValid(ply) then return nil end
    return FARM.Farms[ply:SteamID64()]
end

function FARM.LoadFarm(ply)
    local sid = ply:SteamID64()
    local row = sql.QueryRow("SELECT * FROM farm_players WHERE sid = " .. sql.SQLStr(sid))
    local now = os.time()

    local farm = {
        sid = sid,
        ply = ply,
        objects = {},
        ents = {},
    }

    if row then
        farm.coins = tonumber(row.coins) or 0
        farm.inv = FixInventory(util.JSONToTable(row.inv or "") or {})
        farm.lastSim = tonumber(row.last_sim) or now
    else
        farm.coins = FARM.Config.StartCoins
        farm.inv = NewInventory()
        farm.lastSim = now
        sql.Query(string.format("INSERT INTO farm_players (sid, coins, inv, last_sim) VALUES (%s, %d, %s, %d)",
            sql.SQLStr(sid), farm.coins, sql.SQLStr(util.TableToJSON(farm.inv)), now))
    end

    local rows = sql.Query("SELECT id, data FROM farm_objects WHERE sid = " .. sql.SQLStr(sid)) or {}
    for _, r in ipairs(rows) do
        local obj = util.JSONToTable(r.data or "")
        if istable(obj) then
            obj.id = tonumber(r.id)
            farm.objects[obj.id] = obj
        end
    end

    FARM.Farms[sid] = farm
    return farm
end

function FARM.SaveFarm(farm)
    sql.Begin()
    sql.Query(string.format("UPDATE farm_players SET coins = %d, inv = %s, last_sim = %d WHERE sid = %s",
        math.floor(farm.coins), sql.SQLStr(util.TableToJSON(farm.inv)), farm.lastSim, sql.SQLStr(farm.sid)))
    for id, obj in pairs(farm.objects) do
        sql.Query(string.format("UPDATE farm_objects SET data = %s WHERE id = %d",
            sql.SQLStr(util.TableToJSON(obj)), id))
    end
    sql.Commit()
end

function FARM.NewObject(farm, obj)
    sql.Query(string.format("INSERT INTO farm_objects (sid, data) VALUES (%s, %s)",
        sql.SQLStr(farm.sid), sql.SQLStr(util.TableToJSON(obj))))
    local id = tonumber(sql.QueryValue("SELECT last_insert_rowid()"))
    obj.id = id
    farm.objects[id] = obj
    return obj
end

function FARM.DeleteObject(farm, id)
    farm.objects[id] = nil
    sql.Query("DELETE FROM farm_objects WHERE id = " .. tonumber(id))
    local ent = farm.ents[id]
    farm.ents[id] = nil
    if IsValid(ent) then
        ent.FarmRemoving = true
        ent:Remove()
    end
end

function FARM.SyncInventory(farm)
    if not IsValid(farm.ply) then return end
    net.Start("farm_sync")
        net.WriteUInt(math.floor(farm.coins), 32)
        net.WriteTable(farm.inv)
    net.Send(farm.ply)
end

function FARM.Notify(ply, msg)
    if not IsValid(ply) then return end
    net.Start("farm_notify")
        net.WriteString(msg)
    net.Send(ply)
end

-- 벡터 <-> 저장용 테이블
function FARM.PackVec(v)
    return { math.Round(v.x, 1), math.Round(v.y, 1), math.Round(v.z, 1) }
end

function FARM.UnpackVec(t)
    if not istable(t) then return Vector(0, 0, 0) end
    return Vector(tonumber(t[1]) or 0, tonumber(t[2]) or 0, tonumber(t[3]) or 0)
end

-- 상점 위치 (맵별)
function FARM.SaveShops()
    if FARM.CleaningUp or FARM.ShuttingDown then return end
    local list = {}
    for _, ent in ipairs(ents.FindByClass("farm_shop")) do
        if not ent.FarmRemoving then
            list[#list + 1] = { pos = FARM.PackVec(ent:GetPos()), yaw = math.Round(ent:GetAngles().y, 1) }
        end
    end
    sql.Query(string.format("REPLACE INTO farm_shops (map, data) VALUES (%s, %s)",
        sql.SQLStr(game.GetMap()), sql.SQLStr(util.TableToJSON(list))))
end

function FARM.LoadShops()
    local data = sql.QueryValue("SELECT data FROM farm_shops WHERE map = " .. sql.SQLStr(game.GetMap()))
    local list = data and util.JSONToTable(data) or {}
    FARM.LoadingShops = true
    for _, s in ipairs(list) do
        local ent = ents.Create("farm_shop")
        ent:SetPos(FARM.UnpackVec(s.pos))
        ent:SetAngles(Angle(0, tonumber(s.yaw) or 0, 0))
        ent:Spawn()
    end
    FARM.LoadingShops = false
end
