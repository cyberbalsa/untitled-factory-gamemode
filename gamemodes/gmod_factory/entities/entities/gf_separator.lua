AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "gf_machine_base"
ENT.PrintName = "T0 / Soil separator"
ENT.Category = "Untitled Factory Gamemode"
ENT.Spawnable = true
ENT.HasInlet = true
ENT.HasOutlet = true
ENT.Tint = Color(95, 115, 145)

if CLIENT then return end

function ENT:SetupMachine()
    self.GFState = GF.Tier0.NewSeparator()
    self.GFResource = GF.StockKinds.gravel
    self.Inputs = WireLib.CreateInputs(self, {"Load", "Cycle", "Resource", "Eject", "Reset"})
    self.Outputs = WireLib.CreateOutputs(self, {"Inlet", "CanLoad", "Loaded", "Ready", "Busy", "Done",
        "Progress", "Blocked", "Fault", "Selected", "Gravel", "Sand", "Clay", "Mineral", "Pending"})
end

function ENT:TriggerInput(name, value)
    if name == "Resource" then self.GFResource = GF.Tier0.ResourceKind(value) and value or 0 return end
    if not self:Pulse(name, value) then return end
    local state = self.GFState
    if name == "Load" then
        local stock, kind = self:InletStock()
        if state:Load(kind) then GF.TakeStock(stock) end
    elseif name == "Cycle" then
        if state:Cycle(CurTime()) then self:EmitSound("buttons/lever7.wav", 55, 110) end
    elseif name == "Eject" then
        local kind = state:Peek(self.GFResource, self:OutletBlocked() or not GF.CanMakeStock())
        if not kind then return end
        local stock = GF.MakeStock(kind, self:LocalToWorld(self.Outlet), self:GetAngles(), self:GetPlayer())
        if IsValid(stock) then state:CommitEject(kind) end
    elseif name == "Reset" then state:Reset() end
end

function ENT:MachineTick(now)
    local state = self.GFState
    state:Tick(now)
    local _, kind = self:InletStock()
    local snapshot = {Inlet = GF.StockKinds[kind] or 0, CanLoad = state:CanLoad(), Loaded = state.soil,
        Ready = state:Ready(), Busy = state.busy, Done = state:Pending() > 0,
        Progress = math.floor(state.progress * 100), Blocked = self:OutletBlocked() or not GF.CanMakeStock(),
        Fault = state.fault, Selected = self.GFResource, Pending = state:Pending(),
        Gravel = state.inventory.gravel or 0, Sand = state.inventory.sand or 0,
        Clay = state.inventory.clay or 0, Mineral = state.inventory.mineral or 0}
    for _, name in ipairs({"Inlet", "Loaded", "Busy", "Done", "Progress", "Blocked", "Fault", "Selected",
        "Gravel", "Sand", "Clay", "Mineral", "Pending", "CanLoad", "Ready"}) do
        self:Output(name, snapshot[name])
    end
    local selected = GF.Tier0.ResourceKind(self.GFResource)
    self:SetOverlayText("SOIL SEPARATOR / TIER 0\nLoad > Cycle > select Resource > Eject each fraction\n" ..
        GF.Tier0.Faults[state.fault] .. "\nSelected: " .. (GF.StockLabels[selected] or "invalid") ..
        " | Remaining: " .. snapshot.Pending .. "\n11 gravel / 12 sand / 13 clay / 14 concentrate")
end
