--!strict
-- 3D models for the 8 collection tools. The grip part is named "Handle" and sits
-- at the origin; the business end points along -Z. ToolService welds every
-- other part to the Handle to make a real Tool.

local Kit = require(script.Parent.Kit)
local Tools = require(script.Parent.Parent.Tools)

local ToolArt = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local CN = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local DARK = rgb(45, 47, 56)
local STEEL = rgb(190, 196, 210)
local WOOD = rgb(160, 105, 60)
local RUBBER = rgb(35, 35, 40)
local WHITE = rgb(245, 245, 250)
local GOLD = rgb(255, 200, 50)

local function handle(m: Model, color: Color3): Part
	local grip = Kit.cyl(m, CN(0, 0, 0.2) * ANG(0, rad(90), 0), 1.4, 0.48, color, { Name = "Handle" })
	for z = -0.3, 0.7, 0.33 do
		Kit.cylZ(m, CN(0, 0, z), 0.08, 0.54, Kit.shade(color, -0.3))
	end
	Kit.ball(m, CN(0, 0, 0.95), 0.6, Kit.shade(color, -0.2))
	return grip
end

local function claw(m: Model, at: CFrame, color: Color3, prongs: number, size: number)
	Kit.ball(m, at, 0.7 * size, Kit.shade(color, -0.2))
	for i = 0, prongs - 1 do
		local around = at * ANG(0, 0, i / prongs * math.pi * 2)
		local base = around * CN(0, 0.3 * size, -0.1)
		Kit.cylZ(m, base * ANG(rad(-25), 0, 0) * CN(0, 0, -0.45 * size), 0.9 * size, 0.2 * size, color)
		Kit.cylZ(m, base * ANG(rad(-25), 0, 0) * CN(0, 0, -0.9 * size) * ANG(rad(55), 0, 0) * CN(0, 0, -0.3 * size), 0.6 * size, 0.18 * size, color)
		Kit.ball(m, base * ANG(rad(-25), 0, 0) * CN(0, 0, -0.9 * size), 0.22 * size, color)
	end
end

type Builder = (m: Model, tool: Tools.Tool) -> ()
local B: { [number]: Builder } = {}

B[1] = function(m, tool) -- Rusty Grabber
	handle(m, WOOD)
	Kit.cylZ(m, CN(0, 0, -1.4), 2.4, 0.26, WOOD)
	Kit.cylZ(m, CN(0, 0, -0.75), 0.25, 0.36, DARK)
	Kit.box(m, CN(0, -0.35, 0.1), Vector3.new(0.18, 0.5, 0.2), DARK)
	claw(m, CN(0, 0, -2.8), tool.Color, 2, 1.45)
end

B[2] = function(m, tool) -- Steel Grabber
	handle(m, RUBBER)
	Kit.cylZ(m, CN(0, 0, -1.45), 2.5, 0.28, tool.Color)
	for _, z in { -0.7, -2.0 } do
		Kit.cylZ(m, CN(0, 0, z), 0.2, 0.4, Kit.shade(tool.Color, -0.3))
	end
	Kit.box(m, CN(0, -0.35, 0.1), Vector3.new(0.18, 0.5, 0.2), rgb(230, 70, 60))
	claw(m, CN(0, 0, -2.95), tool.Color, 3, 1.35)
end

B[3] = function(m, tool) -- Magnet Claw
	handle(m, RUBBER)
	Kit.cylZ(m, CN(0, 0, -1.3), 2.2, 0.3, STEEL)
	-- Horseshoe magnet head.
	local head = CN(0, 0, -2.6)
	for _, side in { -1, 1 } do
		Kit.cylZ(m, head * CN(side * 0.55, 0, -0.45), 0.9, 0.5, tool.Color)
		Kit.cylZ(m, head * CN(side * 0.55, 0, -1.0), 0.3, 0.52, STEEL)
	end
	for i = 0, 4 do
		local a = i / 4 * math.pi
		Kit.ball(m, head * CN(math.cos(a) * 0.55, math.sin(a) * 0.0, 0.05 + math.sin(a) * 0.45), 0.52, tool.Color)
	end
	Kit.box(m, head * CN(0, 0, -1.2), Vector3.new(0.9, 0.06, 0.06), rgb(120, 220, 255), { Neon = true })
end

B[4] = function(m, tool) -- Hydraulic Claw
	handle(m, RUBBER)
	Kit.roundBox(m, CN(0, 0.05, -0.9), Vector3.new(0.7, 0.7, 1.2), 0.2, tool.Color, nil, false)
	Kit.cylZ(m, CN(0, 0, -1.9), 1.4, 0.32, STEEL)
	for _, side in { -1, 1 } do
		Kit.cylZ(m, CN(side * 0.32, 0.2, -1.8), 1.2, 0.18, DARK)
		Kit.cylZ(m, CN(side * 0.32, 0.2, -2.5), 0.5, 0.12, STEEL)
	end
	Kit.box(m, CN(0, 0.3, -0.9), Vector3.new(0.12, 0.12, 0.8), rgb(230, 60, 60))
	local head = CN(0, 0, -2.75)
	Kit.roundBox(m, head, Vector3.new(1.1, 0.5, 0.5), 0.15, tool.Color, nil, false)
	for _, side in { -1, 1 } do
		Kit.box(m, head * CN(side * 0.45, 0, -0.55) * ANG(0, rad(-side * 15), 0), Vector3.new(0.22, 0.4, 0.9), DARK)
		Kit.box(m, head * CN(side * 0.3, 0, -1.0) * ANG(0, rad(side * 35), 0), Vector3.new(0.2, 0.38, 0.5), DARK)
	end
