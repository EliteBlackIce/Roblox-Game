--!strict
-- The 8 collection tools, modelled to match the pets: soft, toy-like forms that
-- melt into each other. Everything is capsules, balls and smooth rings; every
-- joint is covered by a ball so no hard seams or box corners show.
--
-- The grip part is named "Handle" and sits at the origin; the business end
-- points along -Z. ToolService welds every other part to an invisible handle.

local Kit = require(script.Parent.Kit)
local Tools = require(script.Parent.Parent.Tools)

local ToolArt = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local CN = CFrame.new
local ANG = CFrame.Angles
local V3 = Vector3.new
local rad = math.rad

local INK = rgb(52, 50, 66)
local STEEL = rgb(205, 212, 228)
local WOOD = rgb(196, 132, 80)
local GRIP = rgb(70, 66, 90)
local WHITE = rgb(250, 250, 255)
local GOLD = rgb(255, 208, 64)

-- Squishy capsule grip with soft ring bands and a round pommel.
local function handle(m: Model, color: Color3): Part
	local grip = Kit.cyl(m, CN(0, 0, 0.2) * ANG(0, rad(90), 0), 1.2, 0.5, color, { Name = "Handle" })
	Kit.ball(m, CN(0, 0, -0.4), 0.5, color)
	for _, z in { -0.15, 0.25, 0.65 } do
		Kit.ring(m, CN(0, 0, z) * ANG(rad(90), 0, 0), 0.25, 0.14, Kit.shade(color, 0.18), 10)
	end
	Kit.ball(m, CN(0, 0, 0.9), 0.66, Kit.shade(color, -0.1))
	return grip
end

-- Shaft from the grip forward to `tipZ`, with a ball collar where it meets the grip.
local function shaft(m: Model, tipZ: number, diameter: number, color: Color3)
	Kit.ball(m, CN(0, 0, -0.55), diameter * 1.6, Kit.shade(color, -0.15))
	Kit.pillBetween(m, V3(0, 0, -0.55), V3(0, 0, tipZ), diameter, color)
end

-- A curved prong: three capsules joined smoothly, bending inward at the tip.
local function prong(m: Model, base: Vector3, outward: Vector3, length: number, diameter: number, color: Color3)
	local p0 = base
	local p1 = p0 + outward * length * 0.35 + V3(0, 0, -length * 0.35)
	local p2 = p1 + outward * length * 0.1 + V3(0, 0, -length * 0.35)
	local p3 = p2 - outward * length * 0.3 + V3(0, 0, -length * 0.25)
	Kit.pillBetween(m, p0, p1, diameter, color)
	Kit.pillBetween(m, p1, p2, diameter * 0.9, color)
	Kit.pillBetween(m, p2, p3, diameter * 0.8, color)
	Kit.ball(m, CN(p3), diameter * 0.95, Kit.shade(color, 0.15))
end

local function claw(m: Model, at: Vector3, color: Color3, prongs: number, size: number)
	Kit.ball(m, CN(at), 0.85 * size, Kit.shade(color, -0.12))
	for i = 0, prongs - 1 do
		local a = i / prongs * math.pi * 2 + (if prongs == 2 then math.pi / 2 else 0)
		local outward = V3(math.cos(a), math.sin(a), 0)
		prong(m, at + outward * 0.2 * size, outward, 1.3 * size, 0.24 * size, color)
	end
end

type Builder = (m: Model, tool: Tools.Tool) -> ()
local B: { [number]: Builder } = {}

B[1] = function(m, tool) -- Rusty Grabber: a wooden pole with a two-finger claw
	handle(m, WOOD)
	shaft(m, -2.7, 0.3, WOOD)
	Kit.ring(m, CN(0, 0, -1.6) * ANG(rad(90), 0, 0), 0.18, 0.12, rgb(150, 90, 60), 10)
	Kit.pillBetween(m, V3(0, -0.3, 0.15), V3(0, -0.6, -0.1), 0.2, rgb(150, 90, 60))
	claw(m, V3(0, 0, -2.8), tool.Color, 2, 1.25)
