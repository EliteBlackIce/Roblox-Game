--!strict
-- Low-poly prop library used by MapBuilder. Every function takes a parent, a base
-- CFrame (on the ground) and builds an anchored, solid-colour model.

local Builder = require(script.Parent.Builder)

local Props = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local BLACK = rgb(35, 35, 40)
local WHITE = rgb(245, 245, 245)
local STEEL = rgb(170, 175, 185)
local DARK = rgb(70, 72, 80)

local function piece(model: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	return Builder.part(model, { Name = name, Size = size, CFrame = cf, Color = color, Material = material, Shape = shape })
end

local function wheel(model: Instance, cf: CFrame, diameter: number, width: number)
	piece(model, "Wheel", Vector3.new(width, diameter, diameter), cf, BLACK, nil, Enum.PartType.Cylinder)
end

function Props.barrel(parent: Instance, base: CFrame, color: Color3, tipped: boolean?)
	local model = Builder.model(parent, "Barrel")
	if tipped then
		piece(model, "Drum", Vector3.new(3.6, 2.6, 2.6), base * CFrame.new(0, 1.3, 0), color, nil, Enum.PartType.Cylinder)
		piece(model, "Band", Vector3.new(0.3, 2.7, 2.7), base * CFrame.new(0.9, 1.3, 0), color:Lerp(BLACK, 0.3), nil, Enum.PartType.Cylinder)
	else
		local up = base * CFrame.Angles(0, 0, math.rad(90))
		piece(model, "Drum", Vector3.new(3.6, 2.6, 2.6), base * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.rad(90)), color, nil, Enum.PartType.Cylinder)
		piece(model, "Band", Vector3.new(0.3, 2.7, 2.7), (up + Vector3.new(0, 2.6, 0)), color:Lerp(BLACK, 0.3), nil, Enum.PartType.Cylinder)
	end
end

function Props.tires(parent: Instance, base: CFrame, count: number)
	local model = Builder.model(parent, "Tires")
	for i = 0, count - 1 do
		piece(model, "Tire", Vector3.new(1, 3.2, 3.2), base * CFrame.new(0, 0.5 + i, 0) * CFrame.Angles(0, i * 0.4, math.rad(90)), BLACK, nil, Enum.PartType.Cylinder)
	end
end

function Props.cone(parent: Instance, base: CFrame)
	local model = Builder.model(parent, "Cone")
	piece(model, "Base", Vector3.new(2, 0.3, 2), base * CFrame.new(0, 0.15, 0), rgb(255, 120, 30))
	Builder.pyramid(model, "Cone", (base * CFrame.new(0, 0.3, 0)).Position, 1.4, 2.6, rgb(255, 120, 30))
end

function Props.car(parent: Instance, base: CFrame, color: Color3, wrecked: boolean?)
	local model = Builder.model(parent, "Car")
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	piece(model, "Body", Vector3.new(6, 2.2, 12), at(0, 1.9, 0), color)
	piece(model, "Cabin", Vector3.new(5.4, 2, 5.5), at(0, 4, 0.8), color)
	piece(model, "Windshield", Vector3.new(5.2, 1.4, 0.2), at(0, 4.1, -2.0), rgb(140, 200, 230))
	piece(model, "BackWindow", Vector3.new(5.2, 1.4, 0.2), at(0, 4.1, 3.6), rgb(140, 200, 230))
	piece(model, "Bumper", Vector3.new(6.2, 0.6, 0.6), at(0, 1.2, -6.1), STEEL)
	piece(model, "Bumper", Vector3.new(6.2, 0.6, 0.6), at(0, 1.2, 6.1), STEEL)
	piece(model, "Light", Vector3.new(1.2, 0.6, 0.2), at(-2.1, 2.2, -6.05), rgb(255, 240, 160), Enum.Material.Neon)
	piece(model, "Light", Vector3.new(1.2, 0.6, 0.2), at(2.1, 2.2, -6.05), rgb(255, 240, 160), Enum.Material.Neon)
	if wrecked then
		piece(model, "Dent", Vector3.new(6.1, 1, 3), at(0, 2.4, -3.5) * CFrame.Angles(math.rad(-12), 0, 0), color:Lerp(BLACK, 0.35))
	end
	for _, x in { -3, 3 } do
		for _, z in { -3.8, 3.8 } do
			if not (wrecked and x == 3 and z == -3.8) then
				wheel(model, at(x, 1.2, z), 2.4, 1)
			end
		end
	end
