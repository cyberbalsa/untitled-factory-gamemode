local textureFallback = CreateConVar("gf_soil_texture_fallback", "1", FCVAR_ARCHIVE,
    "Recognize soil names on unclassified world surfaces", 0, 1)

function GF.CheckSoilTrace(trace, machine)
    local surface = util.GetSurfacePropName(trace.SurfaceProps or 0) or ""
    local override = hook.Run("GF_AllowSoilSurface", trace, machine)
    local allowed, reason = GF.Tier0.SoilSurface(trace, surface, override, textureFallback:GetBool())
    return allowed, reason, surface
end

function GF.ExtractorGround(machine)
    if machine:GetUp().z < 0.9 then return false, "Keep the extractor upright" end
    local position = machine:GetPos()
    local trace = util.TraceLine({start = position, endpos = position - Vector(0, 0, 48),
        filter = machine, mask = MASK_SOLID})
    local allowed, reason, surface = GF.CheckSoilTrace(trace, machine)
    return allowed, reason, surface, trace
end

concommand.Add("gf_ground", function(ply)
    if not IsValid(ply) then return end
    local trace = ply:GetEyeTrace()
    local allowed, reason, surface = GF.CheckSoilTrace(trace)
    ply:PrintMessage(HUD_PRINTCONSOLE, string.format(
        "[UFG ground] %s | MatType=%s | surface=%s | material=%s | %s\n",
        allowed and "SOIL" or "UNSUITABLE", tostring(trace.MatType), surface, trace.HitTexture or "", reason))
    ply:ChatPrint("Ground survey: " .. reason .. ". Console has the surface details.")
end)