end

B[5] = function(m, tool) -- Laser Cutter
	handle(m, DARK)
	Kit.roundBox(m, CN(0, 0.35, -0.6), Vector3.new(0.75, 0.75, 2.0), 0.3, WHITE)
	Kit.roundBox(m, CN(0, 0.35, -0.6), Vector3.new(0.78, 0.3, 1.8), 0.12, tool.Color, nil, false)
	Kit.cylZ(m, CN(0, 0.35, -2.0), 1.0, 0.42, DARK)
	Kit.cylZ(m, CN(0, 0.35, -2.55), 0.15, 0.5, tool.Color, { Neon = true })
	Kit.cylZ(m, CN(0, 0.35, -2.62), 0.05, 0.3, WHITE, { Neon = true })
	for _, z in { -0.9, -0.4 } do
		Kit.cylY(m, CN(0, 0.85, z), 0.3, 0.28, tool.Color, { Neon = true })
	end
	Kit.box(m, CN(0, 0.85, -1.3), Vector3.new(0.15, 0.25, 0.4), DARK)
end

B[6] = function(m, tool) -- Plasma Extractor
	handle(m, DARK)
	Kit.cylZ(m, CN(0, 0.1, -1.2), 1.6, 1.05, rgb(190, 235, 255), { Transparency = 0.3 })
	Kit.ball(m, CN(0, 0.1, -1.2), 0.75, tool.Color, { Neon = true })
	for _, z in { -0.4, -2.0 } do
		Kit.cylZ(m, CN(0, 0.1, z), 0.25, 1.2, STEEL)
	end
	Kit.cone(m, CN(0, 0.1, -2.1) * ANG(rad(-90), 0, 0), 0.9, 0.9, STEEL, 3)
	Kit.cylZ(m, CN(0, 0.1, -3.05), 0.15, 0.3, tool.Color, { Neon = true })
	Kit.ring(m, CN(0, 0.1, -1.2) * ANG(rad(90), 0, 0), 0.6, 0.1, tool.Color, 10, { Neon = true }, false)
end

B[7] = function(m, tool) -- Gravity Gun
	handle(m, DARK)
	Kit.roundBox(m, CN(0, 0.3, -0.8), Vector3.new(0.9, 0.9, 1.8), 0.35, rgb(60, 50, 90))
	Kit.cylZ(m, CN(0, 0.3, -2.0), 0.9, 0.35, STEEL)
	for i = 0, 2 do
		Kit.ring(m, CN(0, 0.3, -2.0 - i * 0.35) * ANG(rad(90), 0, 0), 0.5 + i * 0.12, 0.1, tool.Color, 10, { Neon = true }, false)
	end
	for i = 0, 2 do
		local prong = CN(0, 0.3, -1.8) * ANG(0, 0, i / 3 * math.pi * 2) * CN(0, 0.6, 0)
		Kit.box(m, prong * ANG(rad(-15), 0, 0), Vector3.new(0.14, 0.14, 1.4), DARK)
	end
	Kit.ball(m, CN(0, 0.3, -2.9), 0.45, tool.Color, { Neon = true })
end

B[8] = function(m, _tool) -- Quantum Vacuum
	handle(m, DARK)
	Kit.roundBox(m, CN(0, 0.55, 0.0), Vector3.new(1.2, 1.2, 1.5), 0.45, WHITE)
	Kit.box(m, CN(0, 0.55, -0.76), Vector3.new(0.7, 0.4, 0.05), rgb(120, 220, 255), { Neon = true })
	Kit.cylY(m, CN(0, 1.25, 0.1), 0.3, 0.6, GOLD)
	-- Hose made of rounded segments.
	for i = 0, 5 do
		Kit.ball(m, CN(0, 0.45 - i * 0.03, -0.75 - i * 0.28), 0.42, if i % 2 == 0 then DARK else Kit.shade(DARK, 0.2))
	end
	Kit.cone(m, CN(0, 0.3, -2.4) * ANG(rad(90), 0, 0), 0.8, 1.2, GOLD, 3)
	Kit.cylZ(m, CN(0, 0.3, -2.75), 0.12, 1.25, Kit.shade(GOLD, -0.2))
	for i = 0, 3 do
		Kit.cylZ(m, CN(0, 0.3, -2.8) * ANG(0, 0, i * math.pi / 2) * CN(0, 0.42, 0), 0.08, 0.2, Color3.fromHSV(i / 4, 0.6, 1), { Neon = true })
	end
	Kit.sparkle(Kit.ball(m, CN(0, 0.3, -2.8), 0.2, WHITE, { Neon = true }), rgb(200, 240, 255), 4)
end

function ToolArt.list(): { string }
	local names = {}
	for i in Tools do
		table.insert(names, tostring(i))
	end
	return names
end

-- `id` is the tool tier as a string ("1".."8") or a number.
function ToolArt.build(id: string | number): Model
	local tier = tonumber(id) or 1
	local tool = Tools[tier] or Tools[1]
	local model = Kit.model(nil, tool.Name)
	local builder = B[tier] or B[1]
	builder(model, tool)
	return model
end

return ToolArt
