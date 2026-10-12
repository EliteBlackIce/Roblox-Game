--!strict
-- World prop library in the rounded "toy" style. Every function takes a parent
-- and a ground CFrame (front = -Z / LookVector) and builds an anchored model.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = ReplicatedStorage.Shared.Art
local Items = require(Art.Items)
local Kit = require(Art.Kit)

local Props = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local CN = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local BLACK = rgb(40, 40, 48)
local WHITE = rgb(248, 248, 252)
local STEEL = rgb(185, 192, 205)
local DARK = rgb(65, 68, 80)
local WOOD = rgb(170, 115, 70)

local SOLID = { Collide = true }

local OUTLINED = { Car = true, Crusher = true, BoatWreck = true, Lighthouse = true, UFO = true, RocketWreck = true, Tree = true, Fridge = true, Washer = true, ServerRack = true, Container = true, Barrel = true, Bench = true, LampPost = true }

local function model(parent: Instance, name: string): Model
	local m = Kit.model(parent, name)
	if OUTLINED[name] then
		CollectionService:AddTag(m, "Outline")
	end
	return m
end

-- A giant version of a scrap item, used as a landmark.
function Props.giant(parent: Instance, itemId: string, cf: CFrame, scale: number): Model
	local m = Items.build(itemId)
	m.Name = "Giant" .. itemId
	Kit.scale(m, scale)
	Kit.placeOnGround(m, cf)
	for _, part in m:GetDescendants() do
		if part:IsA("BasePart") and part.Size.Magnitude > 3 then
			part.CanCollide = true
		end
	end
	m.Parent = parent
	CollectionService:AddTag(m, "Outline")
	return m
end

function Props.barrel(parent: Instance, cf: CFrame, color: Color3, tipped: boolean?)
	local m = model(parent, "Barrel")
	local body = if tipped then cf * CN(0, 1.35, 0) * ANG(0, 0, rad(90)) else cf * CN(0, 1.9, 0)
	Kit.cylY(m, body, 3.6, 2.7, color, SOLID)
	for _, y in { -1.1, 1.1 } do
		Kit.ring(m, body * CN(0, y, 0), 1.37, 0.28, Kit.shade(color, -0.3), 8, nil, false)
	end
	Kit.ring(m, body * CN(0, 1.8, 0), 1.2, 0.3, Kit.shade(color, 0.2), 8, nil, false)
	Kit.cylY(m, body * CN(0, 1.82, 0), 0.06, 2.3, Kit.shade(color, -0.2))
	Kit.cylY(m, body * CN(0.6, 1.88, 0), 0.12, 0.4, DARK)
end

function Props.tire(parent: Instance, cf: CFrame)
	local m = model(parent, "Tire")
	Kit.ring(m, cf * CN(0, 0.55, 0), 1.35, 1.1, BLACK, 10)
	Kit.cylY(m, cf * CN(0, 0.55, 0), 0.5, 1.6, Kit.shade(STEEL, -0.3))
end

function Props.tires(parent: Instance, cf: CFrame, count: number)
	for i = 0, count - 1 do
		Props.tire(parent, cf * CN(math.sin(i) * 0.25, i * 1.0, math.cos(i) * 0.25) * ANG(0, i * 0.5, 0))
	end
end

function Props.cone(parent: Instance, cf: CFrame)
	local m = model(parent, "Cone")
	local orange = rgb(255, 130, 40)
	Kit.roundSlab(m, cf * CN(0, 0.15, 0), Vector3.new(2.2, 0.3, 2.2), 0.4, orange)
	Kit.cone(m, cf * CN(0, 0.3, 0), 2.8, 1.6, orange, 5)
	Kit.cylY(m, cf * CN(0, 1.6, 0), 0.45, 0.95, WHITE)
end

