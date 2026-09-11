-- Independent Tier 0 rules. No engine globals are needed by this file.
local Tier0 = {}

Tier0.Resources = {
    soil = {id = 10, label = "Soil", color = {115, 80, 48}},
    gravel = {id = 11, label = "Gravel", color = {145, 150, 155}},
    sand = {id = 12, label = "Sand", color = {225, 205, 135}},
    clay = {id = 13, label = "Clay", color = {195, 115, 80}},
    mineral = {id = 14, label = "Mineral concentrate", color = {145, 115, 205}}
}
Tier0.Fractions = {"gravel", "sand", "clay", "mineral"}
-- One bulk soil parcel becomes four smaller fractions. Counts are parcels, not mass.
Tier0.Yield = {gravel = 1, sand = 1, clay = 1, mineral = 1}

local soilSurfaces = {dirt = true, grass = true, soil = true, mud = true}

function Tier0.SoilSurface(trace, surfaceName, override, textureFallback)
    if not trace.Hit or not trace.HitWorld or trace.HitSky or trace.HitNoDraw or
        trace.StartSolid or trace.AllSolid or trace.HitTexture == "**studio**" then
        return false, "Aim at exposed map ground"
    end
    if not trace.HitNormal or trace.HitNormal.z < 0.7 then return false, "Ground is too steep" end
    if override == false then return false, "Ground excluded by map rule" end
    if override == true then return true, "Map soil rule" end
    -- MAT_DIRT = 68; MAT_GRASS = 85. Displacements may have no material path.
    if trace.MatType == 68 or trace.MatType == 85 then return true, "Dirt/grass material tag" end
    if soilSurfaces[string.lower(surfaceName or "")] then return true, "Soil surface property" end
    -- Only fall back for unclassified surfaces, never a dirt-named metal prop/floor.
    if textureFallback and (not trace.MatType or trace.MatType == 0 or trace.MatType == 88) then
        for token in string.lower(trace.HitTexture or ""):gmatch("[a-z]+") do
            if soilSurfaces[token] then return true, "Soil material-name fallback" end
        end
    end
    return false, "Requires dirt or grass ground"
end

function Tier0.ResourceKind(id)
    for kind, resource in pairs(Tier0.Resources) do
        if resource.id == id then return kind end
    end
end

Tier0.Faults = {
    [0] = "Operational", [1] = "No soil loaded", [2] = "Only soil can be separated",
    [3] = "Outlet obstructed or loose-item limit reached", [4] = "Selected fraction is empty",
    [5] = "Select a valid Resource ID"
}

local Separator = {}
Separator.__index = Separator

function Tier0.NewSeparator()
    return setmetatable({soil = false, busy = false, progress = 0, fault = 0,
        duration = 4, inventory = {}}, Separator)
end

function Separator:Pending()
    local count = 0
    for _, kind in ipairs(Tier0.Fractions) do count = count + (self.inventory[kind] or 0) end
    return count
end

function Separator:CanLoad()
    return not self.soil and not self.busy and self:Pending() == 0 and self.fault == 0
end

function Separator:Load(kind)
    if not self:CanLoad() then return false end
    if kind ~= "soil" then self.fault = kind and 2 or 1 return false end
    self.soil = true
    self.progress = 0
    return true
end

function Separator:Ready()
    return self.soil and not self.busy and self.fault == 0
end

function Separator:Cycle(now)
    if self.busy or self.fault ~= 0 or self:Pending() > 0 then return false end
    if not self.soil then self.fault = 1 return false end
    self.started = now
    self.progress = 0
    self.busy = true
    return true
end

function Separator:Tick(now)
    if not self.busy then return end
    self.progress = math.max(0, math.min(1, (now - self.started) / self.duration))
    if self.progress < 1 then return end
    self.soil = false
    self.busy = false
    for _, kind in ipairs(Tier0.Fractions) do self.inventory[kind] = Tier0.Yield[kind] end
end

function Separator:Peek(resource, blocked)
    if self.busy or self.fault ~= 0 then return end
    local kind = Tier0.ResourceKind(resource)
    if not kind then self.fault = 5 return end
    local available = kind == "soil" and self.soil or (self.inventory[kind] or 0) > 0
    if not available then self.fault = 4 return end
    if blocked then self.fault = 3 return end
    return kind
end

-- Commit only after an output entity exists; a failed spawn preserves inventory.
function Separator:CommitEject(kind)
    if kind == "soil" then self.soil = false
    elseif (self.inventory[kind] or 0) > 0 then self.inventory[kind] = self.inventory[kind] - 1 end
    if self:Pending() == 0 then self.progress = 0 end
end

function Separator:Reset()
    self.fault = 0
    if self.busy then self.busy = false self.progress = 0 end
end

return Tier0
