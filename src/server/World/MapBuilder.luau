--!strict
-- Builds the whole scrapyard out of anchored parts.
--
-- Runs automatically when the server starts if Workspace has no "Junkyard" model.
-- To bake the map into the place permanently (so you can hand-edit it in Studio),
-- paste this into the Studio command bar while NOT playtesting, then save:
--   require(game.ServerScriptService.Server.World.MapBuilder).build()
--
-- Layout (north is -Z):
--   South gate + spawn (z ~ 185) -> road north -> Hub plaza (z ~ 70) with SELL (west) and SHOP (east)
--   Front Heap (centre), Car Graveyard (north-west), Back Lot (north-east, rarer finds)

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Builder = require(script.Parent.Builder)

local MapBuilder = {}

local rng = Random.new(1337) -- fixed seed: same layout every time

local C = {
	Dirt = Color3.fromRGB(122, 98, 72),
	Gravel = Color3.fromRGB(150, 140, 125),
	Road = Color3.fromRGB(70, 68, 66),
	Concrete = Color3.fromRGB(170, 168, 160),
	Rust = Color3.fromRGB(150, 75, 40),
	DarkRust = Color3.fromRGB(105, 55, 35),
	Steel = Color3.fromRGB(150, 155, 165),
	DarkSteel = Color3.fromRGB(80, 84, 92),
	Yellow = Color3.fromRGB(245, 190, 40),
	Black = Color3.fromRGB(28, 28, 30),
	Green = Color3.fromRGB(60, 200, 90),
	Blue = Color3.fromRGB(50, 130, 230),
	White = Color3.fromRGB(255, 255, 255),
}

local CAR_COLORS = {
	Color3.fromRGB(150, 60, 50),
	Color3.fromRGB(70, 100, 140),
	Color3.fromRGB(90, 120, 80),
	Color3.fromRGB(190, 160, 90),
	Color3.fromRGB(120, 110, 105),
}

local JUNK_COLORS = {
	C.Rust,
	C.DarkRust,
	C.Steel,
	C.DarkSteel,
	Color3.fromRGB(200, 120, 60), -- copper
	Color3.fromRGB(60, 110, 70), -- circuit green
	Color3.fromRGB(180, 170, 60), -- faded yellow
}

local MAP_HALF = 170 -- fence runs along +-MAP_HALF
local GATE_HALF = 14

local function ground(parent: Instance)
	Builder.part(parent, {
		Name = "Ground",
		Size = Vector3.new(460, 4, 460),
		CFrame = CFrame.new(0, -2, 10),
		Color = C.Dirt,
		Material = Enum.Material.Ground,
	})
	-- Patches of gravel break up the flat dirt.
	for _ = 1, 14 do
		local size = rng:NextNumber(18, 40)
		Builder.part(parent, {
			Name = "GravelPatch",
			Size = Vector3.new(size, 0.1, size * rng:NextNumber(0.6, 1.2)),
			CFrame = CFrame.new(rng:NextNumber(-150, 150), 0.02, rng:NextNumber(-150, 150))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Color = C.Gravel,
			Material = Enum.Material.Pebble,
			CastShadow = false,
		})
	end
end

