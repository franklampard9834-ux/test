-- Entity Finder (client)
-- 서버에 존재하는 엔티티 클래스를 스캔하고, 지정한 엔티티를 화면에 표시한다.
--
-- 콘솔 명령:
--   entfinder_scan              현재 맵의 엔티티 클래스별 개수 출력
--   entfinder_registered        서버에 설치(등록)된 SENT/SWEP/NPC 클래스 목록 출력
--   entfinder_add <패턴>        추적할 클래스 패턴 추가 (Lua 패턴, 예: "prop_physics", "^weapon_")
--   entfinder_remove <패턴>     추적 패턴 제거
--   entfinder_clear             모든 추적 패턴 제거
--   entfinder_list              현재 추적 패턴 출력
--   entfinder_menu              GUI 메뉴 열기
--
-- ConVar:
--   entfinder_draw 0/1          표시 켜기/끄기
--   entfinder_maxdist <유닛>    표시 최대 거리 (기본 5000)
--   entfinder_halo 0/1          외곽선(halo) 표시

local drawCvar   = CreateClientConVar("entfinder_draw", "1", true, false)
local distCvar   = CreateClientConVar("entfinder_maxdist", "5000", true, false)
local haloCvar   = CreateClientConVar("entfinder_halo", "1", true, false)

local patterns = {}       -- [pattern] = Color
local tracked  = {}       -- 매 틱 갱신되는 { ent, color } 목록
local palette = {
    Color(255, 80, 80), Color(80, 200, 255), Color(120, 255, 120),
    Color(255, 220, 60), Color(220, 120, 255), Color(255, 150, 60),
}

local function HasAccess()
    local mode = GetConVar("entfinder_access")
    mode = mode and mode:GetInt() or 0
    if game.SinglePlayer() then return true end
    if mode == 2 then return true end
    if mode == 1 then
        local ply = LocalPlayer()
        return IsValid(ply) and ply:IsAdmin()
    end
    return false
end

local function Deny()
    MsgC(Color(255, 80, 80), "[EntFinder] 권한이 없습니다 (entfinder_access 확인).\n")
end

local function Print(...)
    MsgC(Color(80, 200, 255), "[EntFinder] ", color_white, string.format(...), "\n")
end

local function MatchColor(class)
    for pat, col in pairs(patterns) do
        if string.find(class, pat) then return col end
    end
end

