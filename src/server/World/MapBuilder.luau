--!strict
-- Builds the whole scrapyard out of anchored, solid-colour parts in a rounded
-- "toy" style (see ReplicatedStorage.Shared.Art).
--
-- The published place already contains the baked result (map/), so this only
-- runs when Workspace has no "Junkyard" model. To rebuild the map in Studio's
-- edit mode, delete Workspace.Junkyard and run in the command bar:
--   require(game.ServerScriptService.Server.World.MapBuilder).build()
--
-- Layout (north is -Z): the Hub sits at z 100..-100. Six 200-stud zone lots
-- follow north along one main road, each behind a gate that unlocks with cash.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local BotArt = require(Shared.Art.BotArt)
local Items = require(Shared.Art.Items)
local Bots = require(Shared.Bots)
local Kit = require(Shared.Art.Kit)
local Zones = require(Shared.Zones)
local Builder = require(script.Parent.Builder)
local Props = require(script.Parent.Props)
local StationArt = require(script.Parent.StationArt)

local MapBuilder = {}

local rng = Random.new(2024) -- fixed seed: same layout every time

local HALF_WIDTH = 100
local ZONE_LENGTH = 200
local HUB_SOUTH = 100
local FIRST_GATE = -100
local END_Z = FIRST_GATE - ZONE_LENGTH * #Zones.List

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local CN = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local C = {
	Grass = rgb(125, 205, 95),
	GrassDark = rgb(100, 185, 80),
	Plaza = rgb(232, 226, 210),
	PlazaTrim = rgb(205, 198, 182),
	Road = rgb(90, 94, 108),
	RoadLine = rgb(255, 215, 70),
	Curb = rgb(240, 240, 245),
	Fence = rgb(120, 128, 145),
	Post = rgb(255, 200, 60),
	White = rgb(255, 255, 255),
	Dark = rgb(60, 62, 75),
}

local function gateZ(order: number): number
	return FIRST_GATE - (order - 1) * ZONE_LENGTH
end

-- A CFrame on the ground at (x, z) whose front (-Z / LookVector) faces `dir`.
local function facing(x: number, z: number, dir: Vector3): CFrame
	local pos = Vector3.new(x, 0, z)
	return CFrame.lookAt(pos, pos + dir)
end

local EAST = Vector3.new(1, 0, 0)
local WEST = Vector3.new(-1, 0, 0)
local SOUTH = Vector3.new(0, 0, 1)

local function randomDir(): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