end

function Props.container(parent: Instance, base: CFrame, color: Color3)
	local model = Builder.model(parent, "Container")
	piece(model, "Box", Vector3.new(8, 8.5, 20), base * CFrame.new(0, 4.25, 0), color)
	for _, x in { -4.05, 4.05 } do
		for z = -8, 8, 4 do
			piece(model, "Rib", Vector3.new(0.2, 8, 0.6), base * CFrame.new(x, 4.25, z), color:Lerp(BLACK, 0.2))
		end
	end
	piece(model, "Doors", Vector3.new(7.6, 8, 0.2), base * CFrame.new(0, 4.25, 10.05), color:Lerp(BLACK, 0.12))
end

function Props.crusher(parent: Instance, base: CFrame)
	local model = Builder.model(parent, "Crusher")
	piece(model, "Base", Vector3.new(10, 4, 10), base * CFrame.new(0, 2, 0), rgb(250, 200, 40))
	for _, x in { -4.5, 4.5 } do
		piece(model, "Pillar", Vector3.new(1.2, 12, 1.2), base * CFrame.new(x, 8, 4), DARK)
	end
	piece(model, "Top", Vector3.new(11, 1.5, 3), base * CFrame.new(0, 14, 4), DARK)
	piece(model, "Press", Vector3.new(8, 2, 8), base * CFrame.new(0, 10, 0), DARK)
	piece(model, "Cube", Vector3.new(4, 3, 4), base * CFrame.new(0, 5.5, 0) * CFrame.Angles(0, 0.3, 0), rgb(200, 70, 60))
	piece(model, "Stripe", Vector3.new(10.1, 0.8, 10.1), base * CFrame.new(0, 3.2, 0), BLACK)
end

function Props.fridge(parent: Instance, base: CFrame, color: Color3)
	local model = Builder.model(parent, "Fridge")
	piece(model, "Body", Vector3.new(4, 8, 3.5), base * CFrame.new(0, 4, 0), color)
	piece(model, "Split", Vector3.new(4.05, 0.2, 3.55), base * CFrame.new(0, 5.6, 0), color:Lerp(BLACK, 0.2))
	piece(model, "Handle", Vector3.new(0.3, 2, 0.4), base * CFrame.new(1.5, 6.8, -1.9), STEEL)
	piece(model, "Handle", Vector3.new(0.3, 2.5, 0.4), base * CFrame.new(1.5, 3.4, -1.9), STEEL)
end

function Props.washer(parent: Instance, base: CFrame, color: Color3)
	local model = Builder.model(parent, "Washer")
	piece(model, "Body", Vector3.new(4, 4.5, 4), base * CFrame.new(0, 2.25, 0), color)
	piece(model, "Door", Vector3.new(0.3, 2.6, 2.6), base * CFrame.new(0, 2.1, -2.05) * CFrame.Angles(0, math.rad(90), 0), rgb(120, 180, 220), nil, Enum.PartType.Cylinder)
	piece(model, "Panel", Vector3.new(4, 0.8, 0.3), base * CFrame.new(0, 4.1, -2.0), DARK)
end

function Props.tv(parent: Instance, base: CFrame, color: Color3, scale: number?)
	local s = scale or 1
	local model = Builder.model(parent, "TV")
	piece(model, "Body", Vector3.new(5, 4, 3.5) * s, base * CFrame.new(0, 2 * s + 0.6 * s, 0), color)
	piece(model, "Screen", Vector3.new(4, 3, 0.2) * s, base * CFrame.new(0, 2 * s + 0.6 * s, -1.8 * s), rgb(80, 220, 255), Enum.Material.Neon)
	piece(model, "Leg", Vector3.new(0.4, 0.6, 0.4) * s, base * CFrame.new(-1.8 * s, 0.3 * s, 0), DARK)
	piece(model, "Leg", Vector3.new(0.4, 0.6, 0.4) * s, base * CFrame.new(1.8 * s, 0.3 * s, 0), DARK)
	piece(model, "Antenna", Vector3.new(0.2, 2.5, 0.2) * s, base * CFrame.new(-0.6 * s, 5.2 * s, 0) * CFrame.Angles(0, 0, math.rad(25)), DARK)
	piece(model, "Antenna", Vector3.new(0.2, 2.5, 0.2) * s, base * CFrame.new(0.6 * s, 5.2 * s, 0) * CFrame.Angles(0, 0, math.rad(-25)), DARK)