function Props.car(parent: Instance, cf: CFrame, color: Color3, wrecked: boolean?)
	local m = model(parent, "Car")
	Kit.roundBox(m, cf * CN(0, 2.0, 0), Vector3.new(6, 2.2, 11), 0.8, color, SOLID, false)
	Kit.roundBox(m, cf * CN(0, 3.75, 0.6), Vector3.new(5.2, 1.9, 5.6), 0.7, Kit.shade(color, 0.08), SOLID, false)
	local glass = rgb(150, 215, 245)
	Kit.box(m, cf * CN(0, 3.85, -2.2), Vector3.new(4.4, 1.3, 0.2), glass)
	Kit.box(m, cf * CN(0, 3.85, 3.45), Vector3.new(4.4, 1.3, 0.2), glass)
	for _, side in { -1, 1 } do
		Kit.box(m, cf * CN(side * 2.62, 3.85, 0.6), Vector3.new(0.2, 1.2, 4.2), glass)
		Kit.ball(m, cf * CN(side * 2.0, 2.3, -5.45), 0.9, rgb(255, 240, 170), { Neon = not wrecked })
		Kit.box(m, cf * CN(side * 2.1, 2.3, 5.5), Vector3.new(1.0, 0.5, 0.1), rgb(230, 60, 60))
		for _, z in { -3.4, 3.4 } do
			if not (wrecked and side == 1 and z < 0) then
				local wheel = cf * CN(side * 2.85, 1.25, z) * ANG(0, 0, rad(90))
				Kit.cylY(m, wheel, 1.0, 2.5, BLACK)
				Kit.cylY(m, wheel, 1.1, 1.3, STEEL)
			end
		end
	end
	Kit.pill(m, cf * CN(0, 1.25, -5.55), 6.2, 0.6, STEEL)
	Kit.pill(m, cf * CN(0, 1.25, 5.55), 6.2, 0.6, STEEL)
	if wrecked then
		Kit.cylY(m, cf * CN(-1.2, 3.15, -3.5), 0.1, 1.6, Kit.shade(color, -0.35))
		Kit.cylY(m, cf * CN(1.5, 2.2, 2.5) * ANG(0, 0, rad(90)), 0.1, 1.2, Kit.shade(color, -0.35))
	end
end

function Props.container(parent: Instance, cf: CFrame, color: Color3)
	local m = model(parent, "Container")
	Kit.roundBox(m, cf * CN(0, 4.25, 0), Vector3.new(8, 8.5, 20), 0.8, color, SOLID, false)
	for _, side in { -1, 1 } do
		for z = -8, 8, 2 do
			Kit.box(m, cf * CN(side * 4.08, 4.25, z), Vector3.new(0.18, 7.8, 0.7), Kit.shade(color, -0.15))
		end
	end
	for _, y in { 0.25, 8.25 } do
		Kit.box(m, cf * CN(0, y, 0), Vector3.new(8.3, 0.5, 20.3), Kit.shade(color, -0.3))
	end
	Kit.box(m, cf * CN(0, 4.25, 10.06), Vector3.new(7.6, 7.8, 0.15), Kit.shade(color, -0.1))
	for _, x in { -1.5, 1.5 } do
		Kit.cylY(m, cf * CN(x, 4.25, 10.2), 7.4, 0.25, STEEL)
	end
end

function Props.crusher(parent: Instance, cf: CFrame)
	local m = model(parent, "Crusher")
	local yellow = rgb(255, 200, 45)
	Kit.roundBox(m, cf * CN(0, 2.2, 0), Vector3.new(11, 4.4, 11), 0.8, yellow, SOLID, false)
	for x = -4.5, 4.5, 1.8 do
		Kit.box(m, cf * CN(x, 3.2, -5.55), Vector3.new(0.9, 0.9, 0.1), BLACK)
	end
	for _, x in { -5, 5 } do
		Kit.roundBox(m, cf * CN(x, 8.5, 4), Vector3.new(1.6, 13, 1.6), 0.5, DARK, SOLID, false)
	end
	Kit.roundBox(m, cf * CN(0, 15.2, 4), Vector3.new(12, 1.6, 2.4), 0.5, DARK, nil, false)
	Kit.cylY(m, cf * CN(0, 12.5, 0), 4, 1.2, STEEL)
	Kit.roundBox(m, cf * CN(0, 10.2, 0), Vector3.new(8.5, 1.6, 8.5), 0.5, DARK, nil, false)
	Kit.roundBox(m, cf * CN(0, 5.6, 0) * ANG(0, 0.3, 0), Vector3.new(4.5, 2.4, 4.5), 0.4, rgb(220, 70, 60), nil, false)