local BRIGHT = { rgb(235, 75, 65), rgb(65, 140, 235), rgb(255, 205, 55), rgb(85, 195, 95), rgb(245, 245, 245), rgb(255, 140, 200), rgb(155, 95, 235) }
local function bright(): Color3
	return BRIGHT[rng:NextInteger(1, #BRIGHT)]
end

---------------------------------------------------------------- ground & fences

local function ground(map: Instance)
	local folder = Builder.folder(map, "Ground")
	local length = HUB_SOUTH - END_Z + 700
	Builder.box(folder, "Grass", Vector3.new(1000, 4, length), Vector3.new(0, -2.05, (HUB_SOUTH + END_Z) / 2), C.Grass)

	Builder.box(folder, "HubFloor", Vector3.new(HALF_WIDTH * 2, 1, HUB_SOUTH - FIRST_GATE), Vector3.new(0, -0.45, (HUB_SOUTH + FIRST_GATE) / 2), C.Plaza)
	Kit.cylY(folder, CN(0, 0.08, 10), 0.15, 70, C.PlazaTrim, { Shadow = false })
	Kit.cylY(folder, CN(0, 0.12, 10), 0.15, 62, C.Plaza, { Shadow = false })
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		Kit.cylY(folder, CN(math.cos(a) * 33, 0.18, 10 + math.sin(a) * 33), 0.1, 3, if i % 2 == 0 then rgb(255, 205, 70) else rgb(120, 200, 255), { Shadow = false })
	end

	for _, zone in Zones.List do
		local z0 = gateZ(zone.Order)
		Builder.box(folder, "ZoneFloor", Vector3.new(HALF_WIDTH * 2, 1, ZONE_LENGTH), Vector3.new(0, -0.45, z0 - ZONE_LENGTH / 2), zone.Theme.Ground)
	end

	-- Main road with curbs and a dashed centre line.
	local roadLength = FIRST_GATE - END_Z
	local roadMid = (FIRST_GATE + END_Z) / 2
	Builder.box(folder, "Road", Vector3.new(22, 0.2, roadLength), Vector3.new(0, 0.08, roadMid), C.Road).CastShadow = false
	for _, side in { -1, 1 } do
		Kit.pill(folder, CN(side * 11.5, 0.3, roadMid) * ANG(0, rad(90), 0), roadLength, 0.9, C.Curb, { Collide = false })
	end
	for z = FIRST_GATE - 6, END_Z + 6, -14 do
		Kit.box(folder, CN(0, 0.2, z), Vector3.new(1.2, 0.15, 7), C.RoadLine, { Shadow = false })
	end
end

local function fenceRun(folder: Instance, from: Vector3, to: Vector3)
	local step = 25
	local length = (to - from).Magnitude
	local count = math.max(1, math.ceil(length / step))
	for i = 0, count - 1 do
		local a = from:Lerp(to, i / count)
		local b = from:Lerp(to, (i + 1) / count)
		local mid = (a + b) / 2
		local look = CFrame.lookAt(mid, b)
		local segment = (b - a).Magnitude
		Builder.part(folder, { Name = "FenceWall", Size = Vector3.new(0.8, 12, segment), CFrame = look + Vector3.new(0, 6, 0), Color = C.Fence, Transparency = 1 })
		for _, y in { 3.2, 6.6, 10.0 } do
			Kit.pill(folder, look * CN(0, y, 0) * ANG(0, rad(90), 0), segment, if y == 10.0 then 1.1 else 0.8, if y == 10.0 then C.Post else C.Fence)
		end
		Kit.cylY(folder, CN(a + Vector3.new(0, 5.5, 0)), 11, 1.8, C.Post, { Collide = true })
		Kit.ball(folder, CN(a + Vector3.new(0, 11.2, 0)), 2.2, Kit.shade(C.Post, 0.15))
	end
	Kit.cylY(folder, CN(to + Vector3.new(0, 5.5, 0)), 11, 1.8, C.Post, { Collide = true })
	Kit.ball(folder, CN(to + Vector3.new(0, 11.2, 0)), 2.2, Kit.shade(C.Post, 0.15))
end

local function fences(map: Instance)
	local folder = Builder.folder(map, "Fence")
	fenceRun(folder, Vector3.new(-HALF_WIDTH, 0, HUB_SOUTH), Vector3.new(-HALF_WIDTH, 0, END_Z))
	fenceRun(folder, Vector3.new(HALF_WIDTH, 0, HUB_SOUTH), Vector3.new(HALF_WIDTH, 0, END_Z))
	fenceRun(folder, Vector3.new(-HALF_WIDTH, 0, HUB_SOUTH), Vector3.new(HALF_WIDTH, 0, HUB_SOUTH))
	fenceRun(folder, Vector3.new(-HALF_WIDTH, 0, END_Z), Vector3.new(HALF_WIDTH, 0, END_Z))
end

local function zoneSpawn(parent: Instance, zoneId: string, position: Vector3)
	local part = Builder.part(parent, {
		Name = "ZoneSpawn_" .. zoneId,
		Size = Vector3.new(6, 1, 6),
		CFrame = CFrame.lookAt(position, position - SOUTH),
		Transparency = 1,
		CanCollide = false,
	})
	part:SetAttribute("ZoneId", zoneId)
	CollectionService:AddTag(part, "ZoneSpawn")
end

---------------------------------------------------------------- hub

local function hub(map: Instance)
	local folder = Builder.folder(map, "Hub")

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, 72), Vector3.new(0, 0.5, 0))
	spawn.Color = rgb(255, 205, 60)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn:SetAttribute("ZoneId", "Hub")
	CollectionService:AddTag(spawn, "ZoneSpawn")
	-- Visible spawn pad.
	Kit.cylY(folder, CN(0, 0.3, 72), 0.6, 16, rgb(255, 205, 60), { Collide = true })
	Kit.cylY(folder, CN(0, 0.45, 72), 0.6, 12, rgb(255, 230, 130))
	Kit.ring(folder, CN(0, 0.75, 72), 6.5, 0.5, rgb(255, 255, 255), 16, { Neon = true }, false)

	-- Giant BoltBot statue in the middle of the plaza.
	Kit.cylY(folder, CN(0, 1.2, 10), 2.4, 22, C.PlazaTrim, { Collide = true })
	Kit.cylY(folder, CN(0, 2.7, 10), 0.6, 19, rgb(120, 200, 255))
	local statue = BotArt.build("BoltBot")
	Kit.scale(statue, 7)
	Kit.placeOnGround(statue, facing(0, 10, SOUTH) * CN(0, 3, 0))
	for _, part in statue:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = true
		end
	end
	statue.Name = "BoltBotStatue"
	statue.Parent = folder
	Builder.sign(folder, "JUNKYARD SIMULATOR", Vector3.new(0, 34, 22), SOUTH, Vector2.new(34, 6), rgb(255, 140, 50), C.White)

	StationArt.upgradeShop(folder, facing(-72, 22, EAST))
	StationArt.toolShop(folder, facing(72, 22, WEST))
	for i, crate in Bots.Crates do
		StationArt.crateStand(folder, crate, facing(-48 + (i - 1) * 32, -52, SOUTH))
	end
	Builder.sign(folder, "SCRAP BOT CRATES", Vector3.new(0, 24, -66), SOUTH, Vector2.new(30, 5), rgb(160, 95, 235), C.White)
	StationArt.rebirthAltar(folder, facing(-72, -66, EAST))
	StationArt.questBoard(folder, facing(72, -64, WEST))
	StationArt.leaderboard(folder, facing(-60, 76, Vector3.new(1, 0, -0.5).Unit))
	StationArt.codeTerminal(folder, facing(62, 76, Vector3.new(-1, 0, -0.5).Unit))

	for _, pos in { Vector3.new(-36, 0, 46), Vector3.new(36, 0, 46), Vector3.new(-38, 0, -22), Vector3.new(38, 0, -22) } do
		Props.planter(folder, CN(pos), rng)
	end
	for _, pos in { Vector3.new(-16, 0, 92), Vector3.new(16, 0, 92), Vector3.new(-16, 0, -88), Vector3.new(16, 0, -88), Vector3.new(-52, 0, -2), Vector3.new(52, 0, -2) } do
		Props.lamp(folder, CN(pos))
	end
	Props.bench(folder, facing(-22, 58, SOUTH))
	Props.bench(folder, facing(22, 58, SOUTH))
	for _, pos in { Vector3.new(-90, 0, 90), Vector3.new(90, 0, 90), Vector3.new(-90, 0, -90), Vector3.new(90, 0, -90), Vector3.new(-90, 0, 40), Vector3.new(90, 0, 45) } do
		Props.bush(folder, CN(pos), rng:NextNumber(1, 1.4), C.GrassDark)
	end
	Builder.sign(folder, "Collect scrap  >  Sell it  >  Upgrade  >  Unlock new yards!", Vector3.new(0, 7, 93), Vector3.new(0, 0, -1), Vector2.new(26, 3.5), C.Dark, C.White)
	for _, x in { -9, 9 } do
		Kit.cylY(folder, CN(x, 2.5, 93.4), 5, 0.8, C.Dark)
	end
