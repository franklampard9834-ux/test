-- 소고기: 출하하면 나오고, 주인이 E로 주워 보관함에 넣는다.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "소고기"
ENT.Category = "농장"
ENT.Spawnable = false
ENT.IsFarmEntity = true

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "FarmOwner")
    self:NetworkVar("Int", 0, "Grade")
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(FARM.Config.Models.Beef)
        if not self:PhysicsInit(SOLID_VPHYSICS) then
            self:PhysicsInitBox(self:OBBMins(), self:OBBMaxs())
        end
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
    end

    function ENT:Use(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        if self.FarmSid ~= ply:SteamID64() then
            FARM.Notify(ply, "다른 사람의 소고기입니다.")
            return
        end
        local farm = FARM.GetFarm(ply)
        if not farm or self.Collected then return end
        self.Collected = true
        local g = self:GetGrade()
        farm.inv.beef[g] = (farm.inv.beef[g] or 0) + 1
        FARM.SyncInventory(farm)
        FARM.Notify(ply, string.format("소고기(%s등급)를 주웠습니다.", FARM.GradeName(g)))
        self:EmitSound("physics/flesh/flesh_impact_bullet1.wav", 60, 100)
        self:Remove()
    end
else
    function ENT:Draw()
        self:DrawModel()
    end
end
