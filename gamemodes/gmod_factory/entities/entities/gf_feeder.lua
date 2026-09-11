AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "gf_machine_base"
ENT.PrintName = "01 / Blank feeder"
ENT.Category = "Untitled Factory Gamemode"
ENT.Spawnable = true
ENT.HasOutlet = true
ENT.Tint = Color(95, 120, 140)

if CLIENT then return end

function ENT:SetupMachine()
    self.Inputs = WireLib.CreateInputs(self, {"Dispense"})
    self.Outputs = WireLib.CreateOutputs(self, {"Ready", "Blocked", "Limited", "Dispensed"})
    self.GFNextDispense = 0
    self.GFDispensed = 0
end

function ENT:TriggerInput(name, value)
    if name ~= "Dispense" or not self:Pulse(name, value) then return end
    if CurTime() < self.GFNextDispense or self:OutletBlocked() then return end
    local stock = GF.MakeStock("blank", self:LocalToWorld(self.Outlet), self:GetAngles(), self:GetPlayer())
    if IsValid(stock) then
        self.GFDispensed = self.GFDispensed + 1
        self.GFNextDispense = CurTime() + 1
        self:EmitSound("buttons/button14.wav", 55, 105)
    end
end

function ENT:MachineTick(now)
    local blocked = self:OutletBlocked()
    local limited = not GF.CanMakeStock()
    self:Output("Blocked", blocked)
    self:Output("Limited", limited)
    self:Output("Dispensed", self.GFDispensed)
    self:Output("Ready", not blocked and not limited and now >= self.GFNextDispense)
    self:SetOverlayText("BLANK FEEDER\nPulse Dispense to issue one blank.\nGreen dock: output\n" ..
        (limited and "Loose-item limit reached" or blocked and "Clear the outlet" or "Awaiting controller"))
end
