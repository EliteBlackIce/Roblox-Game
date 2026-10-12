--!strict
-- 3D models for all 42 scrap items. Each model is built around the origin,
-- roughly 3 studs across, and faces -Z. Used on scrap piles, as the pickup that
-- flies to you, and in the Index / sale UI viewports.

local Kit = require(script.Parent.Kit)
local Zones = require(script.Parent.Parent.Zones)

local Items = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local STEEL = rgb(185, 192, 205)
local DARK = rgb(55, 58, 68)
local BLACK = rgb(30, 30, 38)
local WHITE = rgb(245, 245, 250)
local GOLD = rgb(255, 200, 50)
local COPPER = rgb(225, 125, 60)
local BRASS = rgb(215, 170, 70)
local WOOD = rgb(160, 105, 60)
local CN = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

type Builder = (m: Model) -> ()
local B: { [string]: Builder } = {}

---------------------------------------------------------------- Scrap Heap

B.BentNail = function(m)
	local tilt = ANG(0, 0, rad(-20))
	Kit.cylY(m, tilt * CN(0, 0.6, 0), 1.6, 0.36, STEEL)
	Kit.ball(m, tilt * CN(0, -0.2, 0), 0.36, STEEL)
	local bent = tilt * CN(0, -0.2, 0) * ANG(0, 0, rad(55))
	Kit.cylY(m, bent * CN(0, -0.55, 0), 1.1, 0.36, STEEL)
	Kit.cone(m, bent * CN(0, -1.1, 0) * ANG(rad(180), 0, 0), 0.45, 0.36, STEEL, 3)
	Kit.cylY(m, tilt * CN(0, 1.45, 0), 0.22, 1.0, Kit.shade(STEEL, 0.15))
end

B.TinCan = function(m)
	local label = rgb(220, 60, 60)
	Kit.cylY(m, CN(0, 0, 0), 2.0, 1.6, STEEL)
	Kit.cylY(m, CN(0, 0, 0), 1.1, 1.66, label)
	Kit.cylY(m, CN(0, 0, 0), 0.25, 1.68, WHITE)
	Kit.ring(m, CN(0, 1.0, 0), 0.8, 0.14, Kit.shade(STEEL, 0.2), 10, nil, false)
	Kit.ring(m, CN(0, -1.0, 0), 0.8, 0.14, Kit.shade(STEEL, -0.1), 10, nil, false)
	Kit.cylY(m, CN(0, 1.0, 0), 0.04, 1.45, DARK)
	-- Peeled-back lid.
	Kit.cylY(m, CN(0.45, 1.25, 0.2) * ANG(0, 0, rad(-50)), 0.06, 1.3, Kit.shade(STEEL, 0.25))
end

B.CopperWire = function(m)
	for i = 0, 3 do
		Kit.ring(m, CN(0, -0.6 + i * 0.38, 0) * ANG(rad(6), i * 0.4, 0), 0.85, 0.28, if i % 2 == 0 then COPPER else Kit.shade(COPPER, 0.15), 9, nil, false)
	end
	Kit.cylY(m, CN(0, 0, 0), 1.3, 0.75, Kit.shade(COPPER, -0.45))
	Kit.pill(m, CN(0.95, 0.9, -0.2) * ANG(0, rad(30), rad(40)), 1.4, 0.24, COPPER)
end

B.OldBattery = function(m)
	local green = rgb(70, 200, 110)
	Kit.cylY(m, CN(0, 0, 0), 2.2, 1.2, green)
	Kit.cylY(m, CN(0, 0.75, 0), 0.7, 1.24, BLACK)
	Kit.cylY(m, CN(0, -1.15, 0), 0.15, 1.18, STEEL)
	Kit.cylY(m, CN(0, 1.18, 0), 0.18, 1.16, STEEL)
	Kit.cylY(m, CN(0, 1.35, 0), 0.22, 0.45, STEEL)
	Kit.box(m, CN(0, 0.75, -0.63), Vector3.new(0.45, 0.12, 0.04), WHITE, { Neon = true })
	Kit.box(m, CN(0, 0.75, -0.63), Vector3.new(0.12, 0.45, 0.04), WHITE, { Neon = true })
	Kit.cylY(m, CN(0, -0.3, 0), 0.08, 1.23, Kit.shade(green, 0.35))
end

local function spring(m: Model, color: Color3, coils: number)
	for i = 0, coils - 1 do
		Kit.ring(m, CN(0, -0.9 + i * 0.42, 0) * ANG(rad(8), 0, rad(if i % 2 == 0 then 4 else -4)), 0.7, 0.22, color, 9, nil, false)
	end
	Kit.cylY(m, CN(0, -1.05, 0), 0.12, 1.6, Kit.shade(color, -0.2))
	Kit.cylY(m, CN(0, -0.9 + coils * 0.42, 0), 0.12, 1.6, Kit.shade(color, -0.2))
end

B.GoldenSpring = function(m)
	spring(m, GOLD, 5)
	Kit.sparkle(Kit.ball(m, CN(0, 0.1, 0), 0.4, rgb(255, 240, 150), { Neon = true }), GOLD)
end