local function fenceSegment(parent: Instance, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	local look = CFrame.lookAt(mid, to)
	Builder.part(parent, {
		Name = "FencePanel",
		Size = Vector3.new(0.3, 9, length),
		CFrame = look + Vector3.new(0, 4.5, 0),
		Color = C.DarkSteel,
		Material = Enum.Material.DiamondPlate,
		Transparency = 0.15,
	})
	Builder.part(parent, {
		Name = "FenceRail",
		Size = Vector3.new(0.5, 0.5, length),
		CFrame = look + Vector3.new(0, 9.2, 0),
		Color = C.Rust,
		Material = Enum.Material.CorrodedMetal,
	})
	Builder.cylinder(parent, "FencePost", from + Vector3.new(0, 5, 0), 10, 0.9, C.Rust, Enum.Material.CorrodedMetal)
end

local function perimeterFence(parent: Instance)
	local folder = Builder.folder(parent, "Fence")
	local step = 34
	local corners = {
		Vector3.new(-MAP_HALF, 0, MAP_HALF),
		Vector3.new(-MAP_HALF, 0, -MAP_HALF),
		Vector3.new(MAP_HALF, 0, -MAP_HALF),
		Vector3.new(MAP_HALF, 0, MAP_HALF),
	}
	-- West, north and east walls.
	for i = 1, 3 do
		local a, b = corners[i], corners[i + 1]
		local count = math.ceil((b - a).Magnitude / step)
		for s = 0, count - 1 do
			fenceSegment(folder, a:Lerp(b, s / count), a:Lerp(b, (s + 1) / count))
		end
	end
	-- South wall, split around the gate.
	for _, side in { -1, 1 } do
		local outer = Vector3.new(side * MAP_HALF, 0, MAP_HALF)
		local inner = Vector3.new(side * GATE_HALF, 0, MAP_HALF)
		local count = math.ceil((inner - outer).Magnitude / step)
		for s = 0, count - 1 do
			fenceSegment(folder, outer:Lerp(inner, s / count), outer:Lerp(inner, (s + 1) / count))
		end
	end
	Builder.cylinder(folder, "FencePost", Vector3.new(MAP_HALF, 5, MAP_HALF), 10, 0.9, C.Rust, Enum.Material.CorrodedMetal)
end

local function entrance(parent: Instance)
	local model = Builder.model(parent, "Entrance")
	local z = MAP_HALF
	for _, side in { -1, 1 } do
		Builder.part(model, {
			Name = "GatePillar",
			Size = Vector3.new(3, 18, 3),
			CFrame = CFrame.new(side * (GATE_HALF + 1.5), 9, z),
			Color = C.Yellow,
			Material = Enum.Material.DiamondPlate,
		})
		-- Hazard stripes on the pillars.
		for stripe = 0, 3 do
			Builder.part(model, {
				Name = "Stripe",
				Size = Vector3.new(3.1, 1, 3.1),
				CFrame = CFrame.new(side * (GATE_HALF + 1.5), 2 + stripe * 2.2, z),
				Color = C.Black,
				Material = Enum.Material.SmoothPlastic,
			})
		end
		-- An open gate swung back against the fence.
		Builder.part(model, {
			Name = "GateDoor",
			Size = Vector3.new(0.4, 8, 12),
			CFrame = CFrame.new(side * (GATE_HALF + 3.5), 4, z - 6.5),
			Color = C.DarkSteel,
			Material = Enum.Material.DiamondPlate,
			Transparency = 0.2,
		})
	end
	Builder.part(model, {
		Name = "ArchBeam",
		Size = Vector3.new(GATE_HALF * 2 + 6, 2, 3),
		CFrame = CFrame.new(0, 18, z),
		Color = C.Yellow,
		Material = Enum.Material.DiamondPlate,
	})
	Builder.sign(model, "JUNKYARD SIMULATOR", Vector3.new(0, 22, z + 0.2), Vector3.new(0, 0, 1), Vector2.new(30, 6), C.Rust, C.Yellow)
	Builder.sign(model, "JUNKYARD SIMULATOR", Vector3.new(0, 22, z - 0.2), Vector3.new(0, 0, -1), Vector2.new(30, 6), C.Rust, C.Yellow)

	-- Spawn pad outside the gate.
	Builder.part(model, {
		Name = "SpawnPad",
		Size = Vector3.new(44, 0.4, 30),
		CFrame = CFrame.new(0, 0.1, z + 18),
		Color = C.Concrete,
		Material = Enum.Material.Concrete,
	})
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.5, z + 20) * CFrame.Angles(0, 0, 0)
	spawn.Color = C.Yellow
	spawn.Material = Enum.Material.DiamondPlate
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = model
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	Builder.cylinder(model, "SignPost", Vector3.new(-14, 1.5, z + 8.3), 3, 0.6, C.DarkSteel, Enum.Material.Metal)
	Builder.sign(model, "Collect scrap > Sell it > Buy upgrades!", Vector3.new(-14, 5, z + 8), Vector3.new(0, 0, 1), Vector2.new(14, 4), C.DarkSteel, C.White)
end

local function lightPole(parent: Instance, position: Vector3)
	local model = Builder.model(parent, "LightPole")
	Builder.cylinder(model, "Pole", position + Vector3.new(0, 8, 0), 16, 0.8, C.DarkSteel, Enum.Material.Metal)
	Builder.part(model, {
		Name = "Arm",
		Size = Vector3.new(0.5, 0.5, 4),
		CFrame = CFrame.new(position + Vector3.new(0, 16, 1.5)),
		Color = C.DarkSteel,
		Material = Enum.Material.Metal,
	})
	local lamp = Builder.part(model, {
		Name = "Lamp",
		Size = Vector3.new(1.6, 0.6, 2.2),
		CFrame = CFrame.new(position + Vector3.new(0, 15.6, 3)),
		Color = Color3.fromRGB(255, 220, 160),
		Material = Enum.Material.Neon,
		CastShadow = false,
	})
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 110
	light.Range = 40
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 210, 150)
	light.Parent = lamp
