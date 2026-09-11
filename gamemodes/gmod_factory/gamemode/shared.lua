DeriveGamemode("sandbox")

GM.Name = "Untitled Factory Gamemode"
GM.Author = "Untitled Factory Gamemode contributors"
GM.IsSandboxDerived = true

GF = GF or {}
GF.Logic = include("core/sh_logic.lua")
GF.Tier0 = include("core/sh_tier0.lua")
GF.Build = include("core/sh_construction.lua")
GF.StockKinds = {blank = 1, component = 2}
GF.StockLabels = {blank = "Metal blank", component = "Servo component"}
for kind, resource in pairs(GF.Tier0.Resources) do
    GF.StockKinds[kind] = resource.id
    GF.StockLabels[kind] = resource.label
end
GF.Machines = {gf_extractor = true, gf_separator = true, gf_dispatch = true, gf_hub = true}
GF.StarterClasses = {"gf_extractor", "gf_separator", "gf_dispatch", "gf_hub"}

function GM:PlayerShouldTakeDamage(victim, attacker)
    if IsValid(attacker) and attacker:IsPlayer() and victim ~= attacker then return false end
end

-- A clamped blank is inside a press, not a separate manipulable prop.
-- Machines themselves remain ordinary physics entities for contraption building.