B.AncientGear = function(m)
	local bronze = rgb(230, 150, 60)
	Kit.gear(m, CN(0, 0.2, 0) * ANG(0, rad(90), 0), 1.3, 0.45, 10, bronze, Kit.shade(bronze, -0.3))
	Kit.gear(m, CN(0.95, -0.75, 0.35) * ANG(0, rad(90), rad(18)), 0.7, 0.35, 7, Kit.shade(bronze, -0.15), DARK)
	Kit.cylZ(m, CN(0, 0.2, 0), 0.6, 0.55, rgb(120, 230, 255), { Neon = true })
	for i = 0, 3 do
		Kit.ball(m, CN(0, 0.2, 0) * ANG(0, 0, i * math.pi / 2) * CN(0, 0.75, -0.25), 0.18, Kit.shade(bronze, 0.3))
	end
end

B.GoldenRobotHead = function(m)
	Kit.roundBox(m, CN(0, 0, 0), Vector3.new(2.4, 2.0, 2.0), 0.45, GOLD)
	Kit.eye(m, CN(-0.5, 0.2, -0.95), 0.62, rgb(40, 180, 255))
	Kit.eye(m, CN(0.5, 0.2, -0.95), 0.62, rgb(40, 180, 255))
	for i = -1, 1 do
		Kit.box(m, CN(i * 0.3, -0.5, -1.0), Vector3.new(0.16, 0.3, 0.1), Kit.shade(GOLD, -0.4))
	end
	for _, x in { -1.25, 1.25 } do
		Kit.cyl(m, CN(x, 0.1, 0), 0.3, 0.7, Kit.shade(GOLD, -0.2))
	end
	Kit.cylY(m, CN(0, 1.3, 0), 0.6, 0.14, Kit.shade(GOLD, -0.2))
	Kit.sparkle(Kit.ball(m, CN(0, 1.7, 0), 0.38, rgb(255, 80, 80), { Neon = true }), GOLD, 4)
end

---------------------------------------------------------------- Car Graveyard

B.Hubcap = function(m)
	local face = ANG(0, rad(90), 0) -- local +X now points at the viewer (-Z)
	Kit.cyl(m, face, 0.3, 2.6, Kit.shade(STEEL, -0.1))
	Kit.cyl(m, face * CN(0.08, 0, 0), 0.25, 2.25, Kit.shade(STEEL, 0.2))
	for i = 0, 4 do
		Kit.box(m, face * ANG(i / 5 * math.pi * 2, 0, 0) * CN(0.24, 0.62, 0), Vector3.new(0.12, 0.85, 0.32), Kit.shade(STEEL, -0.25))
	end
	Kit.cyl(m, face * CN(0.26, 0, 0), 0.25, 0.75, DARK)
	Kit.cyl(m, face * CN(0.36, 0, 0), 0.12, 0.45, rgb(220, 70, 60))
	for i = 0, 4 do
		Kit.ball(m, face * ANG(i / 5 * math.pi * 2 + 0.6, 0, 0) * CN(0.2, 0.55, 0), 0.16, DARK)
	end
end

B.SparkPlug = function(m)
	Kit.cylY(m, CN(0, 0.45, 0), 1.3, 0.75, WHITE)
	Kit.cylY(m, CN(0, 1.2, 0), 0.25, 0.38, STEEL)
	Kit.cylY(m, CN(0, 1.4, 0), 0.18, 0.5, STEEL)
	Kit.box(m, CN(0, -0.35, 0), Vector3.new(0.95, 0.38, 0.95), STEEL)
	Kit.box(m, CN(0, -0.35, 0) * ANG(0, rad(45), 0), Vector3.new(0.95, 0.38, 0.95), STEEL)
	for i = 0, 3 do
		Kit.cylY(m, CN(0, -0.65 - i * 0.16, 0), 0.08, 0.62, Kit.shade(STEEL, -0.2))
	end
	Kit.cylY(m, CN(0, -0.85, 0), 0.5, 0.5, Kit.shade(STEEL, 0.1))
	Kit.box(m, CN(0.12, -1.18, 0), Vector3.new(0.32, 0.1, 0.12), STEEL)
end

B.CarBattery = function(m)
	local body = rgb(50, 52, 62)
	Kit.roundBox(m, CN(0, 0, 0), Vector3.new(2.6, 1.6, 1.6), 0.25, body)
	Kit.box(m, CN(0, 0.85, 0), Vector3.new(2.3, 0.12, 1.3), Kit.shade(body, 0.15))
	Kit.cylY(m, CN(-0.8, 1.05, 0), 0.3, 0.4, rgb(230, 60, 60))
	Kit.cylY(m, CN(0.8, 1.05, 0), 0.3, 0.4, BLACK)
	Kit.box(m, CN(0, 0.05, -0.81), Vector3.new(1.8, 0.55, 0.05), rgb(250, 200, 50))
	Kit.box(m, CN(-0.45, 0.05, -0.84), Vector3.new(0.3, 0.08, 0.02), BLACK)
	Kit.box(m, CN(-0.45, 0.05, -0.84), Vector3.new(0.08, 0.3, 0.02), BLACK)
	Kit.box(m, CN(0.45, 0.05, -0.84), Vector3.new(0.3, 0.08, 0.02), BLACK)
end

