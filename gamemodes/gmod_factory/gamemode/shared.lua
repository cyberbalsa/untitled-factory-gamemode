DeriveGamemode("sandbox")

GM.Name = "Untitled Factory Gamemode"
GM.Author = "Untitled Factory Gamemode contributors"
GM.IsSandboxDerived = true

GF = GF or {}
GF.Logic = include("core/sh_logic.lua")
GF.StockKinds = {blank = 1, component = 2}
GF.Machines = {gf_feeder = true, gf_press = true, gf_dispatch = true}

function GM:PlayerShouldTakeDamage(victim, attacker)
    if IsValid(attacker) and attacker:IsPlayer() and victim ~= attacker then return false end
end

-- A clamped blank is inside a press, not a separate manipulable prop.
-- Machines themselves remain ordinary physics entities for contraption building.
