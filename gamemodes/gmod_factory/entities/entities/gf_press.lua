AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "gf_machine_base"
ENT.PrintName = "02 / Servo press"
ENT.Category = "Untitled Factory Gamemode"
ENT.Spawnable = false -- Retained prototype; later tiers must supply its blanks.
ENT.HasInlet = true
ENT.HasOutlet = true
ENT.Tint = Color(75, 95, 130)

if CLIENT then return end

function ENT:SetupMachine()
    self.GFState = GF.Logic.NewPress()
    self.Inputs = WireLib.CreateInputs(self, {"Load", "Clamp", "Cycle", "Eject", "Reset"})
    self.Outputs = WireLib.CreateOutputs(self, {"Inlet", "Loaded", "Clamped", "Ready", "Busy", "Done", "Progress", "Blocked", "Fault"})
end

function ENT:TriggerInput(name, value)
    local state = self.GFState
    if name == "Clamp" then state:SetClamp(GF.Logic.High(value)) return end
    if not self:Pulse(name, value) then return end
    if name == "Load" then
        local stock, kind = self:InletStock()
        if state:Load(kind) then GF.TakeStock(stock) end
    elseif name == "Cycle" then
        if state:Cycle(CurTime()) then self:EmitSound("buttons/lever7.wav", 55, 90) end
    elseif name == "Eject" then
        if state:CanEject(self:OutletBlocked() or not GF.CanMakeStock()) then
            local stock = GF.MakeStock(state.item, self:LocalToWorld(self.Outlet), self:GetAngles(), self:GetPlayer())
            if IsValid(stock) then state:CommitEject() end
        end
    elseif name == "Reset" then
        state:Reset()
    end
end

function ENT:MachineTick(now)
    local state = self.GFState
    state:Tick(now)
    local _, inletKind = self:InletStock()
    local blocked = self:OutletBlocked() or not GF.CanMakeStock()
    -- Publish a single snapshot: Wire feedback may change the state during callbacks.
    local snapshot = {Inlet = GF.StockKinds[inletKind] or 0, Loaded = state.item ~= nil,
        Clamped = state.clamped, Ready = state:Ready(), Busy = state.busy, Done = state.done,
        Progress = math.floor(state.progress * 100), Blocked = blocked, Fault = state.fault}
    for _, name in ipairs({"Inlet", "Loaded", "Clamped", "Busy", "Done", "Progress", "Blocked", "Fault", "Ready"}) do
        self:Output(name, snapshot[name])
    end
    self:SetOverlayText("SERVO PRESS\nAmber: input | Green: output\nLoad > Clamp > Cycle > release > Eject\n" ..
        GF.Logic.Faults[state.fault] .. "\nWorkpiece: " .. (state.item or "empty") ..
        " | Progress: " .. snapshot.Progress .. "%")
end