end

local function paths(parent: Instance)
	local folder = Builder.folder(parent, "Paths")
	local road, gravel = C.Road, Color3.fromRGB(105, 98, 90)
	-- Main road: gate -> hub.
	Builder.path(folder, Vector3.new(0, 0, MAP_HALF + 8), Vector3.new(0, 0, 95), 18, road, Enum.Material.Asphalt)
	-- Hub -> Front Heap.
	Builder.path(folder, Vector3.new(0, 0, 45), Vector3.new(0, 0, 18), 12, gravel, Enum.Material.Pebble)
	-- Hub -> Car Graveyard and Back Lot.
	Builder.path(folder, Vector3.new(-20, 0, 50), Vector3.new(-80, 0, -10), 10, gravel, Enum.Material.Pebble)
	Builder.path(folder, Vector3.new(20, 0, 50), Vector3.new(78, 0, -62), 10, gravel, Enum.Material.Pebble)
	-- Ring connection between the outer zones through the north.
	Builder.path(folder, Vector3.new(-80, 0, -60), Vector3.new(60, 0, -110), 8, gravel, Enum.Material.Pebble, 0)

	for _, z in { 160, 130, 100 } do
		lightPole(folder, Vector3.new(-12, 0, z))
		lightPole(folder, Vector3.new(12, 0, z))
	end
end

local function hub(parent: Instance)
	local model = Builder.model(parent, "HubPlaza")
	Builder.part(model, {
		Name = "Plaza",
		Size = Vector3.new(120, 0.3, 54),
		CFrame = CFrame.new(0, 0.1, 70),
		Color = C.Concrete,
		Material = Enum.Material.Concrete,
	})
	-- Painted guide lines on the plaza pointing to each station.
	Builder.part(model, {
		Name = "GuideLineWest",
		Size = Vector3.new(30, 0.05, 1),
		CFrame = CFrame.new(-22, 0.28, 70),
		Color = C.Green,
		Material = Enum.Material.Neon,
		CastShadow = false,
	})
	Builder.part(model, {
		Name = "GuideLineEast",
		Size = Vector3.new(30, 0.05, 1),
		CFrame = CFrame.new(22, 0.28, 70),
		Color = C.Blue,
		Material = Enum.Material.Neon,
		CastShadow = false,
	})
	lightPole(model, Vector3.new(-30, 0, 92))
	lightPole(model, Vector3.new(30, 0, 92))
end