end

---------------------------------------------------------------- zone themes

type ThemeFn = (folder: Instance, z0: number) -> ()

-- Positions measured from the zone's gate: (x, depth) -> world (x, z0 - depth).
local function at(z0: number, x: number, depth: number, dir: Vector3?): CFrame
	return facing(x, z0 - depth, dir or SOUTH)
end

local THEMES: { [string]: ThemeFn } = {}

THEMES.ScrapHeap = function(folder, z0)
	Props.giant(folder, "TinCan", at(z0, 82, 110, WEST), 5)
	Props.giant(folder, "CopperWire", at(z0, -82, 110, EAST), 4.5)
	Props.giant(folder, "BentNail", at(z0, 84, 165, randomDir()), 4)
	for _, side in { -1, 1 } do
		for _, depth in { 30, 75, 160 } do
			for i = 1, 3 do
				Props.barrel(folder, at(z0, side * 86 + rng:NextNumber(-3, 3), depth + i * 3.4, randomDir()), bright(), i == 3)
			end
		end
		for _, depth in { 70, 150 } do
			Props.tires(folder, at(z0, side * 45, depth), rng:NextInteger(1, 4))
		end
	end
	Props.crusher(folder, at(z0, -84, 185, EAST))
end

THEMES.CarGraveyard = function(folder, z0)
	for _, side in { -1, 1 } do
		for _, depth in { 25, 55, 150, 182 } do
			Props.car(folder, at(z0, side * 86, depth, randomDir()), bright(), rng:NextNumber() < 0.5)
		end
		for _, depth in { 70, 110, 150 } do
			Props.cone(folder, at(z0, side * 15, depth))
		end
	end
	for level = 0, 2 do
		Props.car(folder, at(z0, -84, 112, Vector3.new(0.15 * level, 0, 1).Unit) * CN(0, level * 3.6, 0), bright(), level == 0)
	end
	Props.giant(folder, "Hubcap", at(z0, 82, 112, WEST), 5)
	Props.giant(folder, "SparkPlug", at(z0, 45, 70), 3.2)
	Props.tires(folder, at(z0, -45, 150), 5)
	Props.tires(folder, at(z0, 45, 150), 3)
