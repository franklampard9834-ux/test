-- 소 (암소/수소/송아지)
-- 상태는 서버 농장 데이터가 원본이고, 이 엔티티는 보여주기와 돌아다니기만 맡는다.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "소"
ENT.Category = "농장"
ENT.Spawnable = false
ENT.IsFarmEntity = true
ENT.AutomaticFrameAdvance = true

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "FarmOwner")
    self:NetworkVar("Int", 0, "Grade")
    self:NetworkVar("Bool", 0, "Female")
    self:NetworkVar("Bool", 1, "Fed")
    self:NetworkVar("Bool", 2, "Pregnant")
    self:NetworkVar("Bool", 3, "Walking")
    self:NetworkVar("Bool", 4, "Eating")
    self:NetworkVar("Float", 0, "Growth")
    self:NetworkVar("Float", 1, "Udder")
    self:NetworkVar("Float", 2, "Age")
    self:NetworkVar("Float", 3, "MilkStock")
    self:NetworkVar("Float", 4, "PregProgress")
    self:NetworkVar("String", 0, "CowName")
end

function ENT:IsBullModel()
    return not self:GetFemale()
end

function ENT:TargetScale()
    local C = FARM.Config.Cow
    return Lerp(math.Clamp(self:GetGrowth(), 0, 1), C.CalfScale, 1)
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(FARM.Config.Models.Cow)
        self:SetUseType(SIMPLE_USE)
        self.FarmHome = self.FarmHome or self:GetPos()
        self.NextDecision = CurTime() + math.Rand(2, 6)
        self:ApplyLook()
    end

    -- 성별/성장에 맞게 모델, 크기, 충돌 상자를 맞춘다.
    function ENT:ApplyLook()
        local bull = self:IsBullModel()
        local model = bull and FARM.Config.Models.Bull or FARM.Config.Models.Cow
        local scale = self:TargetScale()

        if self:GetModel() ~= model then self:SetModel(model) end
        if math.abs((self.AppliedScale or 0) - scale) < 0.03 and self.AppliedBull == bull then return end
        self.AppliedScale = scale
        self.AppliedBull = bull

        self:SetModelScale(scale, 0)
        local hull = bull and FARM.Config.Hull.Bull or FARM.Config.Hull.Cow
        self.HullMins, self.HullMaxs = hull[1] * scale, hull[2] * scale
        self:PhysicsInitBox(self.HullMins, self.HullMaxs)
        self:SetCollisionBounds(self.HullMins, self.HullMaxs)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:SetMaterial("flesh")
        end
    end

    function ENT:Use(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        if self:GetFarmOwner() ~= ply then
            FARM.Notify(ply, string.format("%s님의 소입니다.", IsValid(self:GetFarmOwner()) and self:GetFarmOwner():Nick() or "다른 사람"))
            return
        end
        FARM.OpenCowMenu(ply, self)
    end

    local function GroundAt(self, pos)
        local tr = util.TraceLine({
            start = pos + Vector(0, 0, 40),
            endpos = pos - Vector(0, 0, 120),
            filter = self,
            mask = MASK_SOLID_BRUSHONLY,
        })
        if not tr.Hit then return nil end
        return tr.HitPos
    end

    -- 물리건으로 옮겨 놓았을 때
    function ENT:OnPlaced()
        local ground = GroundAt(self, self:GetPos())
        if ground then self:SetPos(ground) end
        self:SetAngles(Angle(0, self:GetAngles().y, 0))
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(false) end
        self.FarmHome = self:GetPos()
        self.WalkTarget = nil
        self:SetWalking(false)
    end

    function ENT:PickTarget()
        local C = FARM.Config.Cow
        local home = self.FarmHome or self:GetPos()
        for _ = 1, 4 do
            local ang = math.Rand(0, math.pi * 2)
            local r = math.Rand(40, C.WanderRadius)
            local ground = GroundAt(self, home + Vector(math.cos(ang) * r, math.sin(ang) * r, 0))
            if ground then
                local tr = util.TraceHull({
                    start = self:GetPos() + Vector(0, 0, 8),
                    endpos = ground + Vector(0, 0, 8),
                    mins = self.HullMins * 0.8,
                    maxs = self.HullMaxs * 0.8,
                    filter = self,
                })
                if not tr.Hit then return ground end
            end
        end
    end

    function ENT:Think()
        local now = CurTime()
        if self.FarmHeld then
            self:NextThink(now + 0.5)
            return true
        end

        local C = FARM.Config.Cow
        if self.WalkTarget then
            local pos = self:GetPos()
            local to = self.WalkTarget - pos
            to.z = 0
            local dist = to:Length()
            local speed = C.WalkSpeed * (self:GetGrowth() < 1 and 1.2 or 1)
            local stepLen = speed * 0.1

            if dist <= stepLen then
                self.WalkTarget = nil
                self:SetWalking(false)
                self.NextDecision = now + math.Rand(5, 20)
            else
                to:Normalize()
                local nextPos = pos + to * stepLen
                local ground = GroundAt(self, nextPos)
                if not ground or math.abs(ground.z - pos.z) > 18 then
                    self.WalkTarget = nil
                    self:SetWalking(false)
                    self.NextDecision = now + math.Rand(2, 6)
                else
                    self:SetPos(ground)
                    local yaw = math.ApproachAngle(self:GetAngles().y, to:Angle().y, 6)
                    self:SetAngles(Angle(0, yaw, 0))
                end
            end
        elseif now >= self.NextDecision then
            local roll = math.random()
            if roll < 0.45 then
                self.WalkTarget = self:PickTarget()
                self:SetWalking(self.WalkTarget ~= nil)
                self:SetEating(false)
            elseif roll < 0.75 and self:GetFed() then
                self:SetEating(true)
            else
                self:SetEating(false)
            end
            self.NextDecision = now + math.Rand(4, 12)
        end

        self:NextThink(now + 0.1)
        return true
    end

    function ENT:OnRemove()
        -- 툴건 등 예상치 못한 방법으로 지워졌다면 다음 계산 때 다시 생긴다.
    end
else
    -- 다리 흔들기, 풀 먹기: 모델에 애니메이션이 없어서 뼈를 직접 돌린다.
    local LEGS = {
        cow = { front = { "ShouldetLeft", "ShoulderRight" }, back = { "ThighLeft", "ThighRight" }, sign = 1 },
        bull = { front = { "ArmLeft", "ArmRight" }, back = { "ThighLeft", "ThighRight" }, sign = -1 },
    }

    function ENT:Initialize()
        self.WalkBlend = 0
        self.EatBlend = 0
    end

    function ENT:SetBoneRoll(name, roll)
        local id = self:LookupBone(name)
        if id then self:ManipulateBoneAngles(id, Angle(0, 0, roll)) end
    end

    function ENT:Think()
        local ft = FrameTime()
        self.WalkBlend = math.Approach(self.WalkBlend or 0, self:GetWalking() and 1 or 0, ft * 3)
        self.EatBlend = math.Approach(self.EatBlend or 0, (self:GetEating() and not self:GetWalking()) and 1 or 0, ft * 1.5)

        local legs = LEGS[self:IsBullModel() and "bull" or "cow"]
        local swing = math.sin(CurTime() * 6) * 22 * self.WalkBlend * legs.sign
        -- 대각선 다리끼리 같은 방향으로 움직인다.
        self:SetBoneRoll(legs.front[1], swing)
        self:SetBoneRoll(legs.back[2], swing)
        self:SetBoneRoll(legs.front[2], -swing)
        self:SetBoneRoll(legs.back[1], -swing)

        local nod = math.sin(CurTime() * 2) * 4
        self:SetBoneRoll("Neck", (35 + nod) * self.EatBlend)
    end

    function ENT:Draw()
        self:DrawModel()
    end
end