local function sellStation(parent: Instance)
	local model = Builder.model(parent, "SellStation")
	local base = CFrame.new(-48, 0, 70) * CFrame.Angles(0, math.rad(-90), 0) -- faces +X (towards the plaza)
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end

	Builder.part(model, {
		Name = "Scale",
		Size = Vector3.new(18, 0.6, 12),
		CFrame = at(0, 0.3, -6),
		Color = C.Steel,
		Material = Enum.Material.DiamondPlate,
	})
	-- Booth: back wall, side walls, roof, counter.
	Builder.part(model, { Name = "BackWall", Size = Vector3.new(20, 12, 1), CFrame = at(0, 6, 6), Color = C.Green, Material = Enum.Material.Metal })
	Builder.part(model, { Name = "SideWall", Size = Vector3.new(1, 12, 10), CFrame = at(-9.5, 6, 1.5), Color = C.Green, Material = Enum.Material.Metal })
	Builder.part(model, { Name = "SideWall", Size = Vector3.new(1, 12, 10), CFrame = at(9.5, 6, 1.5), Color = C.Green, Material = Enum.Material.Metal })
	Builder.part(model, { Name = "Roof", Size = Vector3.new(22, 1, 13), CFrame = at(0, 12.5, 0.5), Color = C.DarkSteel, Material = Enum.Material.CorrodedMetal })
	Builder.part(model, { Name = "Counter", Size = Vector3.new(14, 3.5, 2.5), CFrame = at(0, 1.75, -2), Color = C.DarkSteel, Material = Enum.Material.DiamondPlate })
	-- Coin bin on the counter.
	Builder.cylinder(model, "CashBin", (at(4, 4.1, -2)).Position, 1.4, 2.2, C.Yellow, Enum.Material.Metal)

	Builder.sign(model, "$ SELL SCRAP $", (at(0, 15.5, -0.2)).Position, base.LookVector, Vector2.new(18, 4.5), C.Green, C.White)

	-- A hydraulic crusher next to the booth for flavour.
	Builder.part(model, { Name = "CrusherBase", Size = Vector3.new(8, 4, 8), CFrame = at(-15, 2, 2), Color = C.Yellow, Material = Enum.Material.DiamondPlate })
	Builder.part(model, { Name = "CrusherPress", Size = Vector3.new(7, 2, 7), CFrame = at(-15, 9, 2), Color = C.DarkSteel, Material = Enum.Material.Metal })
	for _, x in { -18, -12 } do
		Builder.part(model, { Name = "CrusherPillar", Size = Vector3.new(1, 10, 1), CFrame = at(x, 6, 5.5), Color = C.DarkSteel, Material = Enum.Material.Metal })
	end
	Builder.part(model, { Name = "CrushedCube", Size = Vector3.new(3, 2.5, 3), CFrame = at(-15, 5.25, 2) * CFrame.Angles(0, 0.3, 0), Color = C.Rust, Material = Enum.Material.CorrodedMetal })

	local anchor = Builder.part(model, {
		Name = "PromptAnchor",
		Size = Vector3.new(2, 2, 2),
		CFrame = at(0, 3, -3.5),
		Transparency = 1,
		CanCollide = false,
	})
	Builder.prompt(anchor, "SellPrompt", "Sell All Scrap", "Scrap Buyer", 0.3, 12)
	Builder.billboard(anchor, "SELL", C.Green, 16)
	CollectionService:AddTag(model, "SellStation")
end

local function upgradeShop(parent: Instance)
	local model = Builder.model(parent, "UpgradeShop")
	local base = CFrame.new(48, 0, 70) * CFrame.Angles(0, math.rad(90), 0) -- faces -X (towards the plaza)
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end

	Builder.part(model, { Name = "Floor", Size = Vector3.new(20, 0.6, 16), CFrame = at(0, 0.3, 2), Color = C.Concrete, Material = Enum.Material.Concrete })
	Builder.part(model, { Name = "BackWall", Size = Vector3.new(20, 13, 1), CFrame = at(0, 6.5, 9.5), Color = C.Blue, Material = Enum.Material.Metal })
	Builder.part(model, { Name = "SideWall", Size = Vector3.new(1, 13, 16), CFrame = at(-9.5, 6.5, 2), Color = C.Blue, Material = Enum.Material.Metal })
	Builder.part(model, { Name = "SideWall", Size = Vector3.new(1, 13, 16), CFrame = at(9.5, 6.5, 2), Color = C.Blue, Material = Enum.Material.Metal })
	Builder.part(model, { Name = "Roof", Size = Vector3.new(22, 1, 18), CFrame = at(0, 13.5, 2), Color = C.DarkSteel, Material = Enum.Material.Metal })
	-- Striped awning over the front.
	for i = 0, 5 do
		Builder.part(model, {
			Name = "Awning",
			Size = Vector3.new(22 / 6, 0.4, 5),
			CFrame = at(-11 + 22 / 12 + i * 22 / 6, 12, -8) * CFrame.Angles(math.rad(-20), 0, 0),
			Color = if i % 2 == 0 then C.Yellow else C.White,
			Material = Enum.Material.Fabric,
		})
	end
	Builder.part(model, { Name = "Counter", Size = Vector3.new(14, 3.5, 2.5), CFrame = at(0, 1.75, -4), Color = C.DarkSteel, Material = Enum.Material.Wood })
	-- Display rack of tools on the back wall.
	for i, color in { Color3.fromRGB(140, 90, 60), C.Steel, Color3.fromRGB(200, 50, 50), C.Yellow, Color3.fromRGB(80, 220, 255) } do
		Builder.part(model, {
			Name = "DisplayTool",
			Size = Vector3.new(0.6, 5, 0.6),
			CFrame = at(-6 + (i - 1) * 3, 6, 8.8) * CFrame.Angles(0, 0, math.rad(15)),
			Color = color,
			Material = if i == 5 then Enum.Material.Neon else Enum.Material.Metal,
		})
	end
	Builder.sign(model, "UPGRADE SHOP", (at(0, 16.5, -6)).Position, base.LookVector, Vector2.new(18, 4.5), C.Blue, C.Yellow)

	local anchor = Builder.part(model, {
		Name = "PromptAnchor",
		Size = Vector3.new(2, 2, 2),
		CFrame = at(0, 3, -5.5),
		Transparency = 1,
		CanCollide = false,
	})
	Builder.prompt(anchor, "ShopPrompt", "Open Shop", "Upgrade Shop", 0, 12)
	Builder.billboard(anchor, "UPGRADES", C.Yellow, 17)
	CollectionService:AddTag(model, "UpgradeShop")
