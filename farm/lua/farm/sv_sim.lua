-- 농장 시뮬레이션
-- 접속 중에는 몇 초마다, 재접속 때는 자리를 비운 시간만큼 같은 함수로 계산한다.

local MAX_STEP = 60 -- 한 번에 계산하는 최대 농장 시간(초)

function FARM.CowName(obj)
    if obj.name and obj.name ~= "" then return obj.name end
    return "소 #" .. tostring(obj.id)
end

function FARM.NewCow(female, grade)
    return {
        kind = "cow",
        female = female,
        grade = grade,
        age = 0,
        growth = 0,
        milkStock = 0,
        udder = 0,
        pregnant = false,
        preg = 0,
        sireGrade = grade,
        mate = 0,
        cooldown = 0,
        fed = false,
        name = "",
        map = game.GetMap(),
        pos = { 0, 0, 0 },
        home = { 0, 0, 0 },
        yaw = 0,
    }
end

local function Dist2(a, b)
    local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
    return dx * dx + dy * dy + dz * dz
end

-- 가까운 사료통 중 사료가 충분한 것을 찾는다.
local function FindFeeder(feeders, pos, need, radius)
    local best, bestD
    local r2 = radius * radius
    for _, f in ipairs(feeders) do
        if f.feed >= need then
            local d = Dist2(f.pos, pos)
            if d <= r2 and (not bestD or d < bestD) then best, bestD = f, d end
        end
    end
    return best
end

local function CountCattle(farm)
    local n = 0
    for _, o in pairs(farm.objects) do
        if o.kind == "cow" then
            n = n + 1
            if o.pregnant then n = n + 1 end
        end
    end
    return n
end
FARM.CountCattle = CountCattle

local function Step(farm, dt, events)
    local C = FARM.Config.Cow
    local map = game.GetMap()
    local feeders, cattle = {}, {}

    for _, o in pairs(farm.objects) do
        if o.kind == "feeder" and o.map == map then
            feeders[#feeders + 1] = o
        elseif o.kind == "cow" then
            cattle[#cattle + 1] = o
        end
    end

    local hadFeed = {}
    for _, f in ipairs(feeders) do hadFeed[f] = f.feed > 0 end

    local dead = {}
    for _, c in ipairs(cattle) do
        c.age = c.age + dt

        if c.age >= C.Lifespan then
            dead[#dead + 1] = c
        elseif c.growth < 1 then
            -- 송아지: 먹어둔 우유가 있는 동안만 자란다.
            if c.milkStock > 0 then
                c.milkStock = math.max(0, c.milkStock - dt)
                c.growth = math.min(1, c.growth + dt / C.GrowTime)
                c.fed = true
                if c.growth >= 1 then
                    events[#events + 1] = { t = "grown", name = FARM.CowName(c) }
                end
            else
                c.fed = false
            end
        else
            local need = C.FeedPerHour * dt / FARM.HOUR
            local f = c.map == map and FindFeeder(feeders, c.pos, need, C.FeedRadius)
            if f then
                f.feed = f.feed - need
                c.fed = true
            else
                c.fed = false
            end

            local old = c.age >= C.PrimeEnd
            if c.female and c.fed then
                local rate = C.MilkPerHour * FARM.GradeMult(c.grade) * (old and C.OldMilkMult or 1)
                c.udder = math.min(FARM.UdderCap(c.grade), c.udder + rate * dt / FARM.HOUR)
            end

            if c.pregnant then
                c.preg = c.preg + dt / C.Gestation
            else
                c.cooldown = math.max(0, c.cooldown - dt)
            end
        end
    end

    -- 번식: 전성기 암컷 근처에 전성기 수컷이 있고 둘 다 배부르면 함께 지낸 시간이 쌓인다.
    local count = CountCattle(farm)
    for _, c in ipairs(cattle) do
        if c.female and not c.pregnant and c.growth >= 1 and c.age < C.PrimeEnd and c.age < C.Lifespan
            and c.cooldown <= 0 and c.fed and c.map == map then
            local sire
            for _, m in ipairs(cattle) do
                if not m.female and m.growth >= 1 and m.age < C.PrimeEnd and m.fed and m.map == map
                    and Dist2(m.pos, c.pos) <= C.MateRadius * C.MateRadius then
                    sire = m
                    break
                end
            end
            if sire and count < FARM.MaxCattle() then
                c.mate = c.mate + dt / C.MateTime
                if c.mate >= 1 then
                    c.mate = 0
                    c.pregnant = true
                    c.preg = 0
                    c.sireGrade = sire.grade
                    count = count + 1
                    events[#events + 1] = { t = "pregnant", name = FARM.CowName(c) }
                end
            end
        end
    end

    -- 출산
    for _, c in ipairs(cattle) do
        if c.pregnant and c.preg >= 1 and c.age < C.Lifespan then
            c.pregnant = false
            c.preg = 0
            c.cooldown = C.BirthCooldown

            local calf = FARM.NewCow(math.random() < 0.5, FARM.RollChildGrade(c.grade, c.sireGrade))
            calf.milkStock = C.NewbornMilk * C.CalfMilkHours * FARM.HOUR
            calf.fed = true
            calf.map = c.map
            local ang = math.Rand(0, math.pi * 2)
            calf.pos = { c.pos[1] + math.cos(ang) * 60, c.pos[2] + math.sin(ang) * 60, c.pos[3] }
            calf.home = table.Copy(c.home or c.pos)
            calf.yaw = math.Rand(0, 360)
            FARM.NewObject(farm, calf)
            events[#events + 1] = { t = "born", name = FARM.CowName(calf), mother = FARM.CowName(c),
                female = calf.female, grade = calf.grade, obj = calf }
        end
    end

    -- 수명이 다한 소는 고기가 되어 보관함으로 간다.
    for _, c in ipairs(dead) do
        local beef = C.OldBeef
        farm.inv.beef[c.grade] = (farm.inv.beef[c.grade] or 0) + beef
        events[#events + 1] = { t = "died", name = FARM.CowName(c), grade = c.grade, beef = beef }
        FARM.DeleteObject(farm, c.id)
    end

    for _, f in ipairs(feeders) do
        if hadFeed[f] and f.feed < C.FeedPerHour * dt / FARM.HOUR then
            f.feed = 0
            events[#events + 1] = { t = "feeder_empty" }
        end
    end
end

-- 농장 시간 total 초만큼 진행한다.
function FARM.Simulate(farm, total, events)
    events = events or {}
    -- 아주 오래 비웠다면 계산 횟수를 제한한다.
    local step = math.max(MAX_STEP, total / 20000)
    while total > 0 do
        local dt = math.min(step, total)
        Step(farm, dt, events)
        total = total - dt
    end
    return events
end

-- 실제 시간 기준으로 마지막 계산 이후를 진행한다.
function FARM.Advance(farm)
    local now = os.time()
    local real = now - farm.lastSim
    farm.lastSim = now
    if real <= 0 then return {} end
    return FARM.Simulate(farm, real * FARM.TimeScale())
end
