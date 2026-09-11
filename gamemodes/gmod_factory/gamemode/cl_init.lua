include("shared.lua")

local ink = Color(13, 21, 29, 235)
local accent = Color(90, 230, 185)
local muted = Color(170, 185, 195)
local white = Color(232, 239, 243)

surface.CreateFont("GFTitle", {font = "Roboto", size = 22, weight = 700})
surface.CreateFont("GFBody", {font = "Roboto", size = 17, weight = 400})
surface.CreateFont("GFSmall", {font = "Roboto", size = 14, weight = 500})

hook.Add("HUDPaint", "gf_directive", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local width = math.min(370, ScrW() - 32)
    local x, y = ScrW() - width - 16, 20
    local required = GetGlobalInt("gf_required", 10)
    local delivered = GetGlobalInt("gf_delivered", 0)
    draw.RoundedBox(5, x, y, width, 144, ink)
    surface.SetDrawColor(accent)
    surface.DrawRect(x, y, 3, 144)
    draw.SimpleText("OFFICE OF PRODUCTIVE LABOR", "GFSmall", x + 16, y + 13, accent)
    draw.SimpleText("DIRECTIVE " .. string.format("%03d", GetGlobalInt("gf_order", 1)), "GFTitle", x + 16, y + 34, white)
    draw.SimpleText(delivered .. " / " .. required .. " servo components", "GFBody", x + 16, y + 66, white)
    surface.SetDrawColor(42, 61, 72)
    surface.DrawRect(x + 16, y + 94, width - 32, 4)
    surface.SetDrawColor(accent)
    surface.DrawRect(x + 16, y + 94, (width - 32) * math.Clamp(delivered / math.max(1, required), 0, 1), 4)
    draw.SimpleText("Favor " .. GetGlobalInt("gf_favor", 0) .. "   /   F1: briefing", "GFSmall", x + 16, y + 113, muted)

    if not GetGlobalBool("gf_wire_ready", false) then
        draw.RoundedBox(5, x, y + 154, width, 60, ink)
        draw.SimpleText("Wiremod is required", "GFBody", x + 16, y + 164, Color(255, 180, 90))
        draw.SimpleText("Enable Wiremod, then reload the map.", "GFSmall", x + 16, y + 189, white)
    end

    local ent = ply:GetEyeTrace().Entity
    if IsValid(ent) and ent:GetClass() == "gf_stock" and ply:GetPos():DistToSqr(ent:GetPos()) < 400 * 400 then
        local kind = ent:GetNWString("gf_kind", "")
        draw.SimpleText(kind == "component" and "SERVO COMPONENT / Ready for tribute" or "METAL BLANK / Requires pressing",
            "GFBody", ScrW() / 2, ScrH() / 2 + 40, accent, TEXT_ALIGN_CENTER)
    end
end)

local briefing
local function showBriefing()
    if IsValid(briefing) then briefing:MakePopup() return end
    briefing = vgui.Create("DFrame")
    briefing:SetSize(math.min(760, ScrW() - 32), math.min(710, ScrH() - 32))
    briefing:Center()
    briefing:SetTitle("Untitled Factory Gamemode / Labor briefing")
    briefing:MakePopup()
    briefing.Paint = function(_, width, height) draw.RoundedBox(6, 0, 0, width, height, ink) end

    local kit = vgui.Create("DButton", briefing)
    kit:Dock(BOTTOM)
    kit:SetTall(42)
    kit:SetText("Issue starter hardware at your crosshair")
    kit.DoClick = function() briefing:Close() RunConsoleCommand("gf_starterkit") end

    local scroll = vgui.Create("DScrollPanel", briefing)
    scroll:Dock(FILL)
    scroll:DockMargin(16, 14, 16, 14)
    local text = vgui.Create("DLabel", scroll)
    text:Dock(TOP)
    text:SetFont("GFBody")
    text:SetTextColor(white)
    text:SetWrap(true)
    text:SetAutoStretchVertical(true)
    text:SetText([[Your overlords require servo components. Your continued usefulness is under review.

ASSIGNMENT 01 / BUILD A PRODUCTION CELL

Look at a clear floor before requesting starter hardware, or spawn machines from Q > Entities > Untitled Factory Gamemode. Hardware starts frozen; use the physgun to position it.

1. Wire Dispense on the feeder. Each 0-to-positive pulse issues one metal blank at its green dock.
2. Build a way to move the blank to the press's amber dock. Try a chute, a piston, a grabber, or an E2-controlled transport. The physgun is useful while testing.
3. Pulse Load, hold Clamp at 1, then pulse Cycle. Watch Busy and Progress. Keep the clamp closed until Done becomes 1.
4. Set Clamp to 0. Once Clamped is 0 and Blocked is 0, pulse Eject. Move the finished component to the uplink's amber dock.
5. Pulse Submit on the uplink. Deliver the full order to earn favor and receive a larger order.

PROGRAM THE FACTORY

Use Wire logic gates or Expression 2. Action inputs respond to a rising edge; holding an action high does not repeat it. Clamp is a continuous signal. Read the machine's outputs and wait for feedback before the next operation.

Inlet: 0 = empty, 1 = blank, 2 = component.
Ready, Loaded, Clamped, Busy, Done, Blocked: 0 or 1.
Progress: 0 to 100. Fault: 0 means operational.
If the press faults, correct the cause and pulse Reset. Reset during a cycle stops it and preserves the unfinished blank.

COOPERATIVE LABOR

Everyone contributes to the same order. Order progress and favor save per map; solo and multiplayer have separate progress files. Contraptions and loose items are not automatically saved in this prototype. Duplicated machines start empty.

Prototype rules: free hardware and blanks, limited loose items, no deadline. The first goal is a reliable unattended cell.]])
end

net.Receive("gf_help", showBriefing)
concommand.Add("gf_help", showBriefing)