end

-- A collectable pile: a dirt mound plus loose junk, with a prompt in the middle.
local function scrapPile(parent: Instance, position: Vector3, zoneName: string, zoneLuck: number)
	local model = Builder.model(parent, "ScrapPile")
	model:SetAttribute("ZoneName", zoneName)
	model:SetAttribute("ZoneLuck", zoneLuck)

	local mound = Builder.part(model, {
		Name = "Mound",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(9, 9, 9),
		CFrame = CFrame.new(position + Vector3.new(0, -3, 0)),
		Color = Color3.fromRGB(95, 78, 60),
		Material = Enum.Material.Ground,
	})
	mound:SetAttribute("Persistent", true)

	for _ = 1, rng:NextInteger(5, 7) do
		local offset = Vector3.new(rng:NextNumber(-2.5, 2.5), rng:NextNumber(1, 2.6), rng:NextNumber(-2.5, 2.5))
		local rotation = CFrame.Angles(rng:NextNumber(-0.8, 0.8), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.8, 0.8))
		local color = JUNK_COLORS[rng:NextInteger(1, #JUNK_COLORS)]
		local kind = rng:NextInteger(1, 3)
		if kind == 1 then
			Builder.part(model, {
				Name = "Plate",
				Size = Vector3.new(rng:NextNumber(1.5, 3), 0.3, rng:NextNumber(1.5, 3.5)),
				CFrame = CFrame.new(position + offset) * rotation,
				Color = color,
				Material = Enum.Material.CorrodedMetal,
				CanCollide = false,
			})
		elseif kind == 2 then
			Builder.part(model, {
				Name = "Pipe",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(rng:NextNumber(2, 4), 0.6, 0.6),
				CFrame = CFrame.new(position + offset) * rotation,
				Color = color,
				Material = Enum.Material.Metal,
				CanCollide = false,
			})
		else
			Builder.part(model, {
				Name = "Chunk",
				Size = Vector3.new(rng:NextNumber(0.8, 1.6), rng:NextNumber(0.8, 1.6), rng:NextNumber(0.8, 1.6)),
				CFrame = CFrame.new(position + offset) * rotation,
				Color = color,
				Material = Enum.Material.DiamondPlate,
				CanCollide = false,
			})
		end
	end

	local anchor = Builder.part(model, {
		Name = "PromptAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(position + Vector3.new(0, 2.5, 0)),
		Transparency = 1,
		CanCollide = false,
	})
	model.PrimaryPart = anchor
	Builder.prompt(anchor, "CollectPrompt", "Collect", zoneName, 0.5, 10)

	-- A faint sparkle so piles read as interactive from a distance.
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "Glint"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 1.5
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Speed = NumberRange.new(0.5, 1)
	sparkle.Size = NumberSequence.new(0.6)
	sparkle.LightEmission = 1
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 230, 150))
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = anchor

	CollectionService:AddTag(model, "ScrapPile")
end