-- 현재 맵에 있는 엔티티를 클래스별로 집계
local function ScanWorld()
    local counts = {}
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) then
            local c = ent:GetClass()
            counts[c] = (counts[c] or 0) + 1
        end
    end
    local sorted = {}
    for c, n in pairs(counts) do sorted[#sorted + 1] = { class = c, count = n } end
    table.sort(sorted, function(a, b) return a.count > b.count end)
    return sorted
end

-- 서버/애드온에 등록된(설치된) 엔티티 정의 목록
local function ScanRegistered()
    local out = { SENT = {}, SWEP = {}, NPC = {} }
    for class in pairs(scripted_ents.GetList()) do out.SENT[#out.SENT + 1] = class end
    for _, w in ipairs(weapons.GetList()) do out.SWEP[#out.SWEP + 1] = w.ClassName end
    for class in pairs(list.Get("NPC")) do out.NPC[#out.NPC + 1] = class end
    for _, t in pairs(out) do table.sort(t) end
    return out
end

local function AddPattern(pat)
    if not pat or pat == "" then return end
    if not pcall(string.find, "", pat) then
        Print("잘못된 패턴: %s", pat)
        return
    end
    local n = table.Count(patterns)
    patterns[pat] = palette[(n % #palette) + 1]
    Print("추적 추가: %s", pat)
end

-- 추적 대상 갱신 (매 프레임 전체 순회를 피하려고 0.25초마다)
timer.Create("EntFinder_Refresh", 0.25, 0, function()
    tracked = {}
    if not drawCvar:GetBool() or next(patterns) == nil or not HasAccess() then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local maxDistSqr = distCvar:GetFloat() ^ 2
    local eye = ply:EyePos()
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and ent ~= ply then
            local col = MatchColor(ent:GetClass())
            if col and eye:DistToSqr(ent:GetPos()) <= maxDistSqr then
                tracked[#tracked + 1] = { ent = ent, color = col }
            end
        end
    end
end)

hook.Add("PreDrawHalos", "EntFinder_Halo", function()
    if not haloCvar:GetBool() or #tracked == 0 then return end
    local byColor = {}
    for _, t in ipairs(tracked) do
        if IsValid(t.ent) then
            byColor[t.color] = byColor[t.color] or {}
            table.insert(byColor[t.color], t.ent)
        end
    end
    for col, list in pairs(byColor) do
        halo.Add(list, col, 2, 2, 1, true, true)
    end
end)

hook.Add("HUDPaint", "EntFinder_Labels", function()
    if #tracked == 0 then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local eye = ply:EyePos()
    for _, t in ipairs(tracked) do
        local ent = t.ent
        if IsValid(ent) then
            local pos = ent:WorldSpaceCenter():ToScreen()
            if pos.visible then
                local dist = math.floor(eye:Distance(ent:GetPos()) * 0.01905) -- 유닛 -> 미터
                draw.SimpleTextOutlined(ent:GetClass(), "DermaDefaultBold", pos.x, pos.y,
                    t.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, color_black)
                draw.SimpleTextOutlined(dist .. "m", "DermaDefault", pos.x, pos.y,
                    color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, color_black)
            end
        end
    end
end)

-- 콘솔 명령
local function Guard(fn)
    return function(ply, cmd, args, argStr)
        if not HasAccess() then return Deny() end
        fn(args, argStr)
    end
end

concommand.Add("entfinder_scan", Guard(function()
    local list = ScanWorld()
    Print("맵 엔티티 클래스 %d종:", #list)
    for _, e in ipairs(list) do Print("  %-40s x%d", e.class, e.count) end
end))

concommand.Add("entfinder_registered", Guard(function()
    for kind, list in SortedPairs(ScanRegistered()) do
        Print("%s (%d):", kind, #list)
        for _, c in ipairs(list) do Print("  %s", c) end
    end
end))

concommand.Add("entfinder_add", Guard(function(_, argStr) AddPattern(string.Trim(argStr)) end))
concommand.Add("entfinder_remove", Guard(function(_, argStr)
    patterns[string.Trim(argStr)] = nil
    Print("추적 제거: %s", argStr)
end))
concommand.Add("entfinder_clear", Guard(function() patterns = {} Print("추적 목록 초기화") end))
concommand.Add("entfinder_list", Guard(function()
    for pat in SortedPairs(patterns) do Print("  %s", pat) end
end))

-- GUI
concommand.Add("entfinder_menu", Guard(function()
    local frame = vgui.Create("DFrame")
    frame:SetTitle("Entity Finder")
    frame:SetSize(520, 480)
    frame:Center()
    frame:MakePopup()

    local search = vgui.Create("DTextEntry", frame)
    search:Dock(TOP)
    search:SetPlaceholderText("클래스 이름 필터...")

    local listView = vgui.Create("DListView", frame)
    listView:Dock(FILL)
    listView:DockMargin(0, 4, 0, 4)
    listView:AddColumn("클래스")
    listView:AddColumn("출처"):SetFixedWidth(70)
    listView:AddColumn("맵 개수"):SetFixedWidth(70)
    listView:AddColumn("추적"):SetFixedWidth(50)

    local function Populate()
        listView:Clear()
        local filter = string.lower(search:GetValue() or "")
        local rows = {}
        for _, e in ipairs(ScanWorld()) do
            rows[e.class] = { src = "맵", count = e.count }
        end
        for kind, list in pairs(ScanRegistered()) do
            for _, c in ipairs(list) do
                rows[c] = rows[c] or { src = kind, count = 0 }
            end
        end
        for class, r in SortedPairs(rows) do
            if filter == "" or string.find(string.lower(class), filter, 1, true) then
                local exact = "^" .. string.PatternSafe(class) .. "$"
                local line = listView:AddLine(class, r.src, r.count, patterns[exact] and "O" or "")
                line.Pattern = exact
            end
        end
    end
    search.OnChange = Populate

    listView.DoDoubleClick = function(_, _, line)
        if patterns[line.Pattern] then
            patterns[line.Pattern] = nil
        else
            AddPattern(line.Pattern)
        end
        line:SetColumnText(4, patterns[line.Pattern] and "O" or "")
    end

    local bottom = vgui.Create("DPanel", frame)
    bottom:Dock(BOTTOM)
    bottom:SetTall(24)
    bottom:SetPaintBackground(false)

    local refresh = vgui.Create("DButton", bottom)
    refresh:Dock(LEFT)
    refresh:SetWide(120)
    refresh:SetText("다시 스캔")
    refresh.DoClick = Populate

    local clear = vgui.Create("DButton", bottom)
    clear:Dock(RIGHT)
    clear:SetWide(120)
    clear:SetText("추적 모두 해제")
    clear.DoClick = function() patterns = {} Populate() end

    local hint = vgui.Create("DLabel", bottom)
    hint:Dock(FILL)
    hint:SetContentAlignment(5)
    hint:SetText("더블클릭: 추적 켜기/끄기")

    Populate()
end))
