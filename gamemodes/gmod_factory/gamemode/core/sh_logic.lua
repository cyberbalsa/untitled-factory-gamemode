-- Engine-independent rules. Time is supplied by the server; Wire only requests actions.
local Logic = {}

function Logic.High(value)
    return type(value) == "number" and value == value and value < math.huge and value > 0
end

function Logic.Rising(edges, name, value)
    local high = Logic.High(value)
    local rising = high and not edges[name]
    edges[name] = high
    return rising
end

Logic.Faults = {
    [0] = "Operational",
    [1] = "No blank loaded",
    [2] = "Release the clamp first",
    [3] = "Clamp the blank before cycling",
    [4] = "Wrong material: a metal blank is required",
    [5] = "Cycle interrupted: clamp released. Reset to retry",
    [6] = "Outlet obstructed. Clear it, then reset",
    [7] = "No material to eject"
}

local Press = {}
Press.__index = Press

function Logic.NewPress()
    return setmetatable({item = nil, clamped = false, busy = false, done = false,
        fault = 0, progress = 0, duration = 3}, Press)
end

function Press:Fail(code)
    self.fault = code
    return false
end

function Press:Load(kind)
    if self.busy or self.item or self.fault ~= 0 then return false end
    if self.clamped then return self:Fail(2) end
    if kind ~= "blank" then return self:Fail(kind and 4 or 1) end
    self.item = kind
    self.done = false
    self.progress = 0
    return true
end

function Press:SetClamp(high)
    self.clamped = high
    if self.busy and not high then
        self.busy = false
        self.progress = 0
        self:Fail(5)
    end
end

function Press:Cycle(now)
    if self.busy or self.fault ~= 0 then return false end
    if self.item ~= "blank" then return self:Fail(1) end
    if not self.clamped then return self:Fail(3) end
    self.started = now
    self.busy = true
    self.done = false
    self.progress = 0
    return true
end

function Press:Tick(now)
    if not self.busy then return end
    self.progress = math.max(0, math.min(1, (now - self.started) / self.duration))
    if self.progress >= 1 then
        self.item = "component"
        self.busy = false
        self.done = true
    end
end

function Press:CanEject(blocked)
    if self.busy or self.fault ~= 0 then return false end
    if not self.item then return self:Fail(7) end
    if self.clamped then return self:Fail(2) end
    if blocked then return self:Fail(6) end
    return true
end

-- Call only after the physical output has successfully spawned.
function Press:CommitEject()
    local kind = self.item
    self.item = nil
    self.done = false
    self.progress = 0
    return kind
end

function Press:Reset()
    self.fault = 0
    if self.busy then
        self.busy = false
        self.progress = 0
    end
end

function Press:Ready()
    return self.item == "blank" and self.clamped and not self.busy and self.fault == 0
end

function Logic.Quota(order)
    return math.min(100, 5 + order * 5)
end

local function integer(value, fallback, minimum, maximum)
    if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
    return math.max(minimum, math.min(maximum, math.floor(value)))
end

function Logic.NewContract(saved)
    saved = type(saved) == "table" and saved or {}
    local order = integer(saved.order, 1, 1, 1000000)
    return {order = order, delivered = integer(saved.delivered, 0, 0, Logic.Quota(order) - 1),
        favor = integer(saved.favor, 0, 0, 1000000000)}
end

local orderResources = {"gravel", "sand", "clay", "mineral"}

function Logic.OrderResource(order)
    return orderResources[(order - 1) % #orderResources + 1]
end

function Logic.Deliver(contract, kind)
    if kind ~= Logic.OrderResource(contract.order) then return false end
    contract.delivered = contract.delivered + 1
    if contract.delivered < Logic.Quota(contract.order) then return false end
    contract.favor = math.min(1000000000, contract.favor + 100)
    contract.order = math.min(1000000, contract.order + 1)
    contract.delivered = 0
    return true
end

return Logic