local function rustyCar(parent: Instance, cframe: CFrame, missingWheel: boolean)
	local model = Builder.model(parent, "RustyCar")
	local color = CAR_COLORS[rng:NextInteger(1, #CAR_COLORS)]
	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end
	Builder.part(model, { Name = "Body", Size = Vector3.new(6, 2.2, 12), CFrame = at(0, 1.9, 0), Color = color, Material = Enum.Material.CorrodedMetal })
	Builder.part(model, { Name = "Cabin", Size = Vector3.new(5.4, 2, 5.5), CFrame = at(0, 4, 0.8), Color = color, Material = Enum.Material.CorrodedMetal })
	Builder.part(model, { Name = "Windows", Size = Vector3.new(5.5, 1.3, 5.6), CFrame = at(0, 4.2, 0.8), Color = Color3.fromRGB(40, 50, 55), Material = Enum.Material.Glass, Transparency = 0.3 })
	Builder.part(model, { Name = "Bumper", Size = Vector3.new(6.2, 0.6, 0.6), CFrame = at(0, 1.2, -6.1), Color = C.DarkSteel, Material = Enum.Material.Metal })
	Builder.part(model, { Name = "RustPatch", Size = Vector3.new(6.05, 1, 3), CFrame = at(0, 2.2, -3), Color = C.Rust, Material = Enum.Material.CorrodedMetal })
	for _, x in { -3, 3 } do
		for _, z in { -3.8, 3.8 } do
			if not (missingWheel and x == 3 and z == -3.8) then
				Builder.part(model, {
					Name = "Wheel",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(1, 2.4, 2.4),
					CFrame = at(x, 1.2, z),
					Color = C.Black,
					Material = Enum.Material.SmoothPlastic,
				})
			end
		end
	end
end

local function barrel(parent: Instance, position: Vector3, color: Color3, tipped: boolean)
	if tipped then
		Builder.part(parent, {
			Name = "Barrel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.6, 2.6, 2.6),
			CFrame = CFrame.new(position + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Color = color,
			Material = Enum.Material.CorrodedMetal,
		})
	else
		Builder.cylinder(parent, "Barrel", position + Vector3.new(0, 1.8, 0), 3.6, 2.6, color, Enum.Material.CorrodedMetal)
	end
end

local function tireStack(parent: Instance, position: Vector3, height: number)
	for i = 0, height - 1 do
		Builder.part(parent, {
			Name = "Tire",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 3.2, 3.2),
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-0.2, 0.2), 0.5 + i, rng:NextNumber(-0.2, 0.2)))
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = C.Black,
			Material = Enum.Material.SmoothPlastic,
		})
	end
end

local function container(parent: Instance, cframe: CFrame, color: Color3)
	local model = Builder.model(parent, "ShippingContainer")
	Builder.part(model, { Name = "Box", Size = Vector3.new(8, 8.5, 20), CFrame = cframe * CFrame.new(0, 4.25, 0), Color = color, Material = Enum.Material.CorrodedMetal })
	for _, x in { -4.05, 4.05 } do
		for z = -8, 8, 4 do
			Builder.part(model, { Name = "Rib", Size = Vector3.new(0.2, 8, 0.6), CFrame = cframe * CFrame.new(x, 4.25, z), Color = color:Lerp(Color3.new(0, 0, 0), 0.25), Material = Enum.Material.Metal })
		end
	end
	Builder.part(model, { Name = "Doors", Size = Vector3.new(7.6, 8, 0.2), CFrame = cframe * CFrame.new(0, 4.25, 10.05), Color = color:Lerp(Color3.new(0, 0, 0), 0.15), Material = Enum.Material.Metal })
end

local function crane(parent: Instance, position: Vector3)
	local model = Builder.model(parent, "Crane")
	Builder.part(model, { Name = "Base", Size = Vector3.new(10, 3, 10), CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0)), Color = C.Yellow, Material = Enum.Material.DiamondPlate })
	Builder.part(model, { Name = "Mast", Size = Vector3.new(3, 34, 3), CFrame = CFrame.new(position + Vector3.new(0, 20, 0)), Color = C.Yellow, Material = Enum.Material.Metal })
	Builder.part(model, { Name = "Cab", Size = Vector3.new(5, 4, 5), CFrame = CFrame.new(position + Vector3.new(0, 36, 2)), Color = C.Yellow, Material = Enum.Material.Metal })
	Builder.part(model, { Name = "Jib", Size = Vector3.new(2, 2, 34), CFrame = CFrame.new(position + Vector3.new(0, 39, 12)), Color = C.Yellow, Material = Enum.Material.Metal })
	Builder.part(model, { Name = "Counterweight", Size = Vector3.new(4, 4, 5), CFrame = CFrame.new(position + Vector3.new(0, 38, -5)), Color = C.DarkSteel, Material = Enum.Material.Concrete })
	Builder.part(model, { Name = "Cable", Size = Vector3.new(0.2, 18, 0.2), CFrame = CFrame.new(position + Vector3.new(0, 29, 26)), Color = C.Black, Material = Enum.Material.Metal, CanCollide = false })
	Builder.cylinder(model, "Magnet", position + Vector3.new(0, 19.5, 26), 1.2, 6, C.DarkSteel, Enum.Material.Metal)
	-- A car dangling from the magnet.
	rustyCar(model, CFrame.new(position + Vector3.new(0, 14.5, 26)) * CFrame.Angles(math.rad(8), math.rad(30), math.rad(5)), true)
end

