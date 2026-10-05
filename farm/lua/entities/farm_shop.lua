-- 농장 상점 (관리자가 스폰 메뉴에서 설치, 위치는 맵별로 저장)

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "농장 상점"
ENT.Category = "농장"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.IsFarmEntity = true
ENT.AutomaticFrameAdvance = true

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "FarmOwner")
end

if SERVER then
    function ENT:SpawnFunction(ply, tr, class)
        if not tr.Hit then return end
        local ent = ents.Create(class)
        ent:SetPos(tr.HitPos)
        ent:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
        ent:Spawn()
        return ent
    end

    function ENT:Initialize()
        self:SetModel(FARM.Config.Models.Shop)
        self:PhysicsInitBox(Vector(-16, -16, 0), Vector(16, 16, 72))
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(false) end
        local seq = self:LookupSequence("idle_all_01")
        if seq and seq >= 0 then self:ResetSequence(seq) end
        if not FARM.LoadingShops then timer.Simple(0, FARM.SaveShops) end
    end

    function ENT:OnPlaced()
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(false) end
        self:SetAngles(Angle(0, self:GetAngles().y, 0))
        FARM.SaveShops()
    end

    function ENT:Think()
        self:NextThink(CurTime())
        return true
    end

    function ENT:Use(ply)
        if IsValid(ply) and ply:IsPlayer() then FARM.OpenShopMenu(ply, self) end
    end

    function ENT:OnRemove()
        self.FarmRemoving = true
        timer.Simple(0, FARM.SaveShops)
    end
else
    function ENT:Draw()
        self:DrawModel()
    end
end