B.ChromeBumper = function(m)
	local chrome = rgb(215, 225, 240)
	local radius = 2.4
	local joints = {}
	for i = -2, 2 do
		local a = i / 2 * rad(38)
		table.insert(joints, Vector3.new(math.sin(a) * radius, 0, (1 - math.cos(a)) * radius))
	end
	for i = 1, #joints - 1 do
		local a, b = joints[i], joints[i + 1]
		local mid = (a + b) / 2
		Kit.cyl(m, CFrame.lookAt(mid, b) * ANG(0, rad(90), 0), (b - a).Magnitude, 0.62, chrome)
	end
	for _, j in joints do
		Kit.ball(m, CFrame.new(j), 0.62, chrome)
	end
	Kit.box(m, CN(0, -0.12, 0.05), Vector3.new(2.6, 0.22, 0.4), Kit.shade(chrome, -0.25))
	Kit.roundBox(m, CN(0, -0.05, -0.33), Vector3.new(1.0, 0.45, 0.08), 0.06, rgb(250, 220, 80), nil, false)
	Kit.box(m, CN(0, -0.05, -0.38), Vector3.new(0.7, 0.1, 0.02), DARK)
	for _, x in { -0.8, 0.8 } do
		Kit.ball(m, CN(x, 0.05, -0.28), 0.16, DARK)
	end
end

B.V8Engine = function(m)
	local red = rgb(210, 55, 55)
	Kit.roundBox(m, CN(0, -0.3, 0), Vector3.new(1.8, 1.2, 2.4), 0.2, DARK)
	for _, side in { -1, 1 } do
		local bank = CN(side * 0.65, 0.45, 0) * ANG(0, 0, rad(side * -35))
		Kit.roundBox(m, bank, Vector3.new(0.6, 0.6, 2.3), 0.15, red, nil, false)
		for z = -0.75, 0.75, 0.5 do
			Kit.cylY(m, bank * CN(0, 0.35, z), 0.15, 0.24, STEEL)
		end
	end
	Kit.roundBox(m, CN(0, 0.75, 0), Vector3.new(0.7, 0.4, 1.9), 0.15, Kit.shade(red, -0.2), nil, false)
	Kit.cylY(m, CN(0, 1.15, 0.2), 0.3, 1.1, STEEL)
	Kit.cylY(m, CN(0, 1.32, 0.2), 0.08, 0.6, Kit.shade(STEEL, 0.25))
	Kit.cylZ(m, CN(0, -0.2, -1.25), 0.2, 0.9, STEEL)
	Kit.cylZ(m, CN(0, 0.4, -1.25), 0.18, 0.5, BLACK)
end

B.HoodOrnament = function(m)
	Kit.cylY(m, CN(0, -1.0, 0), 0.3, 1.2, Kit.shade(GOLD, -0.3))
	Kit.cylY(m, CN(0, -0.78, 0), 0.2, 0.7, GOLD)
	Kit.cylY(m, CN(0, -0.35, 0), 0.75, 0.22, GOLD)
	Kit.ball(m, CN(0, 0.15, 0), 0.6, Kit.shade(GOLD, 0.1))
	Kit.cone(m, CN(0, 0.15, -0.25) * ANG(rad(-90), 0, 0), 0.5, 0.35, GOLD, 3)
	for _, side in { -1, 1 } do
		for i = 0, 2 do
			Kit.box(
				m,
				CN(side * (0.45 + i * 0.32), 0.25 + i * 0.12, 0.12 + i * 0.12) * ANG(0, rad(side * -18), rad(side * 14)),
				Vector3.new(0.5, 0.1, 0.55 - i * 0.12),
				Kit.shade(GOLD, 0.05 + i * 0.1)
			)
		end
	end
	Kit.sparkle(Kit.ball(m, CN(0, 0.15, 0), 0.2, GOLD, { Neon = true }), GOLD, 3)
end

B.DiamondWheel = function(m)
	local ice = rgb(150, 240, 255)
	local face = ANG(rad(90), 0, 0)
	Kit.ring(m, face, 1.25, 0.34, rgb(230, 235, 250), 14)
	for i = 0, 2 do
		Kit.box(m, ANG(0, 0, rad(90 + i * 120)) * CN(0.65, 0, 0), Vector3.new(1.2, 0.24, 0.16), rgb(205, 210, 228))
	end
	Kit.cylZ(m, CN(0, 0, 0.05), 0.25, 0.75, rgb(205, 210, 228))
	Kit.box(m, CN(0, 0, -0.2) * ANG(rad(45), rad(45), 0), Vector3.new(0.6, 0.6, 0.6), ice, { Neon = true })
	for i = 0, 5 do
		Kit.ball(m, ANG(0, 0, i / 6 * math.pi * 2) * CN(1.25, 0, -0.15), 0.22, ice, { Neon = true })
	end
	Kit.sparkle(Kit.ball(m, CN(0, 0, -0.2), 0.2, ice, { Neon = true }), ice, 5)
end

---------------------------------------------------------------- Appliance Alley

local function toaster(m: Model, body: Color3, toast: Color3, glow: boolean)
	Kit.roundBox(m, CN(0, 0, 0), Vector3.new(2.4, 1.6, 1.4), 0.4, body)
	for _, x in { -0.45, 0.45 } do
		Kit.box(m, CN(x, 0.81, 0), Vector3.new(0.32, 0.04, 0.95), DARK)
		Kit.roundBox(m, CN(x, 1.05, 0), Vector3.new(0.24, 0.6, 0.85), 0.1, toast, { Neon = glow }, false)
	end
	Kit.box(m, CN(1.24, 0.1, 0), Vector3.new(0.12, 0.6, 0.12), Kit.shade(body, -0.3))
	Kit.box(m, CN(1.32, 0.35, 0), Vector3.new(0.18, 0.12, 0.4), BLACK)
	Kit.cylZ(m, CN(-0.6, -0.3, -0.71), 0.08, 0.35, BLACK)
	for _, x in { -0.9, 0.9 } do
		Kit.cylY(m, CN(x, -0.85, 0), 0.12, 0.25, BLACK)
	end
