-- 농장 클라이언트: 알림, 인벤토리 동기화, 바라보는 동물 정보 표시

FARM.Local = FARM.Local or { coins = 0, inv = { feed = 0, milk = 0, feeder = 0, beef = { 0, 0, 0, 0, 0 } } }

surface.CreateFont("FarmTitle", { font = "Malgun Gothic", size = 22, weight = 800, extended = true })
surface.CreateFont("FarmText", { font = "Malgun Gothic", size = 17, weight = 500, extended = true })
surface.CreateFont("FarmSmall", { font = "Malgun Gothic", size = 15, weight = 500, extended = true })

FARM.Colors = {
    accent = Color(120, 200, 90),
    bg = Color(25, 28, 24, 230),
    panel = Color(45, 50, 43, 240),
    text = Color(235, 235, 225),
    dim = Color(170, 175, 160),
    bad = Color(230, 110, 90),
    milk = Color(225, 235, 245),
    grow = Color(150, 210, 110),
    feed = Color(215, 175, 90),
    preg = Color(240, 150, 190),
}

net.Receive("farm_notify", function()
    chat.AddText(FARM.Colors.accent, "[농장] ", FARM.Colors.text, net.ReadString())
end)

net.Receive("farm_sync", function()
    FARM.Local.coins = net.ReadUInt(32)
    FARM.Local.inv = net.ReadTable()
    hook.Run("FarmInventoryChanged")
end)

local function Bar(x, y, w, h, frac, col, label)
    draw.RoundedBox(4, x, y, w, h, Color(0, 0, 0, 150))
    draw.RoundedBox(4, x, y, math.max(0, w * math.Clamp(frac, 0, 1)), h, col)
    draw.SimpleText(label, "FarmSmall", x + w / 2, y + h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- 소 정보 줄 만들기 (메뉴에서도 쓴다)
function FARM.CowInfo(ent)
    local C = FARM.Config.Cow
    local growth, age = ent:GetGrowth(), ent:GetAge()
    local stage = FARM.CowStage(growth, age)
    local info = {
        title = ent:GetCowName(),
        sub = string.format("%s · %s · %s등급 · 나이 %s", ent:GetFemale() and "암컷" or "수컷",
            FARM.StageNames[stage], FARM.GradeName(ent:GetGrade()), FARM.FormatTime(age)),
        bars = {},
        notes = {},
    }

    if stage == "calf" then
        info.bars[#info.bars + 1] = { frac = growth, col = FARM.Colors.grow,
            label = string.format("성장 %d%%", math.floor(growth * 100)) }
        local hours = ent:GetMilkStock() / FARM.HOUR
        info.bars[#info.bars + 1] = { frac = hours / (C.CalfMilkMax * C.CalfMilkHours), col = FARM.Colors.milk,
            label = string.format("먹은 우유 %.1f시간분", hours) }
        if hours <= 0 then info.notes[#info.notes + 1] = { "배고파요 - 우유를 먹이세요", FARM.Colors.bad } end
    else
        if ent:GetFemale() then
            local cap = FARM.UdderCap(ent:GetGrade())
            info.bars[#info.bars + 1] = { frac = ent:GetUdder() / cap, col = FARM.Colors.milk,
                label = string.format("젖 %.1f / %.1f", ent:GetUdder(), cap) }
        end
        if ent:GetPregnant() then
            info.bars[#info.bars + 1] = { frac = ent:GetPregProgress(), col = FARM.Colors.preg,
                label = string.format("임신 %d%%", math.floor(ent:GetPregProgress() * 100)) }
        end
        if not ent:GetFed() then info.notes[#info.notes + 1] = { "배고파요 - 근처 사료통에 사료가 필요해요", FARM.Colors.bad } end
        if stage == "old" then
            info.notes[#info.notes + 1] = { string.format("노년 - 생산량 감소, 남은 수명 %s",
                FARM.FormatTime(C.Lifespan - age)), FARM.Colors.dim }
        end
    end
    return info
end

local function DrawPanel(x, y, info)
    local w = 300
    local h = 52 + #info.bars * 24 + #info.notes * 20
    x = x - w / 2
    draw.RoundedBox(8, x, y, w, h, FARM.Colors.bg)
    draw.SimpleText(info.title, "FarmTitle", x + 12, y + 8, FARM.Colors.accent)
    draw.SimpleText(info.sub, "FarmSmall", x + 12, y + 32, FARM.Colors.dim)
    local cy = y + 52
    for _, b in ipairs(info.bars) do
        Bar(x + 12, cy, w - 24, 18, b.frac, b.col, b.label)
        cy = cy + 24
    end
    for _, n in ipairs(info.notes) do
        draw.SimpleText(n[1], "FarmSmall", x + 12, cy, n[2])
        cy = cy + 20
    end
end

hook.Add("HUDPaint", "farm_lookat", function()
    local ply = LocalPlayer()
    local ent = ply:GetEyeTrace().Entity
    if not FARM.IsFarmEntity(ent) or ply:GetPos():DistToSqr(ent:GetPos()) > 300 * 300 then return end

    local x, y = ScrW() / 2, ScrH() / 2 + 40
    local class = ent:GetClass()
    if class == "farm_cow" then
        DrawPanel(x, y, FARM.CowInfo(ent))
        if ent:GetFarmOwner() == ply then
            draw.SimpleText("E: 메뉴", "FarmSmall", x, y - 18, FARM.Colors.text, TEXT_ALIGN_CENTER)
        end
    elseif class == "farm_feeder" then
        local cap = FARM.Config.Feeder.Capacity
        DrawPanel(x, y, {
            title = "사료통",
            sub = ent:GetFarmOwner() == ply and "E: 사료 채우기 · Alt+E: 회수" or "",
            bars = { { frac = ent:GetFeed() / cap, col = FARM.Colors.feed,
                label = string.format("사료 %d / %d", math.floor(ent:GetFeed()), cap) } },
            notes = {},
        })
    elseif class == "farm_beef" then
        draw.SimpleText(string.format("소고기 %s등급 (E: 줍기)", FARM.GradeName(ent:GetGrade())), "FarmText",
            x, y, FARM.Colors.text, TEXT_ALIGN_CENTER)
    elseif class == "farm_shop" then
        draw.SimpleText("농장 상점 (E)", "FarmTitle", x, y, FARM.Colors.accent, TEXT_ALIGN_CENTER)
    end
end)