local function zoneSign(parent: Instance, text: string, position: Vector3, facing: Vector3, color: Color3)
	Builder.cylinder(parent, "SignPost", position + Vector3.new(0, 3, 0), 6, 0.6, C.DarkSteel, Enum.Material.Metal)
	Builder.sign(parent, text, position + Vector3.new(0, 7, 0), facing, Vector2.new(13, 3.5), color, C.White)
end

local function frontHeap(parent: Instance)
	local folder = Builder.folder(parent, "Zone_FrontHeap")
	local center = Vector3.new(0, 0, 0)
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2 + 0.3
		scrapPile(folder, center + Vector3.new(math.cos(angle) * 18, 0, math.sin(angle) * 18), "Front Heap", 1)
	end
	-- A big central junk heap that is just scenery.
	Builder.part(folder, {
		Name = "BigHeap",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(14, 14, 14),
		CFrame = CFrame.new(center + Vector3.new(0, -3, 0)),
		Color = Color3.fromRGB(90, 72, 55),
		Material = Enum.Material.Ground,
	})
	barrel(folder, center + Vector3.new(2, 3.5, 1), C.Blue, true)
	tireStack(folder, center + Vector3.new(-2, 3.5, -1), 2)
	zoneSign(folder, "FRONT HEAP", Vector3.new(9, 0, 30), Vector3.new(0, 0, 1), C.DarkRust)
end

local function carGraveyard(parent: Instance)
	local folder = Builder.folder(parent, "Zone_CarGraveyard")
	local center = Vector3.new(-100, 0, -40)
	local pilePositions = {
		Vector3.new(-14, 0, 18),
		Vector3.new(14, 0, 14),
		Vector3.new(-22, 0, -8),
		Vector3.new(20, 0, -14),
		Vector3.new(-4, 0, -26),
		Vector3.new(4, 0, 2),
	}
	for _, offset in pilePositions do
		scrapPile(folder, center + offset, "Car Graveyard", 1.15)
	end
	local carSpots = {
		{ Vector3.new(-32, 0, 28), 20, false },
		{ Vector3.new(-36, 0, 0), 95, true },
		{ Vector3.new(30, 0, 30), -35, false },
		{ Vector3.new(34, 0, -34), 60, true },
		{ Vector3.new(-26, 0, -38), 150, false },
		{ Vector3.new(12, 0, -40), -10, false },
	}
	for _, spot in carSpots do
		local offset, yaw, missing = spot[1] :: Vector3, spot[2] :: number, spot[3] :: boolean
		rustyCar(folder, CFrame.new(center + offset) * CFrame.Angles(0, math.rad(yaw), math.rad(if missing then 4 else 0)), missing)
	end
	-- Stacked wreck.
	rustyCar(folder, CFrame.new(center + Vector3.new(-36, 5.1, 0)) * CFrame.Angles(0, math.rad(80), math.rad(-3)), false)
	tireStack(folder, center + Vector3.new(0, 0, 32), 4)
	tireStack(folder, center + Vector3.new(4, 0, 34), 3)
	tireStack(folder, center + Vector3.new(26, 0, 4), 2)
	zoneSign(folder, "CAR GRAVEYARD", Vector3.new(-72, 0, -2), Vector3.new(1, 0, 0.6), C.DarkRust)
end

local function backLot(parent: Instance)
	local folder = Builder.folder(parent, "Zone_BackLot")
	local center = Vector3.new(100, 0, -100)
	local pilePositions = {
		Vector3.new(-18, 0, 14),
		Vector3.new(10, 0, 22),
		Vector3.new(-20, 0, -14),
		Vector3.new(4, 0, -4),
		Vector3.new(24, 0, -2),
		Vector3.new(-6, 0, -28),
	}
	for _, offset in pilePositions do
		scrapPile(folder, center + offset, "Back Lot", 1.35)
	end
	crane(folder, center + Vector3.new(40, 0, -30))
	local containerColors = { Color3.fromRGB(180, 60, 50), Color3.fromRGB(40, 100, 160), Color3.fromRGB(60, 130, 80), Color3.fromRGB(200, 140, 40) }
	container(folder, CFrame.new(center + Vector3.new(52, 0, 30)), containerColors[1])
	container(folder, CFrame.new(center + Vector3.new(52, 0, 52)), containerColors[2])
	container(folder, CFrame.new(center + Vector3.new(52, 8.5, 40)), containerColors[3])
	container(folder, CFrame.new(center + Vector3.new(-30, 0, -50)) * CFrame.Angles(0, math.rad(90), 0), containerColors[4])
	zoneSign(folder, "BACK LOT  (rare finds!)", Vector3.new(72, 0, -56), Vector3.new(-0.6, 0, 1), Color3.fromRGB(110, 60, 170))