end

function Props.toaster(parent: Instance, base: CFrame, scale: number)
	local s = scale
	local model = Builder.model(parent, "GiantToaster")
	piece(model, "Body", Vector3.new(10, 7, 6) * s, base * CFrame.new(0, 3.5 * s, 0), rgb(220, 225, 235))
	for _, x in { -2.2, 2.2 } do
		piece(model, "Slot", Vector3.new(3, 0.3, 4) * s, base * CFrame.new(x * s, 7.05 * s, 0), DARK)
		piece(model, "Toast", Vector3.new(2.6, 3, 0.8) * s, base * CFrame.new(x * s, 8.3 * s, 0), rgb(210, 150, 80))
	end
	piece(model, "Lever", Vector3.new(0.6, 1, 1.4) * s, base * CFrame.new(5.2 * s, 4.5 * s, 0), BLACK)
end

function Props.serverRack(parent: Instance, base: CFrame, glow: Color3)
	local model = Builder.model(parent, "ServerRack")
	piece(model, "Body", Vector3.new(4, 9, 4), base * CFrame.new(0, 4.5, 0), rgb(40, 42, 50))
	for i = 0, 5 do
		piece(model, "Light", Vector3.new(3, 0.25, 0.2), base * CFrame.new(0, 1.5 + i * 1.3, -2.05), glow, Enum.Material.Neon)
	end
end

function Props.monitor(parent: Instance, base: CFrame, scale: number, screen: Color3)
	local s = scale
	local model = Builder.model(parent, "GiantMonitor")
	piece(model, "Stand", Vector3.new(6, 0.8, 4) * s, base * CFrame.new(0, 0.4 * s, 0), DARK)
	piece(model, "Neck", Vector3.new(1.2, 5, 1.2) * s, base * CFrame.new(0, 3 * s, 0.5 * s), DARK)
	piece(model, "Frame", Vector3.new(16, 10, 1) * s, base * CFrame.new(0, 10 * s, 0), rgb(30, 30, 35))
	piece(model, "Screen", Vector3.new(15, 9, 0.2) * s, base * CFrame.new(0, 10 * s, -0.55 * s), screen, Enum.Material.Neon)
end

function Props.chip(parent: Instance, base: CFrame, size: number)
	local model = Builder.model(parent, "Chip")
	piece(model, "Body", Vector3.new(size, 1, size), base * CFrame.new(0, 1.2, 0), rgb(30, 30, 35))
	piece(model, "Dot", Vector3.new(size * 0.2, 0.1, size * 0.2), base * CFrame.new(-size * 0.3, 1.75, -size * 0.3), WHITE)
	local legs = math.max(2, math.floor(size / 1.5))
	for i = 1, legs do
		local offset = -size / 2 + (i - 0.5) * size / legs
		for _, side in { -1, 1 } do
			piece(model, "Leg", Vector3.new(0.4, 0.9, 0.8), base * CFrame.new(offset, 0.45, side * (size / 2 + 0.3)), STEEL)
		end
	end
end

function Props.boatHull(parent: Instance, base: CFrame, color: Color3)
	local model = Builder.model(parent, "BoatWreck")
	piece(model, "Hull", Vector3.new(10, 5, 22), base * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, math.rad(12)), color)
	Builder.wedge(model, { Name = "Bow", Size = Vector3.new(10, 5, 8), CFrame = base * CFrame.new(0, 2.5, -15) * CFrame.Angles(0, 0, math.rad(12)), Color = color })
	piece(model, "Stripe", Vector3.new(10.1, 0.8, 22.1), base * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, math.rad(12)), WHITE)
	piece(model, "Cabin", Vector3.new(6, 4, 6), base * CFrame.new(0.8, 7, 4) * CFrame.Angles(0, 0, math.rad(12)), WHITE)
	piece(model, "Mast", Vector3.new(0.8, 10, 0.8), base * CFrame.new(1.8, 11, -4) * CFrame.Angles(0, 0, math.rad(12)), rgb(140, 100, 60))
end