end

B.Toaster = function(m)
	toaster(m, rgb(220, 225, 235), rgb(215, 160, 90), false)
end

B.MicrowaveDoor = function(m)
	Kit.roundBox(m, CN(0, 0, 0), Vector3.new(2.6, 1.7, 0.3), 0.12, DARK)
	Kit.box(m, CN(-0.25, 0, -0.12), Vector3.new(1.8, 1.25, 0.12), rgb(120, 160, 190))
	for x = -0.9, 0.4, 0.26 do
		for y = -0.45, 0.45, 0.3 do
			Kit.box(m, CN(x, y, -0.19), Vector3.new(0.1, 0.1, 0.02), Kit.shade(rgb(120, 160, 190), -0.25))
		end
	end
	Kit.box(m, CN(1.05, 0, -0.25), Vector3.new(0.14, 1.3, 0.22), STEEL)
end

B.FridgeCoil = function(m)
	local pipe = rgb(120, 200, 230)
	Kit.box(m, CN(0, 0, 0.15), Vector3.new(2.3, 2.2, 0.1), DARK)
	for i = 0, 4 do
		local x = -0.9 + i * 0.45
		Kit.cylY(m, CN(x, 0, 0), 1.6, 0.2, pipe)
		Kit.ball(m, CN(x, if i % 2 == 0 then 0.8 else -0.8, 0), 0.2, pipe)
		if i < 4 then
			Kit.cyl(m, CN(x + 0.225, if i % 2 == 0 then 0.8 else -0.8, 0), 0.45, 0.2, pipe)
		end
	end
	for _, y in { -0.4, 0, 0.4 } do
		Kit.box(m, CN(0, y, 0.05), Vector3.new(2.1, 0.06, 0.08), Kit.shade(DARK, 0.3))
	end
end

B.WasherDrum = function(m)
	local face = ANG(0, rad(90), 0) -- local +X points at the viewer
	local drum = rgb(205, 215, 225)
	Kit.cyl(m, face, 1.8, 2.3, drum)
	Kit.cyl(m, face * CN(0.88, 0, 0), 0.08, 1.85, Kit.shade(drum, -0.45))
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		Kit.cyl(m, face * CN(0.92, math.cos(a) * 0.62, math.sin(a) * 0.62), 0.04, 0.2, Kit.shade(drum, 0.1))
	end
	for i = 0, 2 do
		Kit.box(m, face * ANG(i / 3 * math.pi * 2, 0, 0) * CN(0.92, 0.72, 0), Vector3.new(0.18, 0.35, 0.45), Kit.shade(drum, 0.25))
	end
	Kit.cyl(m, face * CN(0.93, 0, 0), 0.04, 0.4, DARK)
	Kit.ring(m, CN(0, 0, -0.92) * ANG(rad(90), 0, 0), 1.08, 0.22, STEEL, 12, nil, false)
	for x = -0.5, 0.5, 0.5 do
		Kit.ring(m, CN(x, 0, 0) * ANG(0, 0, rad(90)), 1.15, 0.08, Kit.shade(drum, -0.15), 12, nil, false)
	end
end

B.RetroTV = function(m)
	local pink = rgb(255, 140, 175)
	Kit.roundBox(m, CN(0, 0.1, 0), Vector3.new(2.6, 2.0, 1.6), 0.35, pink)
	Kit.roundBox(m, CN(-0.3, 0.12, -0.72), Vector3.new(1.6, 1.4, 0.3), 0.2, DARK, nil, false)
	Kit.box(m, CN(-0.3, 0.12, -0.88), Vector3.new(1.35, 1.15, 0.05), rgb(110, 230, 255), { Neon = true })
	for _, y in { 0.45, -0.05 } do
		Kit.cylZ(m, CN(0.85, y, -0.82), 0.12, 0.32, Kit.shade(pink, -0.4))
	end
	Kit.box(m, CN(0.85, -0.5, -0.81), Vector3.new(0.4, 0.3, 0.04), Kit.shade(pink, -0.25))
	for _, x in { -0.9, 0.9 } do
		Kit.box(m, CN(x, -1.05, 0), Vector3.new(0.15, 0.3, 0.15), DARK)
	end
	for _, side in { -1, 1 } do
		Kit.cylY(m, CN(side * 0.35, 1.5, 0.2) * ANG(0, 0, rad(-side * 28)), 0.9, 0.08, DARK)
		Kit.ball(m, CN(side * 0.57, 1.92, 0.2), 0.16, DARK)
	end
end

B.GoldenToaster = function(m)
	toaster(m, GOLD, rgb(255, 230, 150), true)
	Kit.sparkle(Kit.ball(m, CN(0, 1.3, 0), 0.2, GOLD, { Neon = true }), GOLD, 5)
end

B.PlatinumBlender = function(m)
	local plat = rgb(230, 238, 255)
	Kit.roundBox(m, CN(0, -0.9, 0), Vector3.new(1.4, 0.8, 1.4), 0.25, Kit.shade(plat, -0.15))
	Kit.cylZ(m, CN(0, -0.9, -0.71), 0.06, 0.3, rgb(255, 80, 120), { Neon = true })
	Kit.cylY(m, CN(0, 0.2, 0), 1.5, 1.05, rgb(190, 230, 255), { Transparency = 0.35 })
	Kit.cylY(m, CN(0, -0.1, 0), 0.7, 0.95, rgb(255, 120, 170), { Transparency = 0.2 })
	Kit.cylY(m, CN(0, 1.0, 0), 0.18, 1.12, plat)
	Kit.cylY(m, CN(0, 1.15, 0), 0.15, 0.4, plat)
	Kit.box(m, CN(0.62, 0.3, 0), Vector3.new(0.14, 0.9, 0.3), plat)
	Kit.sparkle(Kit.ball(m, CN(0, 0.4, 0), 0.25, plat, { Neon = true }), plat, 5)
