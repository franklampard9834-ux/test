-- Entity Finder (shared)
-- 사용 권한 ConVar는 서버/클라이언트 양쪽에 있어야 복제(replicate)된다.

if SERVER then AddCSLuaFile() end

-- 0 = 비활성, 1 = 관리자만, 2 = 모두 허용
CreateConVar("entfinder_access", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
    "Entity Finder 사용 권한: 0=꺼짐, 1=관리자만, 2=모두", 0, 2)
