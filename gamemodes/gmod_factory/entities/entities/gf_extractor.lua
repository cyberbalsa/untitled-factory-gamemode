AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "gf_machine_base"
ENT.PrintName = "T0 / Soil extractor"
ENT.Category = "Untitled Factory Gamemode"
ENT.Spawnable = true
ENT.HasOutlet = true
ENT.Tint = Color(115, 100, 65)

if CLIENT then return end

function ENT:SetupMachine()
    self.Inputs = WireLib.CreateInputs(self, {"Extract"})
    self.Outputs = WireLib.CreateOutputs(self, {"Ground", "Ready", "Blocked", "Limited", "Extracted"})
    self.GFNextExtract = 0
    self.GFExtracted = 0
end

function ENT:TriggerInput(name, value)
    if name ~= "Extract" or not self:Pulse(name, value) then return end
    if CurTime() < self.GFNextExtract or not GF.ExtractorGround(self) or self:OutletBlocked() then return end
    local stock = GF.MakeStock("soil", self:LocalToWorld(self.Outlet), self:GetAngles(), self:GetPlayer())
    if IsValid(stock) then
        self.GFExtracted = self.GFExtracted + 1
        self.GFNextExtract = CurTime() + 2
        self:EmitSound("physics/gravel/gravel_impact_hard1.wav", 55, 90)
    end
end

function ENT:MachineTick(now)
    local ground, reason = GF.ExtractorGround(self)
    local blocked, limited = self:OutletBlocked(), not GF.CanMakeStock()
    local ready = ground and not blocked and not limited and now >= self.GFNextExtract
    self:Output("Ground", ground)
    self:Output("Blocked", blocked)
    self:Output("Limited", limited)
    self:Output("Extracted", self.GFExtracted)
    self:Output("Ready", ready)
    self:SetOverlayText("SOIL EXTRACTOR / TIER 0\nPulse Extract. Green dock: bulk soil\n" .. reason .. "\n" ..
        (limited and "Loose-item limit reached" or blocked and "Clear the outlet" or "One parcel per 2 seconds"))
end