end

---------------------------------------------------------------- Electronics Dump

B.Keyboard = function(m)
	local base = rgb(230, 230, 225)
	Kit.roundBox(m, CN(0, 0, 0) * ANG(rad(-8), 0, 0), Vector3.new(3.0, 0.35, 1.3), 0.12, base, nil, false)
	local tilt = ANG(rad(-8), 0, 0)
	local keyColors = { rgb(90, 95, 110), rgb(90, 95, 110), rgb(90, 95, 110), rgb(240, 120, 80) }
	for row = 0, 2 do
		for col = 0, 6 do
			local color = if row == 0 and col == 6 then keyColors[4] else keyColors[1]
			Kit.box(m, tilt * CN(-1.15 + col * 0.38, 0.24, -0.38 + row * 0.38), Vector3.new(0.3, 0.14, 0.3), color)
		end
	end
	Kit.box(m, tilt * CN(0, 0.24, 0.4 + 0.36), Vector3.new(1.4, 0.14, 0.26), keyColors[1])
end

B.CircuitBoard = function(m)
	local green = rgb(40, 160, 80)
	Kit.box(m, CN(0, 0, 0), Vector3.new(2.6, 0.15, 2.0), green)
	Kit.box(m, CN(-0.5, 0.17, -0.2), Vector3.new(0.8, 0.2, 0.8), BLACK)
	Kit.box(m, CN(0.7, 0.14, 0.4), Vector3.new(0.5, 0.15, 0.4), BLACK)
	for i = 0, 2 do
		Kit.cylY(m, CN(0.7 + i * 0.22 - 0.2, 0.3, -0.55), 0.45, 0.2, if i == 1 then rgb(70, 130, 230) else DARK)
	end
	for _, line in { { -1.1, 0.5, 2.0 }, { 0.1, -0.7, 1.4 }, { -0.4, 0.75, 1.2 } } do
		Kit.box(m, CN(line[1] + line[3] / 2, 0.085, line[2]), Vector3.new(line[3], 0.02, 0.06), GOLD, { Neon = true })
	end
	for _, x in { -1.15, 1.15 } do
		for _, z in { -0.85, 0.85 } do
			Kit.cylY(m, CN(x, 0.09, z), 0.04, 0.16, STEEL)
		end
	end
end

B.HardDrive = function(m)
	local body = rgb(150, 155, 165)
	Kit.roundBox(m, CN(0, 0, 0), Vector3.new(2.0, 0.4, 2.6), 0.12, body, nil, false)
	Kit.cylY(m, CN(-0.1, 0.22, 0.3), 0.05, 1.6, Kit.shade(STEEL, 0.35))
	Kit.cylY(m, CN(-0.1, 0.25, 0.3), 0.05, 0.4, DARK)
	Kit.box(m, CN(0.45, 0.27, -0.25) * ANG(0, rad(-35), 0), Vector3.new(0.18, 0.06, 1.2), DARK)
	Kit.cylY(m, CN(0.65, 0.27, -0.75), 0.1, 0.3, DARK)
	for _, x in { -0.85, 0.85 } do
		for _, z in { -1.15, 1.15 } do
			Kit.cylY(m, CN(x, 0.21, z), 0.04, 0.14, DARK)
		end
	end
	Kit.box(m, CN(0, 0, -1.31), Vector3.new(1.2, 0.18, 0.04), GOLD)
end

B.GraphicsCard = function(m)
	local shroud = rgb(45, 47, 58)
	Kit.box(m, CN(0, -0.3, 0), Vector3.new(3.0, 0.12, 1.4), rgb(30, 110, 60))
	Kit.roundBox(m, CN(0, 0, 0), Vector3.new(3.0, 0.5, 1.3), 0.15, shroud, nil, false)
	for _, x in { -0.75, 0.75 } do
		Kit.cylY(m, CN(x, 0.27, 0), 0.05, 1.05, BLACK)
		for i = 0, 4 do
			Kit.box(m, CN(x, 0.3, 0) * ANG(0, i / 5 * math.pi * 2 + 0.3, 0) * CN(0, 0, -0.25), Vector3.new(0.18, 0.04, 0.45), DARK)
		end
		Kit.cylY(m, CN(x, 0.33, 0), 0.05, 0.3, rgb(220, 60, 60))
	end
	Kit.box(m, CN(0, 0.0, -0.66), Vector3.new(2.8, 0.08, 0.04), rgb(255, 60, 200), { Neon = true })
	Kit.box(m, CN(-0.6, -0.42, 0.55), Vector3.new(1.4, 0.14, 0.12), GOLD)
end

B.ServerRack = function(m)
	local body = rgb(40, 42, 52)
	Kit.roundBox(m, CN(0, 0, 0), Vector3.new(1.6, 3.0, 1.4), 0.15, body, nil, false)
	for i = 0, 4 do
		local y = -1.1 + i * 0.55
		Kit.box(m, CN(0, y, -0.71), Vector3.new(1.35, 0.42, 0.05), Kit.shade(body, 0.12))
		Kit.box(m, CN(-0.45, y, -0.75), Vector3.new(0.12, 0.12, 0.03), if i % 2 == 0 then rgb(70, 255, 150) else rgb(70, 200, 255), { Neon = true })
		Kit.box(m, CN(0.25, y, -0.75), Vector3.new(0.7, 0.06, 0.03), rgb(70, 200, 255), { Neon = true })
	end
	Kit.box(m, CN(0, 1.55, 0), Vector3.new(1.65, 0.1, 1.45), Kit.shade(body, 0.2))