end

function Props.fridge(parent: Instance, cf: CFrame, color: Color3)
	local m = model(parent, "Fridge")
	Kit.roundBox(m, cf * CN(0, 4, 0), Vector3.new(4, 8, 3.6), 0.6, color, SOLID, false)
	Kit.box(m, cf * CN(0, 5.6, -1.6), Vector3.new(3.7, 0.15, 0.5), Kit.shade(color, -0.2))
	Kit.pill(m, cf * CN(1.4, 6.8, -1.9) * ANG(0, 0, rad(90)), 1.6, 0.3, STEEL)
	Kit.pill(m, cf * CN(1.4, 3.4, -1.9) * ANG(0, 0, rad(90)), 2.2, 0.3, STEEL)
	for _, s in { { -0.9, 6.9, rgb(255, 120, 150) }, { -0.3, 7.1, rgb(120, 200, 255) }, { -1.1, 4.4, rgb(255, 210, 80) } } do
		Kit.cylZ(m, cf * CN(s[1], s[2], -1.85), 0.15, 0.5, s[3])
	end
end

function Props.washer(parent: Instance, cf: CFrame, color: Color3)
	local m = model(parent, "Washer")
	Kit.roundBox(m, cf * CN(0, 2.3, 0), Vector3.new(4.2, 4.6, 4.2), 0.6, color, SOLID, false)
	Kit.cylZ(m, cf * CN(0, 2.0, -2.0), 0.3, 2.9, STEEL)
	Kit.cylZ(m, cf * CN(0, 2.0, -2.1), 0.2, 2.3, rgb(120, 190, 235))
	Kit.box(m, cf * CN(0, 4.1, -2.05), Vector3.new(3.6, 0.7, 0.2), DARK)
	Kit.cylZ(m, cf * CN(1.2, 4.1, -2.2), 0.15, 0.45, rgb(255, 100, 120), { Neon = true })
end

function Props.serverRack(parent: Instance, cf: CFrame, glow: Color3)
	local m = model(parent, "ServerRack")
	Kit.roundBox(m, cf * CN(0, 4.75, 0), Vector3.new(4, 9.5, 4), 0.4, rgb(40, 42, 52), SOLID, false)
	for i = 0, 5 do
		local y = 1.4 + i * 1.35
		Kit.box(m, cf * CN(0, y, -2.02), Vector3.new(3.3, 1.05, 0.1), rgb(60, 63, 78))
		Kit.box(m, cf * CN(-1.2, y, -2.1), Vector3.new(0.3, 0.3, 0.1), glow, { Neon = true })
		Kit.box(m, cf * CN(0.5, y, -2.1), Vector3.new(1.8, 0.14, 0.1), glow, { Neon = true })
	end
end

