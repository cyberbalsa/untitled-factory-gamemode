AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "gf_machine_base"
ENT.PrintName = "T0 / Construction hub"
ENT.Category = "Untitled Factory Gamemode"
ENT.Spawnable = true
ENT.HasInlet = true
ENT.Tint = Color(125, 85, 150)

if CLIENT then return end

function ENT:SetupMachine()
    self.Inputs = WireLib.CreateInputs(self, {"Deposit"})
    self.Outputs = WireLib.CreateOutputs(self, {"Inlet", "Ready", "Accepted", "Rejected", "Gravel", "Sand", "Clay", "Mineral"})
    self.GFAccepted, self.GFRejected, self.GFNextDeposit = 0, 0, 0
end

function ENT:BuildAccount()
    local receipt = GF.BuildReceipts[self]
    if receipt then return GF.GetBuildAccount(receipt.owner) end
end

function ENT:TriggerInput(name, value)
    if name ~= "Deposit" or not self:Pulse(name, value) or CurTime() < self.GFNextDeposit then return end
    self.GFNextDeposit = CurTime() + 0.25
    local account, owner = self:BuildAccount()
    local stock, kind = self:InletStock()
    if not account or not GF.Build.CanCredit(account, kind) then self.GFRejected = self.GFRejected + 1 return end
    if GF.TakeStock(stock) ~= kind then return end
    GF.Build.Credit(account, kind)
    GF.SaveBuildAccounts()
    GF.PublishBuildAccount(owner)
    self.GFAccepted = self.GFAccepted + 1
    self:EmitSound("buttons/button9.wav", 55, 115)
end

function ENT:MachineTick(now)
    local account, owner = self:BuildAccount()
    local _, kind = self:InletStock()
    local snapshot = {Inlet = GF.StockKinds[kind] or 0, Ready = account ~= nil and
        GF.Build.CanCredit(account, kind) and now >= self.GFNextDeposit, Accepted = self.GFAccepted, Rejected = self.GFRejected}
    for _, resource in ipairs(GF.Build.Kinds) do
        snapshot[resource] = account and GF.Build.Available(account, resource) or 0
    end
    for _, name in ipairs({"Inlet", "Accepted", "Rejected", "Ready"}) do self:Output(name, snapshot[name]) end
    for _, name in ipairs({"Gravel", "Sand", "Clay", "Mineral"}) do self:Output(name, snapshot[string.lower(name)]) end
    local ply = owner and player.GetBySteamID64(owner)
    self:SetOverlayText("CONSTRUCTION HUB\nPulse Deposit with a separated resource at the amber dock.\nReserve owner: " ..
        (IsValid(ply) and ply:Nick() or "offline builder") .. "\nSoil must be separated first. Building costs return on removal.")
end