end

B.QuantumChip = function(m)
	local purple = rgb(160, 90, 255)
	Kit.roundBox(m, CN(0, 0, 0), Vector3.new(2.0, 0.35, 2.0), 0.1, BLACK, nil, false)
	for i = 0, 4 do
		local o = -0.8 + i * 0.4
		for _, side in { -1, 1 } do
			Kit.box(m, CN(o, -0.1, side * 1.1), Vector3.new(0.14, 0.1, 0.3), GOLD)
			Kit.box(m, CN(side * 1.1, -0.1, o), Vector3.new(0.3, 0.1, 0.14), GOLD)
		end
	end
	Kit.box(m, CN(0, 0.19, 0), Vector3.new(1.2, 0.05, 1.2), Kit.shade(purple, -0.5))
	Kit.ball(m, CN(0, 0.55, 0), 0.75, purple, { Neon = true })
	Kit.ring(m, CN(0, 0.55, 0) * ANG(rad(70), 0, rad(20)), 0.75, 0.08, rgb(220, 190, 255), 12, { Neon = true }, false)
	Kit.sparkle(Kit.ball(m, CN(0, 0.55, 0), 0.2, purple, { Neon = true }), purple, 4)
end

B.AICore = function(m)
	local red = rgb(255, 80, 80)
	Kit.cylY(m, CN(0, -1.2, 0), 0.3, 1.8, DARK)
	Kit.cylY(m, CN(0, -0.95, 0), 0.25, 1.2, STEEL)
	Kit.ball(m, CN(0, 0.1, 0), 1.3, red, { Neon = true })
	Kit.ring(m, CN(0, 0.1, 0), 1.0, 0.14, STEEL, 12, nil, false)
	Kit.ring(m, CN(0, 0.1, 0) * ANG(rad(90), 0, 0), 1.0, 0.14, STEEL, 12, nil, false)
	Kit.ring(m, CN(0, 0.1, 0) * ANG(0, 0, rad(90)), 1.0, 0.14, STEEL, 12, nil, false)
	Kit.eye(m, CN(0, 0.15, -0.55), 0.5, rgb(255, 255, 255))
	Kit.sparkle(Kit.ball(m, CN(0, 0.1, 0), 0.3, red, { Neon = true }), red, 6)
end

---------------------------------------------------------------- Shipyard Wrecks

local function chainLink(m: Model, cf: CFrame, color: Color3)
	for _, side in { -1, 1 } do
		Kit.cyl(m, cf * CN(0, side * 0.32, 0), 0.7, 0.22, color)
		Kit.cylY(m, cf * CN(side * 0.35, 0, 0), 0.64, 0.22, color)
		for _, s2 in { -1, 1 } do
			Kit.ball(m, cf * CN(side * 0.35, s2 * 0.32, 0), 0.22, color)
		end
	end
end

B.RustyChain = function(m)
	local rust = rgb(190, 105, 60)
	for i = 0, 3 do
		local cf = CN(-1.2 + i * 0.78, math.sin(i) * 0.15, 0) * (if i % 2 == 0 then CFrame.identity else ANG(rad(90), 0, 0))
		chainLink(m, cf, if i % 2 == 0 then rust else Kit.shade(rust, -0.15))
	end
end

B.Porthole = function(m)
	local face = ANG(rad(90), 0, 0)
	Kit.ring(m, face, 1.0, 0.45, BRASS, 12)
	Kit.cylZ(m, CN(0, 0, 0), 0.15, 1.75, rgb(110, 190, 240), { Transparency = 0.15 })
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		Kit.ball(m, CN(math.cos(a) * 1.0, math.sin(a) * 1.0, -0.22), 0.18, Kit.shade(BRASS, -0.3))
	end
	Kit.box(m, CN(0.3, 0.35, -0.09), Vector3.new(0.4, 0.08, 0.02), WHITE, { Neon = true })
end

B.Propeller = function(m)
	Kit.cylZ(m, CN(0, 0, 0.35), 0.7, 0.75, Kit.shade(BRASS, -0.2))
	Kit.ball(m, CN(0, 0, -0.1), 0.8, BRASS)
	Kit.ball(m, CN(0, 0, -0.35), 0.45, Kit.shade(BRASS, 0.2))
	for i = 0, 2 do
		local blade = ANG(0, 0, i / 3 * math.pi * 2) * CN(0, 0.95, 0.05) * ANG(0, rad(28), 0)
		Kit.box(m, blade, Vector3.new(0.85, 1.2, 0.12), GOLD)
		Kit.cylZ(m, blade * CN(0, 0.6, 0), 0.12, 0.85, GOLD)
	end
end

