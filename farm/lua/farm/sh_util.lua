-- 농장 공용 함수

CreateConVar("farm_timescale", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
    "농장 시간 배속 (테스트용, 60이면 실제 1분 = 농장 1시간)", 0.01, 10000)
CreateConVar("farm_max_cattle", "10", { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
    "플레이어당 소 최대 마릿수 (임신 중인 새끼 포함)", 1, 200)

function FARM.TimeScale()
    return GetConVar("farm_timescale"):GetFloat()
end

function FARM.MaxCattle()
    return GetConVar("farm_max_cattle"):GetInt()
end

function FARM.GradeName(g)
    local grade = FARM.Config.Grades[g]
    return grade and grade.name or "?"
end

function FARM.GradeMult(g)
    local grade = FARM.Config.Grades[g]
    return 1 + (grade and grade.bonus or 0)
end

-- 송아지 / 성체 / 노년
function FARM.CowStage(growth, age)
    if growth < 1 then return "calf" end
    if age >= FARM.Config.Cow.PrimeEnd then return "old" end
    return "adult"
end

FARM.StageNames = { calf = "송아지", adult = "성체", old = "노년" }

function FARM.UdderCap(grade)
    local c = FARM.Config.Cow
    return c.MilkPerHour * c.UdderHours * FARM.GradeMult(grade)
end

function FARM.FormatTime(sec)
    sec = math.max(0, math.floor(sec))
    local d = math.floor(sec / FARM.DAY)
    local h = math.floor(sec % FARM.DAY / FARM.HOUR)
    local m = math.floor(sec % FARM.HOUR / 60)
    if d > 0 then return string.format("%d일 %d시간", d, h) end
    if h > 0 then return string.format("%d시간 %d분", h, m) end
    return string.format("%d분", m)
end

-- 새끼 등급 확률: 기본 확률과 부모 영향 분포를 섞는다.
-- 부모 영향 분포는 부모 평균 등급 70%, 한 단계 위 10%, 한 단계 아래 20%.
function FARM.ChildGradeWeights(a, b)
    local grades = FARM.Config.Grades
    local n = #grades
    local avg = math.Clamp(math.floor((a + b) / 2 + 0.5), 1, n)

    local parent = {}
    for i = 1, n do parent[i] = 0 end
    parent[avg] = 0.7
    if avg > 1 then parent[avg - 1] = 0.1 else parent[avg] = parent[avg] + 0.1 end
    if avg < n then parent[avg + 1] = 0.2 else parent[avg] = parent[avg] + 0.2 end

    local k = FARM.Config.ParentInfluence
    local w = {}
    for i = 1, n do
        w[i] = grades[i].base * (1 - k) + parent[i] * k
    end
    return w
end

function FARM.RollChildGrade(a, b)
    local w = FARM.ChildGradeWeights(a, b)
    local total = 0
    for _, v in ipairs(w) do total = total + v end
    local r = math.Rand(0, total)
    for i, v in ipairs(w) do
        r = r - v
        if r <= 0 then return i end
    end
    return #w
end

function FARM.IsFarmEntity(ent)
    return IsValid(ent) and ent.IsFarmEntity == true
end