function Props.boat(parent: Instance, cf: CFrame, color: Color3)
	local m = model(parent, "BoatWreck")
	local tilt = cf * ANG(0, 0, rad(10))
	Kit.roundBox(m, tilt * CN(0, 2.6, 0), Vector3.new(10, 5, 20), 2.2, color, SOLID, false)
	Kit.box(m, tilt * CN(0, 3.4, 0), Vector3.new(10.2, 0.8, 18), WHITE)
	Kit.roundBox(m, tilt * CN(0, 5.6, 0), Vector3.new(8.6, 1, 17), 0.4, WOOD, nil, false)
	Kit.roundBox(m, tilt * CN(0.5, 8.0, 4), Vector3.new(6, 4, 5.5), 0.8, WHITE, nil, false)
	for _, z in { -1.6, 0, 1.6 } do
		Kit.cylY(m, tilt * CN(-2.5, 8.4, 4 + z) * ANG(0, 0, rad(90)), 0.3, 1, rgb(120, 200, 240))
	end
	Kit.cylY(m, tilt * CN(1, 12, -4), 10, 0.7, WOOD)
	Kit.box(m, tilt * CN(1, 13, -2.5) * ANG(0, 0, rad(-6)), Vector3.new(0.2, 6, 4), Kit.shade(WHITE, -0.1))
end

function Props.dock(parent: Instance, cf: CFrame, length: number)
	local m = model(parent, "Dock")
	for z = -length / 2 + 1, length / 2 - 1, 2.2 do
		Kit.box(m, cf * CN(0, 1.2, z), Vector3.new(8, 0.6, 2), if math.floor(z) % 2 == 0 then WOOD else Kit.shade(WOOD, 0.08), SOLID)
	end
	for z = -length / 2 + 2, length / 2 - 2, 6 do
		for _, x in { -3.6, 3.6 } do
			Kit.cylY(m, cf * CN(x, 1, z), 3, 0.9, Kit.shade(WOOD, -0.25))
			Kit.ball(m, cf * CN(x, 2.5, z), 0.9, Kit.shade(WOOD, -0.25))
		end
	end
end

function Props.lighthouse(parent: Instance, cf: CFrame)
	local m = model(parent, "Lighthouse")
	Kit.ball(m, cf * CN(0, -2, 0), 16, rgb(150, 150, 165), SOLID)
	for i = 0, 5 do
		Kit.cylY(m, cf * CN(0, 6.5 + i * 4.5, 0), 4.5, 7 - i * 0.45, if i % 2 == 0 then rgb(235, 70, 70) else WHITE, SOLID)
	end
	Kit.ring(m, cf * CN(0, 33.5, 0), 3, 0.4, DARK, 12, nil, false)
	local lamp = Kit.cylY(m, cf * CN(0, 35.5, 0), 3.5, 3.5, rgb(255, 240, 160), { Neon = true })
	Kit.cone(m, cf * CN(0, 37.3, 0), 4, 5, rgb(235, 70, 70), 4)
	Kit.ball(m, cf * CN(0, 41.6, 0), 0.9, rgb(255, 210, 60))
	local light = Instance.new("PointLight")
	light.Range = 45
	light.Brightness = 2
	light.Color = rgb(255, 240, 180)
	light.Parent = lamp
end

function Props.ufo(parent: Instance, cf: CFrame, scale: number)
	local m = model(parent, "UFO")
	local s = scale
	local tilt = cf * CN(0, 4 * s, 0) * ANG(rad(12), 0, rad(8))
	Kit.cylY(m, tilt, 2 * s, 24 * s, rgb(195, 200, 215), SOLID)
	Kit.cylY(m, tilt * CN(0, -1.2 * s, 0), 1 * s, 18 * s, rgb(140, 145, 160))
	Kit.ring(m, tilt, 12 * s, 1.4 * s, rgb(160, 165, 180), 18, nil, false)
	Kit.ball(m, tilt * CN(0, 1.5 * s, 0), 11 * s, rgb(140, 255, 210), { Neon = true, Transparency = 0.15 })
	for i = 0, 9 do
		local angle = i / 10 * math.pi * 2
		Kit.ball(m, tilt * CN(math.cos(angle) * 10.5 * s, 0.6 * s, math.sin(angle) * 10.5 * s), 1.3 * s, if i % 2 == 0 then rgb(255, 90, 200) else rgb(255, 230, 90), { Neon = true })
	end
	Kit.eye(m, tilt * CN(-1.6 * s, 3.5 * s, -4.4 * s), 2.2 * s)
	Kit.eye(m, tilt * CN(1.6 * s, 3.5 * s, -4.4 * s), 2.2 * s)