B.Anchor = function(m)
	local iron = rgb(70, 74, 88)
	Kit.cylY(m, CN(0, 0.1, 0), 2.4, 0.32, iron)
	Kit.ring(m, CN(0, 1.5, 0) * ANG(rad(90), 0, 0), 0.32, 0.16, iron, 8, nil, false)
	Kit.pill(m, CN(0, 0.85, 0), 1.3, 0.24, iron)
	local arc = 0
	for i = -3, 3 do
		arc = i / 3 * math.rad(60)
		Kit.ball(m, CN(math.sin(arc) * 1.0, -1.1 + (1 - math.cos(arc)) * 1.0, 0), 0.34, iron)
	end
	for _, side in { -1, 1 } do
		Kit.wedge(m, CN(side * 0.95, -0.25, 0) * ANG(0, rad(side * 90), 0), Vector3.new(0.18, 0.55, 0.5), iron)
	end
end

B.CaptainsWheel = function(m)
	local face = ANG(rad(90), 0, 0)
	Kit.ring(m, face, 1.0, 0.28, WOOD, 12)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		Kit.cyl(m, ANG(0, 0, a) * CN(0.85, 0, 0), 1.7, 0.14, Kit.shade(WOOD, 0.1))
		Kit.pill(m, ANG(0, 0, a) * CN(1.55, 0, 0), 0.6, 0.2, Kit.shade(WOOD, -0.1))
	end
	Kit.cylZ(m, CN(0, 0, 0), 0.4, 0.55, BRASS)
	Kit.cylZ(m, CN(0, 0, -0.2), 0.1, 0.3, GOLD)
end