function Props.anchor(parent: Instance, base: CFrame, scale: number)
	local s = scale
	local model = Builder.model(parent, "Anchor")
	local color = rgb(60, 62, 70)
	piece(model, "Shaft", Vector3.new(1.2, 10, 1.2) * s, base * CFrame.new(0, 6 * s, 0), color)
	piece(model, "Bar", Vector3.new(6, 1, 1) * s, base * CFrame.new(0, 9.5 * s, 0), color)
	piece(model, "Ring", Vector3.new(0.6, 2.4, 2.4) * s, base * CFrame.new(0, 11.8 * s, 0) * CFrame.Angles(0, math.rad(90), 0), color, nil, Enum.PartType.Cylinder)
	piece(model, "Crown", Vector3.new(8, 1.2, 1.2) * s, base * CFrame.new(0, 1.4 * s, 0), color)
	for _, side in { -1, 1 } do
		Builder.wedge(model, {
			Name = "Fluke",
			Size = Vector3.new(1.2, 3, 2) * s,
			CFrame = base * CFrame.new(side * 4 * s, 2.4 * s, 0) * CFrame.Angles(0, math.rad(side * 90), 0),
			Color = color,
		})
	end
end

function Props.lighthouse(parent: Instance, base: CFrame)
	local model = Builder.model(parent, "Lighthouse")
	piece(model, "Rock", Vector3.new(14, 3, 14), base * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0.4, 0), rgb(140, 140, 150))
	for i = 0, 5 do
		piece(model, "Tower", Vector3.new(5, 7 - i * 0.4, 7 - i * 0.4), base * CFrame.new(0, 5.5 + i * 5, 0) * CFrame.Angles(0, 0, math.rad(90)), if i % 2 == 0 then rgb(230, 60, 60) else WHITE, nil, Enum.PartType.Cylinder)
	end
	piece(model, "Lamp", Vector3.new(4, 4, 4), base * CFrame.new(0, 35, 0), rgb(255, 240, 150), Enum.Material.Neon)
	Builder.pyramid(model, "Roof", (base * CFrame.new(0, 37, 0)).Position, 6, 4, rgb(230, 60, 60))
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 2
	light.Color = rgb(255, 240, 180)
	light.Parent = model:FindFirstChild("Lamp")
end

function Props.dock(parent: Instance, base: CFrame, length: number)
	local model = Builder.model(parent, "Dock")
	piece(model, "Deck", Vector3.new(8, 0.8, length), base * CFrame.new(0, 1.2, 0), rgb(170, 120, 75))
	for z = -length / 2 + 2, length / 2 - 2, 6 do
		for _, x in { -3.6, 3.6 } do
			piece(model, "Post", Vector3.new(1, 3, 1), base * CFrame.new(x, 0.8, z), rgb(120, 85, 55))
		end
	end
end

function Props.ufo(parent: Instance, base: CFrame, scale: number)
	local s = scale
	local model = Builder.model(parent, "UFO")
	local tilt = base * CFrame.new(0, 4 * s, 0) * CFrame.Angles(math.rad(14), 0, math.rad(8))
	piece(model, "Disc", Vector3.new(2, 24, 24) * s, tilt * CFrame.Angles(0, 0, math.rad(90)), rgb(190, 195, 210), nil, Enum.PartType.Cylinder)
	piece(model, "Rim", Vector3.new(1, 26, 26) * s, tilt * CFrame.new(0, -0.6 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(120, 125, 140), nil, Enum.PartType.Cylinder)
	piece(model, "Dome", Vector3.new(4, 11, 11) * s, tilt * CFrame.new(0, 2.6 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(120, 255, 200), Enum.Material.Neon, Enum.PartType.Cylinder)
	for i = 0, 7 do
		local angle = i * math.pi / 4
		piece(model, "Light", Vector3.new(1.2, 0.6, 1.2) * s, tilt * CFrame.new(math.cos(angle) * 11 * s, -0.4 * s, math.sin(angle) * 11 * s), rgb(255, 80, 200), Enum.Material.Neon)
	end
end

function Props.satellite(parent: Instance, base: CFrame)
	local model = Builder.model(parent, "SatelliteDish")
	piece(model, "Post", Vector3.new(1, 6, 1), base * CFrame.new(0, 3, 0), STEEL)
	piece(model, "Dish", Vector3.new(0.6, 7, 7), base * CFrame.new(0, 7, 0) * CFrame.Angles(0, 0, math.rad(55)), WHITE, nil, Enum.PartType.Cylinder)
	piece(model, "Arm", Vector3.new(0.3, 0.3, 3), base * CFrame.new(-1, 8.2, 0) * CFrame.Angles(0, math.rad(90), math.rad(-35)), STEEL)
end

function Props.crystal(parent: Instance, base: CFrame, color: Color3, height: number)
	local model = Builder.model(parent, "Crystal")
	piece(model, "Shard", Vector3.new(height * 0.35, height, height * 0.35), base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0.15, 0.6, 0.1), color, Enum.Material.Neon)
	piece(model, "Shard", Vector3.new(height * 0.25, height * 0.6, height * 0.25), base * CFrame.new(height * 0.3, height * 0.3, 0) * CFrame.Angles(0, 0.2, -0.5), color, Enum.Material.Neon)
end

function Props.rocket(parent: Instance, base: CFrame)
	local model = Builder.model(parent, "RocketWreck")
	local lying = base * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(8))
	piece(model, "Body", Vector3.new(26, 6, 6), lying, WHITE, nil, Enum.PartType.Cylinder)
	piece(model, "Band", Vector3.new(3, 6.2, 6.2), lying * CFrame.new(5, 0, 0), rgb(230, 60, 60), nil, Enum.PartType.Cylinder)
	piece(model, "Nose", Vector3.new(4, 4, 4), lying * CFrame.new(-14, 0, 0) * CFrame.Angles(0, 0, 0.785), rgb(230, 60, 60))
	for _, angle in { 0, 120, 240 } do
		local fin = lying * CFrame.new(12, 0, 0) * CFrame.Angles(math.rad(angle), 0, 0)
		Builder.wedge(model, { Name = "Fin", Size = Vector3.new(0.6, 4, 5), CFrame = fin * CFrame.new(0, 4, 0) * CFrame.Angles(0, math.rad(90), 0), Color = rgb(230, 60, 60) })
	end
