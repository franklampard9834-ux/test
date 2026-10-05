-- 농장 메뉴: 소 메뉴, 상점, 농장 메뉴(!farm)

local C = FARM.Colors

local function Frame(title, w, h)
    local f = vgui.Create("DFrame")
    f:SetTitle("")
    f:SetSize(w, h)
    f:Center()
    f:MakePopup()
    f.Paint = function(s, pw, ph)
        draw.RoundedBox(8, 0, 0, pw, ph, C.bg)
        draw.SimpleText(title, "FarmTitle", 12, 6, C.accent)
    end
    return f
end

local function Button(parent, text, onClick)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b:SetTall(32)
    b.Label = text
    b.Paint = function(s, w, h)
        local col = s:GetDisabled() and Color(60, 60, 60) or (s:IsHovered() and C.accent or C.panel)
        draw.RoundedBox(6, 0, 0, w, h, col)
        draw.SimpleText(s.Label, "FarmText", w / 2, h / 2, s:GetDisabled() and C.dim or C.text,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.DoClick = onClick
    return b
end

local function Label(parent, text, font, col)
    local l = vgui.Create("DLabel", parent)
    l:SetFont(font or "FarmText")
    l:SetTextColor(col or C.text)
    l:SetText(text)
    l:SizeToContents()
    return l
end

local function InvText()
    local inv = FARM.Local.inv
    return string.format("코인 %d   ·   사료 %d   ·   우유 %d병", FARM.Local.coins, inv.feed or 0, inv.milk or 0)
end

-- 소 메뉴 -------------------------------------------------------------

local function CowAction(ent, action, extra)
    net.Start("farm_cow_action")
        net.WriteEntity(ent)
        net.WriteString(action)
        if extra then net.WriteString(extra) end
    net.SendToServer()
end

net.Receive("farm_cow_menu", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end
    if IsValid(FARM.CowFrame) then FARM.CowFrame:Remove() end

    local f = Frame("소 관리", 340, 330)
    FARM.CowFrame = f

    local info = vgui.Create("DPanel", f)
    info:SetPos(10, 36)
    info:SetSize(320, 140)
    info.Paint = function(s, w, h)
        if not IsValid(ent) then f:Remove() return end
        local i = FARM.CowInfo(ent)
        draw.SimpleText(i.title, "FarmTitle", 4, 0, C.text)
        draw.SimpleText(i.sub, "FarmSmall", 4, 26, C.dim)
        local y = 48
        for _, b in ipairs(i.bars) do
            draw.RoundedBox(4, 4, y, w - 8, 18, Color(0, 0, 0, 150))
            draw.RoundedBox(4, 4, y, (w - 8) * math.Clamp(b.frac, 0, 1), 18, b.col)
            draw.SimpleText(b.label, "FarmSmall", w / 2, y + 9, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            y = y + 24
        end
        for _, n in ipairs(i.notes) do
            draw.SimpleText(n[1], "FarmSmall", 4, y, n[2])
            y = y + 20
        end
    end

    local inv = Label(f, InvText(), "FarmSmall", C.dim)
    inv:SetPos(14, 180)
    inv.Think = function(s) s:SetText(InvText()) s:SizeToContents() end

    local adult = ent:GetGrowth() >= 1
    local y = 204
    local function Row(text, fn, enabled)
        local b = Button(f, text, fn)
        b:SetPos(10, y)
        b:SetWide(320)
        b:SetDisabled(not enabled)
        y = y + 38
        return b
    end

    if adult then
        Row("착유하기", function() CowAction(ent, "milk") end, ent:GetFemale())
        Row("출하하기 (소고기로 바꾸기)", function()
            local stage = FARM.CowStage(ent:GetGrowth(), ent:GetAge())
            local n = stage == "old" and FARM.Config.Cow.OldBeef or FARM.Config.Cow.PrimeBeef
            Derma_Query(string.format("%s을(를) 출하할까요? 소고기 %d개(%s등급)가 나옵니다.",
                ent:GetCowName(), n, FARM.GradeName(ent:GetGrade())), "출하",
                "출하", function() CowAction(ent, "ship") f:Remove() end, "취소")
        end, true)
    else
        Row("우유 먹이기", function() CowAction(ent, "feed") end, true)
    end
    Row("이름 바꾸기", function()
        Derma_StringRequest("이름 바꾸기", "새 이름 (20자 이내)", ent:GetCowName(), function(text)
            CowAction(ent, "rename", text)
        end)
    end, true)
    f:SetTall(y + 6)
end)

-- 상점 ----------------------------------------------------------------

local function ShopBuy(shop, item, amount)
    net.Start("farm_shop_buy")
        net.WriteEntity(shop)
        net.WriteString(item)
        net.WriteUInt(amount or 1, 8)
    net.SendToServer()
end

local function ShopSell(shop, item, grade, all)
    net.Start("farm_shop_sell")
        net.WriteEntity(shop)
        net.WriteString(item)
        net.WriteUInt(grade or 0, 4)
        net.WriteBool(all)
    net.SendToServer()
end

local function ShopRow(parent, title, sub, buttons)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 6)
    row:SetTall(48)
    row.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, C.panel)
        draw.SimpleText(title, "FarmText", 10, 6, C.text)
        draw.SimpleText(isfunction(sub) and sub() or sub, "FarmSmall", 10, 26, C.dim)
    end
    for i = #buttons, 1, -1 do
        local b = Button(row, buttons[i][1], buttons[i][2])
        b:Dock(RIGHT)
        b:DockMargin(4, 8, i == #buttons and 8 or 0, 8)
        b:SetWide(70)
    end
    return row
end

net.Receive("farm_shop_menu", function()
    local shop = net.ReadEntity()
    if not IsValid(shop) then return end
    if IsValid(FARM.ShopFrame) then FARM.ShopFrame:Remove() end

    local f = Frame("농장 상점", 480, 470)
    FARM.ShopFrame = f

    local top = Label(f, InvText(), "FarmText", C.accent)
    top:SetPos(12, 34)
    top.Think = function(s) s:SetText(InvText()) s:SizeToContents() end

    local sheet = vgui.Create("DPropertySheet", f)
    sheet:SetPos(10, 62)
    sheet:SetSize(460, 398)

    local buy = vgui.Create("DScrollPanel", sheet)
    local S = FARM.Config.Shop
    for _, key in ipairs(S.BuyOrder) do
        local def = S.Buy[key]
        local sub = string.format("%d코인", def.price)
        if key == "calf_f" or key == "calf_m" then sub = sub .. " · 3등급" end
        local buttons = { { "사기", function() ShopBuy(shop, key, 1) end } }
        if key == "feed" or key == "milk" then
            buttons[#buttons + 1] = { "x10", function() ShopBuy(shop, key, 10) end }
        end
        ShopRow(buy, def.name, sub, buttons)
    end
    sheet:AddSheet("구매", buy)

    local sell = vgui.Create("DScrollPanel", sheet)
    ShopRow(sell, "우유", function()
        return string.format("보유 %d병 · 개당 %d코인", FARM.Local.inv.milk or 0, S.SellMilk)
    end, {
        { "1개", function() ShopSell(shop, "milk", 0, false) end },
        { "전부", function() ShopSell(shop, "milk", 0, true) end },
    })
    for g, grade in ipairs(FARM.Config.Grades) do
        ShopRow(sell, string.format("소고기 %s등급", grade.name), function()
            return string.format("보유 %d개 · 개당 %d코인", FARM.Local.inv.beef[g] or 0, grade.beef)
        end, {
            { "1개", function() ShopSell(shop, "beef", g, false) end },
            { "전부", function() ShopSell(shop, "beef", g, true) end },
        })
    end
    sheet:AddSheet("판매", sell)
end)

-- 농장 메뉴 (!farm) ---------------------------------------------------

concommand.Add("farm_menu", function()
    net.Start("farm_main_request")
    net.SendToServer()
end)

local function MainAction(action, id)
    net.Start("farm_main_action")
        net.WriteString(action)
        net.WriteUInt(id or 0, 32)
    net.SendToServer()
end

net.Receive("farm_main_data", function()
    local list = net.ReadTable()
    local x, y
    if IsValid(FARM.MainFrame) then
        x, y = FARM.MainFrame:GetPos()
        FARM.MainFrame:Remove()
    end
    local f = Frame("내 농장", 620, 480)
    if x then f:SetPos(x, y) end
    FARM.MainFrame = f

    local top = Label(f, InvText(), "FarmText", C.accent)
    top:SetPos(12, 34)
    top.Think = function(s) s:SetText(InvText()) s:SizeToContents() end

    local beef = {}
    for g, grade in ipairs(FARM.Config.Grades) do
        local n = FARM.Local.inv.beef[g] or 0
        if n > 0 then beef[#beef + 1] = string.format("%s등급 %d", grade.name, n) end
    end
    local beefLabel = Label(f, "소고기: " .. (#beef > 0 and table.concat(beef, ", ") or "없음"), "FarmSmall", C.dim)
    beefLabel:SetPos(12, 58)

    local place = Button(f, string.format("사료통 설치 (보유 %d)", FARM.Local.inv.feeder or 0), function()
        MainAction("place_feeder", 0)
    end)
    place:SetPos(420, 34)
    place:SetSize(190, 32)
    place:SetDisabled((FARM.Local.inv.feeder or 0) < 1)

    local lv = vgui.Create("DListView", f)
    lv:SetPos(10, 80)
    lv:SetSize(600, 350)
    lv:SetMultiSelect(false)
    lv:AddColumn("이름")
    lv:AddColumn("성별"):SetFixedWidth(50)
    lv:AddColumn("등급"):SetFixedWidth(50)
    lv:AddColumn("상태")
    lv:AddColumn("위치")

    table.sort(list, function(a, b) return a.id < b.id end)
    for _, o in ipairs(list) do
        local where = o.here and "이 맵" or ("보관함 (" .. tostring(o.map) .. ")")
        local line
        if o.kind == "cow" then
            local state = FARM.StageNames[o.stage] .. " · " .. FARM.FormatTime(o.age)
            if o.pregnant then state = state .. " · 임신" end
            if not o.fed then state = state .. " · 배고픔" end
            line = lv:AddLine(o.name, o.female and "암" or "수", FARM.GradeName(o.grade), state, where)
        else
            line = lv:AddLine("사료통", "", "", string.format("사료 %d", math.floor(o.feed)), where)
        end
        line.FarmObj = o
    end

    local retrieve = Button(f, "선택한 것을 여기로 꺼내기", function()
        local _, line = lv:GetSelectedLine()
        if line and line.FarmObj and not line.FarmObj.here then
            MainAction("retrieve", line.FarmObj.id)
        end
    end)
    retrieve:SetPos(10, 438)
    retrieve:SetSize(600, 32)
end)