end

function Props.crystal(parent: Instance, cf: CFrame, color: Color3, height: number)
	local m = model(parent, "Crystal")
	Kit.box(m, cf * CN(0, height / 2, 0) * ANG(0.12, 0.7, 0.08), Vector3.new(height * 0.32, height, height * 0.32), color, { Neon = true, Collide = true })
	Kit.box(m, cf * CN(height * 0.28, height * 0.3, 0.2) * ANG(0, 0.3, -0.45), Vector3.new(height * 0.22, height * 0.6, height * 0.22), Kit.shade(color, 0.2), { Neon = true })
	Kit.box(m, cf * CN(-height * 0.25, height * 0.22, -0.2) * ANG(0, -0.2, 0.5), Vector3.new(height * 0.2, height * 0.45, height * 0.2), Kit.shade(color, -0.1), { Neon = true })
	Kit.ball(m, cf * CN(0, 0, 0), height * 0.5, rgb(110, 90, 140))
end

function Props.rocket(parent: Instance, cf: CFrame)
	local m = model(parent, "RocketWreck")
	local lying = cf * CN(0, 3, 0) * ANG(0, 0, rad(82))
	Kit.cylY(m, lying, 22, 6, WHITE, SOLID)
	for _, y in { -4, 3 } do
		Kit.cylY(m, lying * CN(0, y, 0), 1.6, 6.2, rgb(230, 60, 60))
	end
	Kit.cone(m, lying * CN(0, 11, 0), 6, 6, rgb(230, 60, 60), 5)
	Kit.cylZ(m, lying * CN(0, 4, -3.0), 0.3, 2.2, rgb(130, 200, 240))
	for _, a in { 0, 120, 240 } do
		local fin = lying * ANG(0, rad(a), 0)
		Kit.pillBetween(m, (fin * CN(0, -6.5, 2.6)).Position, (fin * CN(0, -10.5, 5.2)).Position, 1.6, rgb(230, 60, 60))
	end
	Kit.cylY(m, lying * CN(0, -11.5, 0), 1.5, 4.5, DARK)
end

function Props.satellite(parent: Instance, cf: CFrame)
	Props.giant(parent, "SatelliteDish", cf, 3.2)
end

function Props.lamp(parent: Instance, cf: CFrame, color: Color3?)
	local m = model(parent, "LampPost")
	local glow = color or rgb(255, 230, 160)
	Kit.cylY(m, cf * CN(0, 0.4, 0), 0.8, 1.8, DARK)
	Kit.cylY(m, cf * CN(0, 7, 0), 13, 0.7, DARK, SOLID)
	Kit.ring(m, cf * CN(0, 13.4, 0), 0.9, 0.3, DARK, 8, nil, false)
	local bulb = Kit.ball(m, cf * CN(0, 14.3, 0), 2.0, glow, { Neon = true })
	Kit.cone(m, cf * CN(0, 15.1, 0), 1.1, 2.4, DARK, 3)
	local light = Instance.new("PointLight")
	light.Range = 28
	light.Brightness = 1.2
	light.Color = glow
	light.Parent = bulb
end

-- Pet-Simulator-style tree: a chunky trunk and a cluster of round leaf balls.
function Props.tree(parent: Instance, cf: CFrame, scale: number, leaf: Color3, rng: Random)
	local m = model(parent, "Tree")
	local s = scale
	Kit.cylY(m, cf * CN(0, 3 * s, 0), 6 * s, 1.6 * s, rgb(130, 85, 55), SOLID)
	Kit.cylY(m, cf * CN(0, 0.4 * s, 0), 0.8 * s, 2.4 * s, rgb(115, 75, 50))
	local blobs = { { 0, 8, 0, 6.5 }, { -2.2, 6.8, 0.8, 4.6 }, { 2.3, 7, -0.5, 4.8 }, { 0.4, 6.6, 2.3, 4.2 }, { -0.5, 10, -0.6, 4.2 } }
	for i, b in blobs do
		local color = if i % 2 == 0 then Kit.shade(leaf, 0.1) else leaf
		Kit.ball(m, cf * CN(b[1] * s, b[2] * s, b[3] * s), b[4] * s * rng:NextNumber(0.92, 1.08), color)
	end
	if rng:NextNumber() < 0.4 then
		for _ = 1, 3 do
			local a = rng:NextNumber(0, math.pi * 2)
			Kit.ball(m, cf * CN(math.cos(a) * 3 * s, 7.5 * s + rng:NextNumber(-1, 1.5) * s, math.sin(a) * 3 * s), 0.7 * s, rgb(255, 90, 90))
		end
	end
