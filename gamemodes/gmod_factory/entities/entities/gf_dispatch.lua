AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "gf_machine_base"
ENT.PrintName = "03 / Tribute uplink"
ENT.Category = "Untitled Factory Gamemode"
ENT.Spawnable = true
ENT.HasInlet = true
ENT.Tint = Color(60, 125, 110)

if CLIENT then return end

function ENT:SetupMachine()
    self.Inputs = WireLib.CreateInputs(self, {"Submit"})
    self.Outputs = WireLib.CreateOutputs(self, {"Inlet", "Ready", "Accepted", "Rejected", "Order", "Delivered", "Required", "Favor"})
    self.GFAccepted = 0
    self.GFRejected = 0
    self.GFNextSubmit = 0
end

function ENT:TriggerInput(name, value)
    if name ~= "Submit" or not self:Pulse(name, value) or CurTime() < self.GFNextSubmit then return end
    local stock, kind = self:InletStock()
    self.GFNextSubmit = CurTime() + 0.5
    if kind ~= "component" then self.GFRejected = self.GFRejected + 1 return end
    if GF.TakeStock(stock) ~= "component" then return end
    self.GFAccepted = self.GFAccepted + 1
    GF.Deliver()
    self:EmitSound("buttons/button9.wav", 55, 105)
end

function ENT:MachineTick(now)
    local _, kind = self:InletStock()
    local contract = GF.Contract
    local snapshot = {Inlet = GF.StockKinds[kind] or 0, Ready = kind == "component" and now >= self.GFNextSubmit,
        Accepted = self.GFAccepted, Rejected = self.GFRejected, Order = contract.order,
        Delivered = contract.delivered, Required = GF.Logic.Quota(contract.order), Favor = contract.favor}
    for _, name in ipairs({"Inlet", "Accepted", "Rejected", "Order", "Delivered", "Required", "Favor", "Ready"}) do
        self:Output(name, snapshot[name])
    end
    self:SetOverlayText("TRIBUTE UPLINK\nPulse Submit with a component at the amber dock.\nOrder " .. snapshot.Order ..
        ": " .. snapshot.Delivered .. "/" .. snapshot.Required .. " components\nFavor: " .. snapshot.Favor)
end