end

B[2] = function(m, tool) -- Steel Grabber: three-finger claw and a red trigger
	handle(m, GRIP)
	shaft(m, -2.8, 0.3, tool.Color)
	for _, z in { -1.2, -2.2 } do
		Kit.ring(m, CN(0, 0, z) * ANG(rad(90), 0, 0), 0.18, 0.14, Kit.shade(tool.Color, -0.25), 10)
	end
	Kit.pillBetween(m, V3(0, -0.3, 0.15), V3(0, -0.62, -0.12), 0.22, rgb(235, 80, 80))
	claw(m, V3(0, 0, -2.95), tool.Color, 3, 1.2)
end

B[3] = function(m, tool) -- Magnet Claw: a big soft horseshoe magnet
	handle(m, GRIP)
	shaft(m, -1.9, 0.32, STEEL)
	local base = V3(0, 0, -2.0)
	-- The horseshoe: a smooth arc of capsules (bend nearest the shaft), arms
	-- reaching forward with silver tips.
	local prev = nil
	for i = 0, 8 do
		local a = math.pi * i / 8
		local point = base + V3(-math.cos(a) * 0.6, 0, math.sin(a) * 0.35 - 0.35)
		if prev then
			Kit.pillBetween(m, prev, point, 0.5, tool.Color)
		end
		prev = point
	end
	for _, side in { -1, 1 } do
		local top = base + V3(side * 0.6, 0, -0.35)
		local tip = top + V3(0, 0, -0.85)
		Kit.pillBetween(m, top, tip, 0.5, tool.Color)
		Kit.pillBetween(m, tip, tip + V3(0, 0, -0.3), 0.52, STEEL)
	end
	Kit.ball(m, CN(base + V3(0, 0, -1.3)), 0.25, rgb(140, 220, 255), { Neon = true })
end

B[4] = function(m, tool) -- Hydraulic Claw: chunky yellow pistons and big jaws
	handle(m, GRIP)
	Kit.pill(m, CN(0, 0.05, -0.95) * ANG(0, rad(90), 0), 1.5, 0.75, tool.Color)
	shaft(m, -2.4, 0.34, STEEL)
	for _, side in { -1, 1 } do
		Kit.pillBetween(m, V3(side * 0.32, 0.2, -1.2), V3(side * 0.32, 0.2, -2.3), 0.22, INK)
		Kit.pillBetween(m, V3(side * 0.32, 0.2, -2.3), V3(side * 0.32, 0.18, -2.7), 0.14, STEEL)
	end
	Kit.ball(m, CN(0, 0.4, -0.95), 0.26, rgb(235, 80, 80), { Neon = true })
	Kit.pill(m, CN(0, 0, -2.75), 1.2, 0.6, tool.Color)
	claw(m, V3(0, 0, -2.85), INK, 2, 1.35)
end

B[5] = function(m, tool) -- Laser Cutter: a rounded toy blaster
	handle(m, INK)
	Kit.pill(m, CN(0, 0.38, -0.7) * ANG(0, rad(90), 0), 2.2, 0.85, WHITE)
	Kit.ring(m, CN(0, 0.38, -0.7) * ANG(rad(90), 0, 0), 0.43, 0.16, tool.Color, 12)
	Kit.ring(m, CN(0, 0.38, -1.2) * ANG(rad(90), 0, 0), 0.4, 0.12, tool.Color, 12)
	Kit.pillBetween(m, V3(0, 0.38, -1.6), V3(0, 0.38, -2.4), 0.42, INK)
	Kit.ring(m, CN(0, 0.38, -2.45) * ANG(rad(90), 0, 0), 0.22, 0.14, tool.Color, 10, { Neon = true })
	Kit.ball(m, CN(0, 0.38, -2.5), 0.3, WHITE, { Neon = true })
	for _, z in { -0.95, -0.45 } do
		Kit.ball(m, CN(0, 0.82, z), 0.3, tool.Color, { Neon = true })
	end