end

THEMES.ApplianceAlley = function(folder, z0)
	local pastel = { rgb(248, 248, 250), rgb(255, 185, 205), rgb(155, 228, 218), rgb(252, 228, 135), rgb(185, 205, 255) }
	for _, side in { -1, 1 } do
		for _, depth in { 25, 50, 155, 180 } do
			local cf = at(z0, side * 86, depth, -Vector3.new(side, 0, 0))
			local color = pastel[rng:NextInteger(1, #pastel)]
			if rng:NextNumber() < 0.5 then
				Props.fridge(folder, cf, color)
			else
				Props.washer(folder, cf, color)
			end
		end
		Props.washer(folder, at(z0, side * 45, 150, randomDir()), pastel[rng:NextInteger(1, #pastel)])
	end
	Props.giant(folder, "Toaster", at(z0, 80, 110, WEST), 4.2)
	Props.giant(folder, "RetroTV", at(z0, -80, 110, EAST), 4.2)
	Props.giant(folder, "MicrowaveDoor", at(z0, 45, 70, randomDir()), 2.6)
end

THEMES.ElectronicsDump = function(folder, z0)
	local glows = { rgb(80, 255, 160), rgb(80, 205, 255), rgb(255, 100, 210) }
	for _, side in { -1, 1 } do
		for _, depth in { 25, 45, 160, 180 } do
			Props.serverRack(folder, at(z0, side * 88, depth, -Vector3.new(side, 0, 0)), glows[rng:NextInteger(1, #glows)])
		end
		Builder.box(folder, "Trace", Vector3.new(0.6, 0.1, ZONE_LENGTH - 10), Vector3.new(side * 14, 0.12, z0 - ZONE_LENGTH / 2), glows[1], nil, Enum.Material.Neon).CastShadow = false
	end
	Props.giant(folder, "GraphicsCard", at(z0, -80, 110, EAST), 4.5)
	Props.giant(folder, "Keyboard", at(z0, 80, 110, WEST), 4)
	Props.giant(folder, "CircuitBoard", at(z0, 45, 70), 3.5)
	Props.giant(folder, "HardDrive", at(z0, -45, 150), 3)
end

THEMES.Shipyard = function(folder, z0)
	local water = Builder.box(folder, "Water", Vector3.new(26, 0.4, ZONE_LENGTH - 4), Vector3.new(86, 0.1, z0 - ZONE_LENGTH / 2), rgb(80, 175, 240))
	water.Transparency = 0.1
	for _, depth in { 40, 140 } do
		Props.dock(folder, at(z0, 78, depth, WEST) * ANG(0, rad(90), 0), 22)
	end
	Props.boat(folder, at(z0, 88, 90), rgb(225, 80, 70))
	Props.boat(folder, at(z0, 88, 178) * ANG(0, rad(8), 0), rgb(70, 125, 200))
	Props.lighthouse(folder, at(z0, -82, 110))
	Props.giant(folder, "Anchor", at(z0, -84, 30, EAST), 4.2)
	Props.giant(folder, "CaptainsWheel", at(z0, -84, 175, EAST), 3.6)
	for _, depth in { 70, 150 } do
		Props.barrel(folder, at(z0, -45, depth, randomDir()), rgb(70, 125, 200), true)
		Props.barrel(folder, at(z0, 45, depth, randomDir()), rgb(225, 80, 70), false)
	end
end

THEMES.CrashSite = function(folder, z0)
	local glows = { rgb(195, 100, 255), rgb(70, 235, 215), rgb(255, 120, 210) }
	Props.ufo(folder, at(z0, 80, 110), 1)
	for i = 0, 9 do
		local angle = i / 10 * math.pi * 2
		Props.rock(folder, CN(80 + math.cos(angle) * 18, 0, z0 - 110 + math.sin(angle) * 18), rng:NextNumber(1, 1.6), rgb(115, 95, 145))
	end
	Props.rocket(folder, at(z0, -82, 110, SOUTH))
	Props.giant(folder, "SpaceRock", at(z0, -45, 70), 3.5)
	Props.satellite(folder, at(z0, 45, 70))
	for _, side in { -1, 1 } do
		for _, depth in { 25, 55, 165, 185 } do
			Props.crystal(folder, at(z0, side * 88, depth), glows[rng:NextInteger(1, #glows)], rng:NextNumber(5, 9))
		end
		Props.crystal(folder, at(z0, side * 45, 150), glows[rng:NextInteger(1, #glows)], 6)
	end
end

-- Small life on the ground: grass tufts, flowers and loose bits of the zone's
-- scrap lying around, kept off the road and away from the piles' rows.
local function scatter(folder: Instance, zone: Zones.Zone, z0: number)
	local detail = Builder.folder(folder, "Detail")
	local grass = zone.Theme.Ground:Lerp(Color3.fromRGB(110, 200, 90), 0.55)
	local loose = StationArt.pileItems(zone)
	for _ = 1, 28 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x = side * rng:NextNumber(16, 96)
		local depth = rng:NextNumber(8, 195)
		-- Skip spots right on top of a pile row.
		local nearRow = false
		for _, row in { 50, 90, 130, 170 } do
			if math.abs(depth - row) < 7 and (math.abs(math.abs(x) - 28) < 8 or math.abs(math.abs(x) - 62) < 8) then
				nearRow = true
			end
		end
		if not nearRow then
			local base = CN(x, 0, z0 - depth)
			local roll = rng:NextNumber()
			if roll < 0.55 then
				for i = 1, 3 do
					Kit.pillBetween(detail, (base * CN((i - 2) * 0.35, 0, 0)).Position, (base * CN((i - 2) * 0.6, 1.1 + i % 2 * 0.4, (i - 2) * 0.2)).Position, 0.32, if i == 2 then Kit.shade(grass, 0.12) else grass)
				end
			elseif roll < 0.75 then
				Props.flowers(detail, base, rng)
			else
				local item = Items.build(loose[rng:NextInteger(1, #loose)])
				Kit.scale(item, 0.7)
				Kit.placeOnGround(item, base * ANG(0, rng:NextNumber(0, math.pi * 2), rad(rng:NextNumber(-25, 25))))
				for _, d in item:GetDescendants() do
					if d:IsA("ParticleEmitter") then
						d:Destroy()
					end
				end
				item.Parent = detail
			end
		end
	end
end

local function zoneLot(map: Instance, zone: Zones.Zone)
	local folder = Builder.folder(map, "Zone_" .. zone.Id)
	local z0 = gateZ(zone.Order)

	StationArt.gate(folder, zone, z0, HALF_WIDTH)
	zoneSpawn(folder, zone.Id, Vector3.new(0, 0.5, z0 - 14))
	StationArt.sellMachine(folder, at(z0, -40, 30, EAST), zone.Theme.Accent)

	for _, depth in { 50, 90, 130, 170 } do
		for _, x in { -62, -28, 28, 62 } do
			local pos = Vector3.new(x + rng:NextNumber(-5, 5), 0, z0 - depth + rng:NextNumber(-5, 5))
			StationArt.scrapPile(folder, zone, pos, rng)
		end
	end

	local theme = THEMES[zone.Id]
	if theme then
		theme(folder, z0)
	end
	scatter(folder, zone, z0)
	for _, depth in { 60, 140 } do
		Props.lamp(folder, at(z0, -14, depth), zone.Theme.Accent)
		Props.lamp(folder, at(z0, 14, depth + 40), zone.Theme.Accent)
	end
end

---------------------------------------------------------------- outside

local function scenery(map: Instance)
	local folder = Builder.folder(map, "Scenery")
	local leaves = { rgb(100, 190, 85), rgb(85, 175, 75), rgb(130, 210, 95), rgb(255, 170, 200) }
	for z = HUB_SOUTH + 40, END_Z - 40, -34 do
		for _, side in { -1, 1 } do
			local x = side * (HALF_WIDTH + rng:NextNumber(16, 55))
			local leaf = leaves[rng:NextInteger(1, if rng:NextNumber() < 0.15 then 4 else 3)]
			Props.tree(folder, CN(x, 0, z + rng:NextNumber(-10, 10)), rng:NextNumber(1.1, 1.7), leaf, rng)
			if rng:NextNumber() < 0.5 then
				Props.bush(folder, CN(x + side * rng:NextNumber(8, 16), 0, z + rng:NextNumber(-12, 12)), rng:NextNumber(1, 1.6), C.GrassDark)
			end
			if rng:NextNumber() < 0.3 then
				Props.flowers(folder, CN(side * (HALF_WIDTH + rng:NextNumber(6, 12)), 0, z + rng:NextNumber(-14, 14)), rng)
			end
		end
	end
	-- Rolling hills in the distance.
	for z = HUB_SOUTH + 80, END_Z - 80, -150 do
		for _, side in { -1, 1 } do
			local x = side * rng:NextNumber(260, 330)
			local size = rng:NextNumber(150, 220)
			Kit.ball(folder, CN(x, -size * 0.32, z), size, Kit.shade(C.Grass, rng:NextNumber(-0.12, 0.05)))
			Kit.ball(folder, CN(x + side * size * 0.3, -size * 0.3, z + size * 0.3), size * 0.7, Kit.shade(C.Grass, -0.08))
		end
	end
end

---------------------------------------------------------------- lighting

-- Toon / cel-shaded lighting: no environment reflections, bright coloured
-- ambient so shadows stay light and flat, crisp shadow edges, punchy grade.
function MapBuilder.setupLighting()
	Lighting.ClockTime = 14.2
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.4
	Lighting.Ambient = rgb(150, 140, 175)
	Lighting.OutdoorAmbient = rgb(175, 170, 200)
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	Lighting.ShadowSoftness = 0.08
	Lighting.GlobalShadows = true

	local function ensure(className: string, name: string): Instance
		local existing = Lighting:FindFirstChild(name)
		if existing and existing.ClassName == className then
			return existing
		end
		local instance = Instance.new(className)
		instance.Name = name
		instance.Parent = Lighting
		return instance
	end

	local sky = ensure("Sky", "Sky") :: Sky
	sky.SunAngularSize = 18
	sky.MoonAngularSize = 9

	local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.12
	atmosphere.Offset = 0.2
	atmosphere.Color = rgb(225, 235, 255)
	atmosphere.Decay = rgb(170, 190, 235)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.2

	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.45
	bloom.Size = 18
	bloom.Threshold = 1.4

	local color = ensure("ColorCorrectionEffect", "ColorCorrection") :: ColorCorrectionEffect
	color.Saturation = 0.32
	color.Contrast = 0.12
	color.Brightness = 0.04
	color.TintColor = rgb(255, 250, 245)

	local rays = ensure("SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = 0.02
	rays.Spread = 0.4
end

function MapBuilder.build(): Model
	local existing = Workspace:FindFirstChild("Junkyard")
	if existing and existing:IsA("Model") then
		return existing
	end

	local map = Instance.new("Model")
	map.Name = "Junkyard"
	ground(map)
	fences(map)
	hub(map)
	for _, zone in Zones.List do
		zoneLot(map, zone)
	end
	scenery(map)

	map.Parent = Workspace
	MapBuilder.setupLighting()
	return map
end

return MapBuilder