end

local function decorations(parent: Instance)
	local folder = Builder.folder(parent, "Decorations")
	-- Containers lining the west fence.
	local colors = { Color3.fromRGB(180, 60, 50), Color3.fromRGB(40, 100, 160), Color3.fromRGB(60, 130, 80) }
	for i, z in { 120, 90, -100, -130 } do
		container(folder, CFrame.new(-MAP_HALF + 6, 0, z), colors[(i - 1) % #colors + 1])
	end
	-- Barrel clusters.
	local barrelColors = { C.Blue, Color3.fromRGB(190, 50, 40), C.Yellow, Color3.fromRGB(60, 120, 60) }
	local clusters = {
		Vector3.new(-62, 0, 92),
		Vector3.new(62, 0, 92),
		Vector3.new(-30, 0, 140),
		Vector3.new(140, 0, 40),
		Vector3.new(-140, 0, 40),
		Vector3.new(30, 0, -60),
	}
	for _, center in clusters do
		for _ = 1, rng:NextInteger(3, 5) do
			local offset = Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
			barrel(folder, center + offset, barrelColors[rng:NextInteger(1, #barrelColors)], rng:NextNumber() < 0.25)
		end
	end
	-- Loose tires, placed by hand so they never block the road, plaza or piles.
	local tires = {
		Vector3.new(-28, 0, 120),
		Vector3.new(30, 0, 150),
		Vector3.new(-60, 0, 30),
		Vector3.new(55, 0, 20),
		Vector3.new(-120, 0, 80),
		Vector3.new(120, 0, 90),
		Vector3.new(-30, 0, -100),
		Vector3.new(0, 0, -140),
		Vector3.new(150, 0, -20),
		Vector3.new(-150, 0, -10),
		Vector3.new(80, 0, 150),
		Vector3.new(-90, 0, 150),
	}
	for i, pos in tires do
		if i % 2 == 0 then
			tireStack(folder, pos, rng:NextInteger(1, 3))
		else
			Builder.part(folder, {
				Name = "Tire",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1, 3.2, 3.2),
				CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(10)),
				Color = C.Black,
				Material = Enum.Material.SmoothPlastic,
			})
		end
	end
	-- Extra parked wrecks near the entrance road.
	rustyCar(folder, CFrame.new(-40, 0, 140) * CFrame.Angles(0, math.rad(75), 0), false)
	rustyCar(folder, CFrame.new(44, 0, 130) * CFrame.Angles(0, math.rad(-100), 0), true)
	-- Scrap mountains in the corners for silhouette.
	for _, pos in { Vector3.new(-140, 0, -145), Vector3.new(145, 0, 140), Vector3.new(-145, 0, 150) } do
		Builder.part(folder, {
			Name = "ScrapMountain",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(40, 40, 40),
			CFrame = CFrame.new(pos + Vector3.new(0, -8, 0)),
			Color = Color3.fromRGB(85, 70, 58),
			Material = Enum.Material.Ground,
		})
	end
end

function MapBuilder.setupLighting()
	Lighting.ClockTime = 16.2
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(70, 60, 55)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 125, 110)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
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
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 8

	local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(230, 200, 170)
	atmosphere.Decay = Color3.fromRGB(150, 110, 90)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.2

	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 1.6

	local color = ensure("ColorCorrectionEffect", "ColorCorrection") :: ColorCorrectionEffect
	color.Saturation = 0.15
	color.Contrast = 0.08
	color.TintColor = Color3.fromRGB(255, 245, 235)

	local rays = ensure("SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = 0.06
	rays.Spread = 0.6
end

function MapBuilder.build(): Model
	local existing = Workspace:FindFirstChild("Junkyard")
	if existing and existing:IsA("Model") then
		return existing
	end

	local map = Instance.new("Model")
	map.Name = "Junkyard"

	ground(map)
	perimeterFence(map)
	entrance(map)
	paths(map)
	hub(map)
	sellStation(map)
	upgradeShop(map)
	frontHeap(map)
	carGraveyard(map)
	backLot(map)
	decorations(map)

	map.Parent = Workspace
	MapBuilder.setupLighting()
	return map
end

return MapBuilder