B.SunkenTreasure = function(m)
	local wood = rgb(140, 90, 55)
	Kit.roundBox(m, CN(0, -0.45, 0), Vector3.new(2.4, 1.2, 1.6), 0.12, wood, nil, false)
	-- Lid hinged open at the back.
	local lid = CN(0, 0.15, 0.8) * ANG(rad(-65), 0, 0) * CN(0, 0.2, -0.8)
	Kit.roundBox(m, lid, Vector3.new(2.4, 0.4, 1.6), 0.15, Kit.shade(wood, 0.12), nil, false)
	Kit.box(m, lid * CN(0, 0.05, 0), Vector3.new(0.2, 0.44, 1.64), GOLD)
	for _, x in { -0.95, 0.95 } do
		Kit.box(m, CN(x, -0.45, 0), Vector3.new(0.18, 1.24, 1.64), GOLD)
	end
	Kit.box(m, CN(0, -0.3, -0.82), Vector3.new(0.38, 0.45, 0.06), GOLD)
	-- Spilling treasure.
	Kit.box(m, CN(0, 0.12, 0), Vector3.new(2.2, 0.06, 1.4), Kit.shade(GOLD, -0.1))
	for i = 0, 8 do
		local x, z = -0.8 + (i % 3) * 0.8, -0.45 + (i // 3) * 0.45
		Kit.cylY(m, CN(x, 0.2 + (i % 2) * 0.12, z) * ANG(rad(12 * (i % 3)), 0, rad(8 * (i % 2))), 0.1, 0.42, GOLD)
	end
	Kit.ball(m, CN(-0.35, 0.35, 0.05), 0.4, rgb(255, 70, 110), { Neon = true })
	Kit.ball(m, CN(0.45, 0.35, -0.1), 0.34, rgb(80, 220, 255), { Neon = true })
	Kit.box(m, CN(0.05, 0.35, 0.3) * ANG(rad(45), rad(45), 0), Vector3.new(0.3, 0.3, 0.3), rgb(120, 255, 140), { Neon = true })
	Kit.sparkle(Kit.ball(m, CN(0, 0.35, 0), 0.2, GOLD, { Neon = true }), GOLD, 6)
end

B.KrakenTooth = function(m)
	local tooth = rgb(240, 245, 235)
	local glow = rgb(120, 255, 220)
	Kit.cylY(m, CN(0, -1.15, 0), 0.25, 1.6, rgb(60, 80, 110))
	Kit.ring(m, CN(0, -1.0, 0), 0.62, 0.16, glow, 10, { Neon = true }, false)
	local cf = CN(0, -1.15, 0)
	for i = 0, 6 do
		local d = 1.15 * (1 - i / 7) + 0.1
		cf = cf * ANG(0, 0, rad(-12)) * CN(0, 0.34, 0)
		Kit.cylY(m, cf, 0.38, d, tooth)
	end
	Kit.ball(m, cf * CN(0, 0.22, 0), 0.2, tooth)
	Kit.sparkle(Kit.ball(m, CN(0, -0.9, 0), 0.25, glow, { Neon = true }), glow, 6)
end

---------------------------------------------------------------- Crash Site

B.SpaceRock = function(m)
	local rock = rgb(125, 105, 155)
	Kit.ball(m, CN(0, 0, 0), 2.0, rock)
	Kit.ball(m, CN(0.75, -0.35, 0.3), 1.2, Kit.shade(rock, -0.1))
	Kit.ball(m, CN(-0.7, -0.4, -0.2), 1.0, Kit.shade(rock, 0.08))
	for _, c in { { -0.3, 0.5, -0.7 }, { 0.4, 0.2, -0.85 }, { -0.1, -0.3, -0.92 } } do
		Kit.ball(m, CN(c[1], c[2], c[3]), 0.42, Kit.shade(rock, -0.35))
	end
	Kit.ball(m, CN(0.2, 0.75, -0.35), 0.3, rgb(140, 255, 220), { Neon = true })
end

B.SatelliteDish = function(m)
	Kit.cylY(m, CN(0, -1.0, 0), 0.25, 1.2, DARK)
	Kit.cylY(m, CN(0, -0.55, 0), 0.8, 0.25, STEEL)
	local dish = CN(0, 0.15, 0) * ANG(rad(-35), 0, 0)
	Kit.cylY(m, dish, 0.18, 2.2, WHITE)
	Kit.cylY(m, dish * CN(0, 0.1, 0), 0.06, 1.6, Kit.shade(WHITE, -0.12))
	Kit.cylY(m, dish * CN(0, 0.55, 0), 0.9, 0.1, STEEL)
	Kit.ball(m, dish * CN(0, 1.0, 0), 0.26, rgb(255, 80, 80), { Neon = true })
end

B.RocketFin = function(m)
	local red = rgb(230, 60, 60)
	Kit.wedge(m, CN(0, 0, 0), Vector3.new(0.3, 2.2, 2.0), red)
	Kit.wedge(m, CN(0, -0.55, 0.25), Vector3.new(0.32, 0.4, 1.5), WHITE)
	Kit.box(m, CN(0, -1.15, 0), Vector3.new(0.45, 0.15, 2.1), STEEL)
	for _, z in { -0.7, 0, 0.7 } do
		Kit.ball(m, CN(0, -1.05, z), 0.16, DARK)
	end
end

B.AlienAlloy = function(m)
	local teal = rgb(60, 230, 200)
	Kit.box(m, CN(0, 0, 0), Vector3.new(2.4, 0.7, 1.1), Kit.shade(teal, -0.2))
	for _, side in { -1, 1 } do
		Kit.wedge(m, CN(side * 1.38, 0, 0) * ANG(0, rad(side * -90), 0), Vector3.new(1.1, 0.7, 0.36), Kit.shade(teal, -0.3))
	end
	Kit.box(m, CN(0, 0.37, 0), Vector3.new(2.2, 0.05, 0.9), Kit.shade(teal, 0.25))
	Kit.box(m, CN(0, 0, -0.56), Vector3.new(2.0, 0.12, 0.04), teal, { Neon = true })
	Kit.box(m, CN(0.5, 0.41, 0), Vector3.new(0.5, 0.04, 0.5) , rgb(255, 255, 255), { Neon = true })
end

B.UFOCore = function(m)
	local green = rgb(150, 255, 120)
	Kit.cylY(m, CN(0, -1.0, 0), 0.25, 1.4, STEEL)
	Kit.cylY(m, CN(0, 1.0, 0), 0.25, 1.4, STEEL)
	Kit.ball(m, CN(0, 0, 0), 1.3, green, { Neon = true })
	for i = 0, 3 do
		Kit.cylY(m, ANG(0, i * math.pi / 2, 0) * CN(0.7, 0, 0), 1.9, 0.14, Kit.shade(STEEL, -0.1))
	end
	Kit.ring(m, CN(0, 0, 0), 0.75, 0.16, Kit.shade(STEEL, 0.2), 10, nil, false)
	Kit.sparkle(Kit.ball(m, CN(0, 0, 0), 0.3, green, { Neon = true }), green, 5)
end

B.AlienArtifact = function(m)
	local pink = rgb(255, 120, 230)
	local base = rgb(70, 50, 110)
	Kit.cylY(m, CN(0, -1.0, 0), 0.3, 1.8, base)
	for i = 0, 3 do
		Kit.wedge(m, CN(0, -0.25, 0) * ANG(0, i * math.pi / 2, 0) * CN(0, 0, -0.3), Vector3.new(1.2, 1.2, 0.6), Kit.shade(base, 0.15))
	end
	Kit.ball(m, CN(0, 0.75, 0), 0.7, pink, { Neon = true })
	Kit.ring(m, CN(0, 0.75, 0) * ANG(rad(20), 0, 0), 0.75, 0.1, pink, 12, { Neon = true }, false)
	Kit.box(m, CN(0, -0.3, -0.6), Vector3.new(0.3, 0.3, 0.05), pink, { Neon = true })
	Kit.sparkle(Kit.ball(m, CN(0, 0.75, 0), 0.2, pink, { Neon = true }), pink, 6)
end

B.CosmicShard = function(m)
	local colors = { rgb(255, 255, 255), rgb(255, 150, 220), rgb(160, 220, 255) }
	local shards = { { 0, 0, 0, 2.4, 0 }, { 0.55, -0.3, 0.1, 1.5, -25 }, { -0.5, -0.35, -0.1, 1.6, 22 }, { 0.1, -0.5, 0.5, 1.0, 10 } }
	for i, s in shards do
		local cf = CN(s[1], s[2], s[3]) * ANG(0, i, rad(s[5]))
		Kit.box(m, cf * ANG(0, rad(45), 0), Vector3.new(0.5 * s[4] / 2.4 + 0.2, s[4], 0.5 * s[4] / 2.4 + 0.2), colors[(i - 1) % 3 + 1], { Neon = true })
	end
	Kit.ring(m, CN(0, 0.2, 0) * ANG(rad(15), 0, 0), 1.2, 0.1, rgb(255, 200, 240), 14, { Neon = true }, false)
	Kit.sparkle(Kit.ball(m, CN(0, 0.3, 0), 0.25, WHITE, { Neon = true }), rgb(255, 220, 250), 8)
end

---------------------------------------------------------------- API

function Items.list(): { string }
	return table.clone(Zones.ItemOrder)
end

-- Builds an item model centred on the origin.
function Items.build(id: string): Model
	local model = Kit.model(nil, id)
	local builder = B[id]
	if builder then
		builder(model)
	else
		local item = Zones.Items[id]
		Kit.roundBox(model, CFrame.new(), Vector3.new(1.6, 1.6, 1.6), 0.4, if item then item.Color else STEEL)
	end
	return model
end

return Items