end

B[6] = function(m, tool) -- Plasma Extractor: a glowing canister with a nozzle
	handle(m, INK)
	Kit.pill(m, CN(0, 0.1, -1.25) * ANG(0, rad(90), 0), 1.8, 1.05, rgb(200, 240, 255), { Transparency = 0.35 })
	Kit.ball(m, CN(0, 0.1, -1.25), 0.72, tool.Color, { Neon = true })
	for _, z in { -0.55, -1.95 } do
		Kit.ring(m, CN(0, 0.1, z) * ANG(rad(90), 0, 0), 0.5, 0.2, STEEL, 12)
	end
	Kit.pillBetween(m, V3(0, 0.1, -2.1), V3(0, 0.1, -2.75), 0.55, STEEL)
	Kit.pillBetween(m, V3(0, 0.1, -2.75), V3(0, 0.1, -3.05), 0.3, STEEL)
	Kit.ball(m, CN(0, 0.1, -3.1), 0.28, tool.Color, { Neon = true })
end

B[7] = function(m, tool) -- Gravity Gun: a purple orb launcher with floating rings
	handle(m, INK)
	Kit.ball(m, CN(0, 0.3, -0.75), 1.15, rgb(110, 80, 170))
	Kit.pillBetween(m, V3(0, 0.3, -0.75), V3(0, 0.3, -1.9), 0.55, rgb(110, 80, 170))
	for i = 0, 2 do
		Kit.ring(m, CN(0, 0.3, -2.0 - i * 0.38) * ANG(rad(90), 0, 0), 0.45 + i * 0.12, 0.12, tool.Color, 12, { Neon = true })
	end
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		local base = V3(math.cos(a) * 0.35, 0.3 + math.sin(a) * 0.35, -1.6)
		Kit.pillBetween(m, base, base + V3(math.cos(a) * 0.25, math.sin(a) * 0.25, -1.0), 0.16, INK)
	end
	Kit.ball(m, CN(0, 0.3, -2.95), 0.5, tool.Color, { Neon = true })
end

B[8] = function(m, _tool) -- Quantum Vacuum: a pearly tank, bendy hose, golden nozzle
	handle(m, INK)
	Kit.pill(m, CN(0, 0.6, 0.05) * ANG(0, rad(90), 0), 1.6, 1.25, WHITE)
	Kit.ring(m, CN(0, 0.6, 0.05) * ANG(rad(90), 0, 0), 0.62, 0.14, GOLD, 12)
	Kit.ball(m, CN(0, 1.25, 0.1), 0.42, GOLD)
	Kit.ball(m, CN(0, 0.6, -0.68), 0.35, rgb(130, 220, 255), { Neon = true })
	local prev = V3(0, 0.45, -0.7)
	for i = 1, 6 do
		local point = V3(math.sin(i * 0.9) * 0.08, 0.45 - i * 0.03, -0.7 - i * 0.26)
		Kit.pillBetween(m, prev, point, 0.38, if i % 2 == 0 then INK else Kit.shade(INK, 0.25))
		prev = point
	end
	-- Flared golden nozzle built from widening rings.
	for i = 0, 3 do
		Kit.ring(m, CN(0, 0.3, -2.35 - i * 0.18) * ANG(rad(90), 0, 0), 0.25 + i * 0.12, 0.16, GOLD, 12)
	end
	for i = 0, 3 do
		Kit.ball(m, CN(0, 0.3, -2.85) * ANG(0, 0, i * math.pi / 2) * CN(0, 0.38, 0), 0.16, Color3.fromHSV(i / 4, 0.55, 1), { Neon = true })
	end
	Kit.sparkle(Kit.ball(m, CN(0, 0.3, -2.8), 0.1, WHITE, { Transparency = 1 }), rgb(200, 240, 255), 4)
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