end

function Props.bush(parent: Instance, cf: CFrame, scale: number, color: Color3)
	local m = model(parent, "Bush")
	Kit.ball(m, cf * CN(0, 1.2 * scale, 0), 3.2 * scale, color)
	Kit.ball(m, cf * CN(1.4 * scale, 0.9 * scale, 0.4 * scale), 2.4 * scale, Kit.shade(color, 0.1))
	Kit.ball(m, cf * CN(-1.3 * scale, 0.8 * scale, -0.3 * scale), 2.2 * scale, Kit.shade(color, -0.08))
end

function Props.rock(parent: Instance, cf: CFrame, scale: number, color: Color3)
	local m = model(parent, "Rock")
	Kit.ball(m, cf * CN(0, 0.6 * scale, 0), 3 * scale, color, SOLID)
	Kit.ball(m, cf * CN(1.3 * scale, 0.3 * scale, 0.6 * scale), 1.8 * scale, Kit.shade(color, 0.1))
	Kit.ball(m, cf * CN(-1.1 * scale, 0.25 * scale, -0.5 * scale), 1.5 * scale, Kit.shade(color, -0.1))
end

function Props.flowers(parent: Instance, cf: CFrame, rng: Random)
	local m = model(parent, "Flowers")
	local petals = { rgb(255, 110, 150), rgb(255, 220, 80), rgb(150, 140, 255), rgb(255, 255, 255) }
	for _ = 1, 3 do
		local offset = Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
		Kit.cylY(m, cf * CN(offset + Vector3.new(0, 0.6, 0)), 1.2, 0.18, rgb(80, 170, 70))
		Kit.ball(m, cf * CN(offset + Vector3.new(0, 1.35, 0)), 0.75, petals[rng:NextInteger(1, #petals)])
		Kit.ball(m, cf * CN(offset + Vector3.new(0, 1.45, -0.25)), 0.3, rgb(255, 230, 90))
	end
end

function Props.bench(parent: Instance, cf: CFrame)
	local m = model(parent, "Bench")
	Kit.roundBox(m, cf * CN(0, 2, 0), Vector3.new(8, 0.6, 2.6), 0.25, WOOD, SOLID, false)
	Kit.roundBox(m, cf * CN(0, 3.4, 1.1), Vector3.new(8, 2, 0.5), 0.2, WOOD, nil, false)
	for _, x in { -3.2, 3.2 } do
		Kit.roundBox(m, cf * CN(x, 1, 0.2), Vector3.new(0.6, 2, 2.4), 0.2, DARK, nil, false)
	end
end

function Props.planter(parent: Instance, cf: CFrame, rng: Random)
	local m = model(parent, "Planter")
	Kit.roundSlab(m, cf * CN(0, 1, 0), Vector3.new(11, 2, 11), 1.5, rgb(210, 200, 185), SOLID)
	Kit.box(m, cf * CN(0, 2.02, 0), Vector3.new(9.4, 0.1, 9.4), rgb(120, 85, 60))
	Props.tree(parent, cf * CN(0, 2, 0), 0.85, rgb(110, 200, 90), rng)
	Props.flowers(parent, cf * CN(0, 2, 0), rng)
end

return Props
