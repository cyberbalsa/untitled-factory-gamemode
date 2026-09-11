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
    self.Outputs = WireLib.CreateOutputs(self, {"Inlet", "Target", "Ready", "Accepted", "Rejected", "Order", "Delivered", "Required", "Favor"})
    self.GFAccepted = 0
    self.GFRejected = 0
    self.GFNextSubmit = 0
end

function ENT:TriggerInput(name, value)
    if name ~= "Submit" or not self:Pulse(name, value) or CurTime() < self.GFNextSubmit then return end
    local stock, kind = self:InletStock()
    self.GFNextSubmit = CurTime() + 0.5
    if kind ~= GF.Logic.OrderResource(GF.Contract.order) then self.GFRejected = self.GFRejected + 1 return end
    if GF.TakeStock(stock) ~= kind then return end
    self.GFAccepted = self.GFAccepted + 1
    GF.Deliver(kind)
    self:EmitSound("buttons/button9.wav", 55, 105)
end

function ENT:MachineTick(now)
    local _, kind = self:InletStock()
    local contract = GF.Contract
    local target = GF.Logic.OrderResource(contract.order)
    local snapshot = {Inlet = GF.StockKinds[kind] or 0, Target = GF.StockKinds[target], Ready = kind == target and now >= self.GFNextSubmit,
        Accepted = self.GFAccepted, Rejected = self.GFRejected, Order = contract.order,
        Delivered = contract.delivered, Required = GF.Logic.Quota(contract.order), Favor = contract.favor}
    for _, name in ipairs({"Inlet", "Target", "Accepted", "Rejected", "Order", "Delivered", "Required", "Favor", "Ready"}) do
        self:Output(name, snapshot[name])
    end
    self:SetOverlayText("TRIBUTE UPLINK / TIER 0\nPulse Submit with the requested resource at the amber dock.\nOrder " .. snapshot.Order ..
        ": " .. snapshot.Delivered .. "/" .. snapshot.Required .. " " .. GF.StockLabels[target] .. "\nFavor: " .. snapshot.Favor)
end
