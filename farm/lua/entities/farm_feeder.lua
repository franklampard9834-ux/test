-- 사료통: E로 사료 채우기, Alt+E로 회수

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "사료통"
ENT.Category = "농장"
ENT.Spawnable = false
ENT.IsFarmEntity = true

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "FarmOwner")
    self:NetworkVar("Float", 0, "Feed")
end

if SERVER then
    function ENT:Initialize()
        self:SetUseType(SIMPLE_USE)
        self:ApplyLook()
    end

    function ENT:ApplyLook()
        local model = self:GetFeed() > 0 and FARM.Config.Models.FeederFull or FARM.Config.Models.FeederEmpty
        if self:GetModel() == model then return end
        self:SetModel(model)
        -- 충돌 모델을 못 읽으면 모델 크기의 상자로 대신한다.
        if not self:PhysicsInit(SOLID_VPHYSICS) then
            self:PhysicsInitBox(self:OBBMins(), self:OBBMaxs())
        end
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(false) end
    end

    function ENT:OnPlaced()
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(false) end
        self:SetAngles(Angle(0, self:GetAngles().y, 0))
    end

    function ENT:Use(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        if self:GetFarmOwner() ~= ply then
            FARM.Notify(ply, "다른 사람의 사료통입니다.")
            return
        end
        local farm = FARM.GetFarm(ply)
        local obj = farm and farm.objects[self.FarmId]
        if not obj then return end

        FARM.PullEntityState(farm)
        FARM.HandleEvents(farm, FARM.Advance(farm))

        if ply:KeyDown(IN_WALK) then
            farm.inv.feed = farm.inv.feed + math.floor(obj.feed)
            farm.inv.feeder = farm.inv.feeder + 1
            FARM.DeleteObject(farm, obj.id)
            FARM.Notify(ply, "사료통을 회수했습니다. 안에 있던 사료도 돌려받았습니다.")
        else
            local cap = FARM.Config.Feeder.Capacity
            local give = math.min(math.floor(cap - obj.feed), farm.inv.feed)
            if give < 1 then
                FARM.Notify(ply, obj.feed >= cap - 1 and "사료통이 가득 찼습니다." or "사료가 없습니다. 상점에서 사 오세요.")
                return
            end
            farm.inv.feed = farm.inv.feed - give
            obj.feed = obj.feed + give
            FARM.Notify(ply, string.format("사료 %d을(를) 채웠습니다. (%d/%d)", give, math.floor(obj.feed), cap))
            self:EmitSound("physics/cardboard/cardboard_box_break3.wav", 60, 90)
        end

        FARM.SyncEntities(farm)
        FARM.SyncInventory(farm)
    end
else
    function ENT:Draw()
        self:DrawModel()
    end
end