end

-- The hub's landmark: a giant friendly scrap robot.
function Props.robotStatue(parent: Instance, base: CFrame)
	local model = Builder.model(parent, "ScrapRobotStatue")
	local body = rgb(240, 160, 50)
	local trim = rgb(70, 160, 230)
	piece(model, "Plinth", Vector3.new(18, 3, 18), base * CFrame.new(0, 1.5, 0), rgb(200, 195, 185))
	for _, x in { -3.5, 3.5 } do
		piece(model, "Leg", Vector3.new(3.5, 9, 3.5), base * CFrame.new(x, 7.5, 0), DARK)
		piece(model, "Foot", Vector3.new(4.5, 2, 6), base * CFrame.new(x, 4, -0.8), body)
	end
	piece(model, "Torso", Vector3.new(12, 10, 7), base * CFrame.new(0, 17, 0), body)
	piece(model, "Chest", Vector3.new(6, 4, 0.4), base * CFrame.new(0, 18, -3.6), trim, Enum.Material.Neon)
	for _, x in { -8, 8 } do
		piece(model, "Arm", Vector3.new(3, 9, 3), base * CFrame.new(x, 16, 0) * CFrame.Angles(0, 0, math.rad(if x < 0 then -15 else 15)), DARK)
		piece(model, "Hand", Vector3.new(4, 3, 4), base * CFrame.new(x * 1.18, 11, 0), body)
	end
	piece(model, "Neck", Vector3.new(3, 2, 3), base * CFrame.new(0, 23, 0), DARK)
	piece(model, "Head", Vector3.new(9, 7, 7), base * CFrame.new(0, 27.5, 0), body)
	for _, x in { -2.2, 2.2 } do
		piece(model, "Eye", Vector3.new(2, 2, 0.4), base * CFrame.new(x, 28.2, -3.6), trim, Enum.Material.Neon)
	end
	piece(model, "Mouth", Vector3.new(4, 0.8, 0.4), base * CFrame.new(0, 25.6, -3.6), DARK)
	piece(model, "Antenna", Vector3.new(0.6, 4, 0.6), base * CFrame.new(0, 33, 0), DARK)
	piece(model, "Bulb", Vector3.new(1.6, 1.6, 1.6), base * CFrame.new(0, 35.5, 0), rgb(255, 80, 80), Enum.Material.Neon)
end

function Props.lamp(parent: Instance, base: CFrame, color: Color3?)
	local model = Builder.model(parent, "LampPost")
	piece(model, "Pole", Vector3.new(0.8, 14, 0.8), base * CFrame.new(0, 7, 0), DARK)
	local bulb = piece(model, "Bulb", Vector3.new(2, 1.4, 2), base * CFrame.new(0, 14.4, 0), color or rgb(255, 230, 160), Enum.Material.Neon)
	bulb.CastShadow = false
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 1.2
	light.Color = color or rgb(255, 230, 160)
	light.Parent = bulb
end

return Props
