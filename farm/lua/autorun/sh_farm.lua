-- 농장 애드온 로더
-- 공용 설정/유틸을 먼저 읽고, 서버/클라이언트 파일을 나눠 불러온다.

FARM = FARM or {}

local shared = { "farm/sh_config.lua", "farm/sh_util.lua" }
local server = { "farm/sv_data.lua", "farm/sv_sim.lua", "farm/sv_core.lua", "farm/sv_net.lua" }
local client = { "farm/cl_hud.lua", "farm/cl_menus.lua" }

for _, f in ipairs(shared) do
    if SERVER then AddCSLuaFile(f) end
    include(f)
end

if SERVER then
    for _, f in ipairs(client) do AddCSLuaFile(f) end
    for _, f in ipairs(server) do include(f) end
else
    for _, f in ipairs(client) do include(f) end
end
