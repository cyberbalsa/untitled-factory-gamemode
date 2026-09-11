AddCSLuaFile()
DEFINE_BASECLASS("base_wire_entity")
ENT.Type = "anim"
ENT.Base = "base_wire_entity"
ENT.PrintName = "Factory machine"
ENT.Category = "Untitled Factory Gamemode"
ENT.Spawnable = false
ENT.AdminOnly = false
ENT.Model = "models/hunter/blocks/cube05x05x05.mdl"
ENT.Tint = Color(55, 80, 95)
ENT.Inlet = Vector(-40, 0, 0)
ENT.Outlet = Vector(40, 0, 0)

function ENT:SpawnFunction(ply, trace, class)
    if not SERVER or not GF or not trace.Hit then return end
    return GF.SpawnMachine(ply, class, trace.HitPos + trace.HitNormal * 18, Angle(0, ply:EyeAngles().y, 0))
end

if CLIENT then
    local inletColor = Color(245, 180, 65)
    local outletColor = Color(65, 225, 180)
    function ENT:Draw(flags)
        BaseClass.Draw(self, flags)
        if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > 700 * 700 then return end
        if self.HasInlet then
            render.DrawWireframeBox(self:LocalToWorld(self.Inlet), self:GetAngles(),
                Vector(-14, -14, -10), Vector(14, 14, 10), inletColor, false)
        end
        if self.HasOutlet then
            render.DrawWireframeBox(self:LocalToWorld(self.Outlet), self:GetAngles(),
                Vector(-14, -14, -10), Vector(14, 14, 10), outletColor, false)
        end
    end
    return
end

function ENT:Initialize()
    self:SetModel(self.Model)
    self:SetMaterial("models/debug/debugwhite")
    self:SetColor(self.Tint)
    BaseClass.Initialize(self)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:SetMass(80) phys:Wake() end
    self.GFEdges = {}
    self.GFLastOutputs = {}
    self:SetupMachine()
end

function ENT:SetupMachine() end

function ENT:Pulse(name, value)
    return GF.Logic.Rising(self.GFEdges, name, value)
end

function ENT:Output(name, value)
    if type(value) == "boolean" then value = value and 1 or 0 end
    if self.GFLastOutputs[name] == value then return end
    self.GFLastOutputs[name] = value
    WireLib.TriggerOutput(self, name, value)
end

function ENT:InletStock()
    local position = self:LocalToWorld(self.Inlet)
    local ent, kind = GF.FindStock(position, 18)
    if not IsValid(ent) then return end
    -- A nearby item behind a wall is not at the dock.
    local trace = util.TraceLine({start = position, endpos = ent:GetPos(), filter = self, mask = MASK_SOLID})
    if trace.Hit and trace.Entity ~= ent then return end
    return ent, kind
end

function ENT:OutletBlocked()
    local position = self:LocalToWorld(self.Outlet)
    local trace = util.TraceHull({start = position, endpos = position,
        mins = Vector(-9, -9, -9), maxs = Vector(9, 9, 9), filter = self, mask = MASK_SOLID})
    return trace.Hit or not util.IsInWorld(position)
end

function ENT:Think()
    self:MachineTick(CurTime())
    self:NextThink(CurTime() + 0.1)
    return true
end

function ENT:OnEntityCopyTableFinish(data)
    BaseClass.OnEntityCopyTableFinish(self, data)
    data.GFState = nil
    data.GFEdges = nil
    data.GFLastOutputs = nil
end

function ENT:OnRemove()
    -- Hardware deletion scraps any contained workpiece. It never manufactures output.
    BaseClass.OnRemove(self)
end
