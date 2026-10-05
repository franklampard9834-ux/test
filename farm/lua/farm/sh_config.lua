-- 농장 설정값
-- 시간은 모두 "농장 시간" 초 단위다. farm_timescale 로 실제 시간 대비 배속을 바꿀 수 있다.

local HOUR = 3600
local DAY = 24 * HOUR

FARM.Config = {
    StartCoins = 1500,

    -- 품질 등급: 실제 한우 육질등급. 번호가 작을수록 좋은 등급.
    -- bonus: 생산량 보너스, base: 번식 시 기본 확률, beef: 소고기 판매가
    Grades = {
        { name = "1++", bonus = 0.40, base = 0.005, beef = 1800 },
        { name = "1+",  bonus = 0.25, base = 0.020, beef = 1000 },
        { name = "1",   bonus = 0.10, base = 0.075, beef = 650 },
        { name = "2",   bonus = 0.00, base = 0.250, beef = 400 },
        { name = "3",   bonus = 0.00, base = 0.650, beef = 250 },
    },
    ShopGrade = 5,          -- 상점에서 파는 동물은 항상 3등급
    ParentInfluence = 0.15, -- 새끼 등급에 부모 등급이 섞이는 비율

    Cow = {
        GrowTime = 8 * HOUR,        -- 송아지 → 성체 (먹이가 있을 때만 자람)
        PrimeEnd = 5 * DAY,         -- 이 나이부터 노년
        Lifespan = 7 * DAY,         -- 수명

        MilkPerHour = 1,            -- 성체 암소 시간당 우유
        UdderHours = 4,             -- 이 시간만큼 차면 가득 참
        OldMilkMult = 0.5,          -- 노년 생산량 배수

        FeedPerHour = 1,            -- 성체 시간당 사료 소비량
        FeedRadius = 400,           -- 사료통에서 먹을 수 있는 거리

        CalfMilkHours = 2,          -- 송아지에게 우유 1개 = 2시간 분량
        CalfMilkMax = 4,            -- 송아지가 미리 먹어둘 수 있는 우유 개수
        NewbornMilk = 1,            -- 갓 태어난 송아지가 어미에게 받은 우유 개수

        MateRadius = 400,           -- 암수가 이 거리 안에 있어야 번식
        MateTime = 1 * HOUR,        -- 함께 지내야 임신하는 시간
        Gestation = 4 * HOUR,       -- 임신 기간
        BirthCooldown = 2 * HOUR,   -- 출산 후 쉬는 시간

        PrimeBeef = 2,              -- 전성기 출하 시 소고기 개수
        OldBeef = 1,                -- 노년 출하/자연사 시 소고기 개수

        CalfScale = 0.45,
        WanderRadius = 250,
        WalkSpeed = 28,
    },

    Feeder = { Capacity = 120 },

    Models = {
        Cow = "models/tsbb/animals/cow.mdl",
        Bull = "models/tsbb/animals/bull.mdl",
        FeederEmpty = "models/farm/feeder_empty.mdl",
        FeederFull = "models/farm/feeder_full.mdl",
        Beef = "models/farm/beef.mdl",
        Shop = "models/player/group01/male_07.mdl",
    },

    -- 소 모델 충돌 상자 (크기 1.0 기준)
    Hull = {
        Cow = { Vector(-58, -18, 0), Vector(72, 18, 80) },
        Bull = { Vector(-52, -24, 0), Vector(100, 24, 88) },
    },

    -- 상점 가격
    Shop = {
        Buy = {
            calf_f = { name = "암송아지", price = 500 },
            calf_m = { name = "수송아지", price = 300 },
            feed = { name = "사료 1포대 (24)", price = 60, amount = 24 },
            milk = { name = "우유 1병", price = 30, amount = 1 },
            feeder = { name = "사료통", price = 300 },
        },
        BuyOrder = { "calf_f", "calf_m", "feed", "milk", "feeder" },
        SellMilk = 15,
    },
}

FARM.HOUR = HOUR
FARM.DAY = DAY
