--!strict
-- Builds the whole low-poly scrapyard out of anchored, solid-colour parts.
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

local Bots = require(ReplicatedStorage.Shared.Bots)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Builder = require(script.Parent.Builder)
local Props = require(script.Parent.Props)

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

local C = {
	Grass = rgb(120, 200, 95),
	GrassDark = rgb(95, 175, 80),
	Plaza = rgb(225, 220, 205),
	PlazaTrim = rgb(195, 188, 172),
	Road = rgb(85, 88, 98),
	RoadLine = rgb(250, 215, 70),
	Fence = rgb(110, 115, 128),
	Post = rgb(250, 195, 50),
	White = rgb(255, 255, 255),
	Dark = rgb(55, 58, 66),
	Green = rgb(70, 200, 100),
	Blue = rgb(60, 140, 235),
	Purple = rgb(170, 90, 240),
	Pink = rgb(255, 110, 190),
	Yellow = rgb(255, 205, 60),
	Orange = rgb(255, 140, 50),
	Wood = rgb(170, 120, 75),
}

local function gateZ(order: number): number
	return FIRST_GATE - (order - 1) * ZONE_LENGTH
end

-- A CFrame on the ground at (x, z) whose front (-Z / LookVector) faces `facing`.
local function facing(x: number, z: number, dir: Vector3): CFrame
	local pos = Vector3.new(x, 0, z)
	return CFrame.lookAt(pos, pos + dir)
end

local EAST = Vector3.new(1, 0, 0)
local WEST = Vector3.new(-1, 0, 0)
local SOUTH = Vector3.new(0, 0, 1)

---------------------------------------------------------------- ground & fences

local function ground(map: Instance)
	local folder = Builder.folder(map, "Ground")
	local length = HUB_SOUTH - END_Z + 600
	Builder.box(folder, "Grass", Vector3.new(900, 4, length), Vector3.new(0, -2.05, (HUB_SOUTH + END_Z) / 2), C.Grass)

	Builder.box(folder, "HubFloor", Vector3.new(HALF_WIDTH * 2, 1, HUB_SOUTH - FIRST_GATE), Vector3.new(0, -0.45, (HUB_SOUTH + FIRST_GATE) / 2), C.Plaza)
	-- Checker accents on the plaza.
	for x = -80, 80, 40 do
		for z = 80, -80, -40 do
			if (x // 40 + z // 40) % 2 == 0 then
				Builder.box(folder, "PlazaTile", Vector3.new(38, 0.2, 38), Vector3.new(x, 0.06, z), C.PlazaTrim).CastShadow = false
			end
		end
	end

	for _, zone in Zones.List do
		local z0 = gateZ(zone.Order)
		Builder.box(folder, "ZoneFloor", Vector3.new(HALF_WIDTH * 2, 1, ZONE_LENGTH), Vector3.new(0, -0.45, z0 - ZONE_LENGTH / 2), zone.Theme.Ground)
	end

	-- Main road from the hub to the far end, with dashed centre line.
	local roadLength = FIRST_GATE - END_Z
	Builder.box(folder, "Road", Vector3.new(22, 0.2, roadLength), Vector3.new(0, 0.08, (FIRST_GATE + END_Z) / 2), C.Road).CastShadow = false
	for z = FIRST_GATE - 6, END_Z + 6, -14 do
		Builder.box(folder, "RoadLine", Vector3.new(1, 0.1, 7), Vector3.new(0, 0.22, z), C.RoadLine).CastShadow = false
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
		Builder.part(folder, { Name = "FencePanel", Size = Vector3.new(0.6, 10, segment), CFrame = look + Vector3.new(0, 5, 0), Color = C.Fence })
		Builder.part(folder, { Name = "FenceRail", Size = Vector3.new(1, 1, segment), CFrame = look + Vector3.new(0, 10.3, 0), Color = C.Post })
		Builder.box(folder, "FencePost", Vector3.new(1.6, 12, 1.6), a + Vector3.new(0, 6, 0), C.Post)
	end
	Builder.box(folder, "FencePost", Vector3.new(1.6, 12, 1.6), to + Vector3.new(0, 6, 0), C.Post)
end

local function fences(map: Instance)
	local folder = Builder.folder(map, "Fence")
	fenceRun(folder, Vector3.new(-HALF_WIDTH, 0, HUB_SOUTH), Vector3.new(-HALF_WIDTH, 0, END_Z))
	fenceRun(folder, Vector3.new(HALF_WIDTH, 0, HUB_SOUTH), Vector3.new(HALF_WIDTH, 0, END_Z))
	fenceRun(folder, Vector3.new(-HALF_WIDTH, 0, HUB_SOUTH), Vector3.new(HALF_WIDTH, 0, HUB_SOUTH))
	fenceRun(folder, Vector3.new(-HALF_WIDTH, 0, END_Z), Vector3.new(HALF_WIDTH, 0, END_Z))
end

---------------------------------------------------------------- stations

local function sellStation(parent: Instance, base: CFrame, accent: Color3)
	local model = Builder.model(parent, "SellStation")
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	Builder.part(model, { Name = "Pad", Size = Vector3.new(16, 0.6, 12), CFrame = at(0, 0.3, -4), Color = C.Green })
	Builder.part(model, { Name = "PadTrim", Size = Vector3.new(17, 0.4, 13), CFrame = at(0, 0.2, -4), Color = C.White })
	Builder.part(model, { Name = "Back", Size = Vector3.new(16, 10, 1), CFrame = at(0, 5, 3), Color = accent })
	Builder.part(model, { Name = "Roof", Size = Vector3.new(18, 1, 8), CFrame = at(0, 10.5, 0), Color = C.Dark })
	for _, x in { -7.5, 7.5 } do
		Builder.part(model, { Name = "Pillar", Size = Vector3.new(1, 10, 1), CFrame = at(x, 5, -3), Color = C.White })
	end
	Builder.part(model, { Name = "Counter", Size = Vector3.new(10, 3.2, 2), CFrame = at(0, 1.6, 0), Color = C.White })
	Builder.part(model, { Name = "Coin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 3, 3), CFrame = at(0, 6.5, 2.3) * CFrame.Angles(0, math.rad(90), 0), Color = C.Yellow, Material = Enum.Material.Neon })
	Builder.sign(model, "$ SELL $", at(0, 13, -0.5).Position, base.LookVector, Vector2.new(14, 4), C.Green, C.White)

	local anchor = Builder.anchor(model, at(0, 3, -3).Position)
	Builder.prompt(anchor, "SellPrompt", "Sell Backpack", "Scrap Buyer", 0.25, 14)
	Builder.billboard(anchor, "SELL", C.Green, 14)
	CollectionService:AddTag(model, "SellStation")
end

local function shopBuilding(parent: Instance, name: string, tag: string, base: CFrame, wall: Color3, title: string, marker: string)
	local model = Builder.model(parent, name)
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	Builder.part(model, { Name = "Floor", Size = Vector3.new(22, 0.6, 16), CFrame = at(0, 0.3, 2), Color = C.PlazaTrim })
	Builder.part(model, { Name = "BackWall", Size = Vector3.new(22, 13, 1), CFrame = at(0, 6.5, 9.5), Color = wall })
	Builder.part(model, { Name = "SideWall", Size = Vector3.new(1, 13, 16), CFrame = at(-10.5, 6.5, 2), Color = wall })
	Builder.part(model, { Name = "SideWall", Size = Vector3.new(1, 13, 16), CFrame = at(10.5, 6.5, 2), Color = wall })
	Builder.part(model, { Name = "Roof", Size = Vector3.new(24, 1.2, 18), CFrame = at(0, 13.6, 2), Color = C.Dark })
	for i = 0, 5 do
		Builder.wedge(model, {
			Name = "Awning",
			Size = Vector3.new(4, 1.5, 4),
			CFrame = at(-10 + i * 4, 12, -8.5) * CFrame.Angles(0, math.rad(180), 0),
			Color = if i % 2 == 0 then C.White else C.Yellow,
		})
	end
	Builder.part(model, { Name = "Counter", Size = Vector3.new(14, 3.4, 2.4), CFrame = at(0, 1.7, -4), Color = C.Wood })
	Builder.sign(model, title, at(0, 17, -6).Position, base.LookVector, Vector2.new(20, 5), wall, C.Yellow)

	local anchor = Builder.anchor(model, at(0, 3, -6.5).Position)
	Builder.prompt(anchor, "ShopPrompt", "Open", title, 0, 13)
	Builder.billboard(anchor, marker, C.Yellow, 18)
	CollectionService:AddTag(model, tag)
	return model, at
end

local function crateStand(parent: Instance, crate: Bots.Crate, base: CFrame)
	local model = Builder.model(parent, "Crate_" .. crate.Id)
	model:SetAttribute("CrateId", crate.Id)
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	Builder.part(model, { Name = "Pedestal", Size = Vector3.new(12, 2, 12), CFrame = at(0, 1, 0), Color = C.Dark })
	Builder.part(model, { Name = "PedestalTop", Size = Vector3.new(11, 0.4, 11), CFrame = at(0, 2.2, 0), Color = crate.Color })
	local box = Builder.part(model, { Name = "Crate", Size = Vector3.new(7, 7, 7), CFrame = at(0, 5.9, 0) * CFrame.Angles(0, math.rad(20), 0), Color = crate.Color })
	box.Material = if crate.Id == "Galaxy" or crate.Id == "Gem" then Enum.Material.Neon else Enum.Material.SmoothPlastic
	for _, y in { 3.2, 8.6 } do
		Builder.part(model, { Name = "Band", Size = Vector3.new(7.2, 0.6, 7.2), CFrame = at(0, y, 0) * CFrame.Angles(0, math.rad(20), 0), Color = C.Dark })
	end
	Builder.part(model, { Name = "Lid", Size = Vector3.new(0.6, 7.2, 7.2), CFrame = at(0, 5.9, 0) * CFrame.Angles(0, math.rad(20), 0), Color = C.Dark })
	local price = if crate.Currency == "Gems" then `{crate.Price} Gems` else Formulas.formatCash(crate.Price)
	Builder.sign(model, `{crate.Name}\n{price}`, at(0, 13, 0).Position, base.LookVector, Vector2.new(11, 4.5), C.Dark, C.White)

	local anchor = Builder.anchor(model, at(0, 4, -7).Position)
	Builder.prompt(anchor, "OpenPrompt", `Open ({price})`, crate.Name, 0.4, 12)
	CollectionService:AddTag(model, "CrateStand")
end

local function rebirthAltar(parent: Instance, base: CFrame)
	local model = Builder.model(parent, "RebirthAltar")
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	Builder.part(model, { Name = "Step", Size = Vector3.new(20, 1, 20), CFrame = at(0, 0.5, 0), Color = rgb(90, 60, 130) })
	Builder.part(model, { Name = "Step", Size = Vector3.new(14, 1, 14), CFrame = at(0, 1.5, 0), Color = rgb(120, 80, 170) })
	Builder.part(model, { Name = "Crystal", Size = Vector3.new(4, 10, 4), CFrame = at(0, 8, 0) * CFrame.Angles(0, math.rad(45), 0), Color = C.Pink, Material = Enum.Material.Neon })
	Builder.pyramid(model, "CrystalTip", at(0, 13, 0).Position, 5.5, 4, C.Pink, 45)
	for _, x in { -6, 6 } do
		Builder.part(model, { Name = "Pillar", Size = Vector3.new(2, 9, 2), CFrame = at(x, 6, 4), Color = rgb(200, 180, 230) })
		Builder.part(model, { Name = "Orb", Size = Vector3.new(2.2, 2.2, 2.2), CFrame = at(x, 11.5, 4), Color = C.Purple, Material = Enum.Material.Neon })
	end
	Builder.sign(model, "REBIRTH", at(0, 17.5, 2).Position, base.LookVector, Vector2.new(14, 4), C.Purple, C.White)
	local anchor = Builder.anchor(model, at(0, 4, -6).Position)
	Builder.prompt(anchor, "OpenPrompt", "Rebirth", "Rebirth Altar", 0, 13)
	Builder.billboard(anchor, "REBIRTH", C.Pink, 18)
	CollectionService:AddTag(model, "RebirthAltar")
end

local function board(parent: Instance, name: string, tag: string, base: CFrame, title: string, color: Color3, withPrompt: string?)
	local model = Builder.model(parent, name)
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	for _, x in { -8, 8 } do
		Builder.part(model, { Name = "Leg", Size = Vector3.new(1.2, 16, 1.2), CFrame = at(x, 8, 0.6), Color = C.Dark })
	end
	local panel = Builder.part(model, { Name = "Board", Size = Vector3.new(18, 13, 0.8), CFrame = at(0, 10, 0), Color = color })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = panel
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.fromScale(1, 0.2)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = C.Yellow
	titleLabel.Text = title
	titleLabel.Parent = gui
	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromScale(0.05, 0.22)
	list.Size = UDim2.fromScale(0.9, 0.74)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.GothamBold
	list.TextScaled = true
	list.TextColor3 = C.White
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = if withPrompt then "Daily quests, the quest chain\nand login rewards!" else "Loading..."
	list.Parent = gui
	if withPrompt then
		local anchor = Builder.anchor(model, at(0, 3, -4).Position)
		Builder.prompt(anchor, "OpenPrompt", withPrompt, title, 0, 13)
	end
	CollectionService:AddTag(model, tag)
end

local function codeTerminal(parent: Instance, base: CFrame)
	local model = Builder.model(parent, "CodeTerminal")
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	Builder.part(model, { Name = "Body", Size = Vector3.new(6, 8, 4), CFrame = at(0, 4, 0), Color = C.Blue })
	Builder.part(model, { Name = "Screen", Size = Vector3.new(4.6, 3.4, 0.2), CFrame = at(0, 5.8, -2.05), Color = rgb(120, 255, 180), Material = Enum.Material.Neon })
	Builder.part(model, { Name = "Keys", Size = Vector3.new(5, 0.6, 2), CFrame = at(0, 3.2, -2.6) * CFrame.Angles(math.rad(-20), 0, 0), Color = C.Dark })
	Builder.sign(model, "CODES", at(0, 10.5, 0).Position, base.LookVector, Vector2.new(7, 2.5), C.Dark, rgb(120, 255, 180))
	local anchor = Builder.anchor(model, at(0, 3, -4).Position)
	Builder.prompt(anchor, "OpenPrompt", "Enter Code", "Code Terminal", 0, 12)
	CollectionService:AddTag(model, "CodeTerminal")
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
	spawn.Color = C.Yellow
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn:SetAttribute("ZoneId", "Hub")
	CollectionService:AddTag(spawn, "ZoneSpawn")

	Props.robotStatue(folder, facing(0, 18, SOUTH))
	Builder.sign(folder, "JUNKYARD SIMULATOR", Vector3.new(0, 43, 18), SOUTH, Vector2.new(34, 6), C.Orange, C.White)

	shopBuilding(folder, "UpgradeShop", "UpgradeShop", facing(-72, 20, EAST), C.Blue, "UPGRADES", "UPGRADES")
	local _, toolAt = shopBuilding(folder, "ToolShop", "ToolShop", facing(72, 20, WEST), C.Orange, "TOOL SHOP", "TOOLS")
	-- Display rack of every tool in the tool shop.
	local toolShop = folder:FindFirstChild("ToolShop") :: Model
	for i = 1, 8 do
		local color = Color3.fromHSV((i - 1) / 8, 0.7, 0.95)
		Builder.part(toolShop, {
			Name = "DisplayTool",
			Size = Vector3.new(0.7, 5, 0.7),
			CFrame = toolAt(-8 + (i - 1) * 2.3, 6.5, 8.6) * CFrame.Angles(0, 0, math.rad(12)),
			Color = color,
			Material = if i >= 5 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		})
	end

	for i, crate in Bots.Crates do
		crateStand(folder, crate, facing(-48 + (i - 1) * 32, -50, SOUTH))
	end
	Builder.sign(folder, "SCRAP BOT CRATES", Vector3.new(0, 20, -62), SOUTH, Vector2.new(30, 5), C.Purple, C.White)

	rebirthAltar(folder, facing(-72, -62, EAST))
	board(folder, "QuestBoard", "QuestBoard", facing(72, -62, WEST), "QUEST BOARD", rgb(150, 100, 60), "View Quests")
	board(folder, "Leaderboard", "Leaderboard", facing(-62, 72, Vector3.new(1, 0, -0.4).Unit), "TOP EARNERS", C.Dark, nil)
	codeTerminal(folder, facing(60, 74, Vector3.new(-1, 0, -0.4).Unit))

	-- Planters, lamps and benches around the plaza.
	for _, pos in { Vector3.new(-35, 0, 45), Vector3.new(35, 0, 45), Vector3.new(-35, 0, -20), Vector3.new(35, 0, -20) } do
		Builder.box(folder, "Planter", Vector3.new(10, 2, 10), pos + Vector3.new(0, 1, 0), C.PlazaTrim)
		Builder.tree(folder, pos + Vector3.new(0, 2, 0), 0.9, C.GrassDark, rng)
	end
	for _, pos in { Vector3.new(-14, 0, 90), Vector3.new(14, 0, 90), Vector3.new(-14, 0, -85), Vector3.new(14, 0, -85), Vector3.new(-50, 0, 0), Vector3.new(50, 0, 0) } do
		Props.lamp(folder, CFrame.new(pos))
	end
	for _, pos in { Vector3.new(-22, 0, 58), Vector3.new(22, 0, 58) } do
		Builder.box(folder, "BenchSeat", Vector3.new(8, 0.6, 2.5), pos + Vector3.new(0, 2, 0), C.Wood)
		Builder.box(folder, "BenchBack", Vector3.new(8, 2, 0.6), pos + Vector3.new(0, 3.2, 1.1), C.Wood)
		for _, x in { -3.2, 3.2 } do
			Builder.box(folder, "BenchLeg", Vector3.new(0.6, 2, 2), pos + Vector3.new(x, 1, 0), C.Dark)
		end
	end
	Builder.sign(folder, "Collect scrap  >  Sell it  >  Upgrade  >  Unlock new yards!", Vector3.new(0, 7, 92), Vector3.new(0, 0, -1), Vector2.new(26, 3.5), C.Dark, C.White)
	Builder.box(folder, "SignPost", Vector3.new(1, 5, 1), Vector3.new(-9, 2.5, 92.4), C.Dark)
	Builder.box(folder, "SignPost", Vector3.new(1, 5, 1), Vector3.new(9, 2.5, 92.4), C.Dark)
end

---------------------------------------------------------------- piles

local function scrapPile(parent: Instance, zone: Zones.Zone, position: Vector3)
	local model = Builder.model(parent, "ScrapPile")
	model:SetAttribute("ZoneId", zone.Id)

	local moundColor = zone.Theme.Ground:Lerp(Color3.new(0, 0, 0), 0.25)
	for _, wedge in Builder.pyramid(model, "Mound", position, 9, 3.2, moundColor, rng:NextNumber(0, 90)) do
		wedge:SetAttribute("Persistent", true)
	end

	local palette = zone.Theme.Pile
	for i = 1, 5 do
		local offset = Vector3.new(rng:NextNumber(-2.2, 2.2), 1.6 + rng:NextNumber(0, 1.6), rng:NextNumber(-2.2, 2.2))
		local rotation = CFrame.Angles(rng:NextNumber(-0.7, 0.7), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.7, 0.7))
		local color = palette[(i - 1) % #palette + 1]
		local kind = rng:NextInteger(1, 3)
		local cf = CFrame.new(position + offset) * rotation
		if kind == 1 then
			Builder.part(model, { Name = "Junk", Size = Vector3.new(rng:NextNumber(1.5, 3), 0.5, rng:NextNumber(1.5, 3)), CFrame = cf, Color = color, CanCollide = false })
		elseif kind == 2 then
			Builder.wedge(model, { Name = "Junk", Size = Vector3.new(rng:NextNumber(1, 2), rng:NextNumber(1, 2), rng:NextNumber(1.2, 2.4)), CFrame = cf, Color = color, CanCollide = false })
		else
			Builder.part(model, { Name = "Junk", Size = Vector3.new(rng:NextNumber(0.9, 1.6), rng:NextNumber(0.9, 1.6), rng:NextNumber(0.9, 1.6)), CFrame = cf, Color = color, CanCollide = false })
		end
	end

	local anchor = Builder.anchor(model, position + Vector3.new(0, 3, 0), 1)
	model.PrimaryPart = anchor
	Builder.prompt(anchor, "CollectPrompt", "Collect", zone.Name, 0.5, 10)

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "Glint"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 1.5
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Speed = NumberRange.new(0.5, 1)
	sparkle.Size = NumberSequence.new(0.7)
	sparkle.LightEmission = 1
	sparkle.Color = ColorSequence.new(rgb(255, 240, 170))
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = anchor

	CollectionService:AddTag(model, "ScrapPile")
end

---------------------------------------------------------------- zone gates

local function gate(parent: Instance, zone: Zones.Zone, z: number)
	local model = Builder.model(parent, "Gate_" .. zone.Id)
	model:SetAttribute("ZoneId", zone.Id)
	local accent = zone.Theme.Accent
	local opening = 15

	for _, side in { -1, 1 } do
		local inner = side * opening
		local outer = side * HALF_WIDTH
		Builder.box(model, "Wall", Vector3.new(math.abs(outer - inner), 14, 2), Vector3.new((inner + outer) / 2, 7, z), C.Fence)
		Builder.box(model, "WallTrim", Vector3.new(math.abs(outer - inner), 1.2, 2.4), Vector3.new((inner + outer) / 2, 14, z), accent)
		Builder.box(model, "Tower", Vector3.new(5, 22, 5), Vector3.new(side * (opening + 2.5), 11, z), accent)
		Builder.pyramid(model, "TowerCap", Vector3.new(side * (opening + 2.5), 22, z), 6, 4, C.Dark)
	end
	Builder.box(model, "Arch", Vector3.new(opening * 2 + 10, 3, 3), Vector3.new(0, 21, z), C.Dark)
	Builder.sign(model, string.upper(zone.Name), Vector3.new(0, 25.5, z + 0.5), SOUTH, Vector2.new(30, 5), accent, C.White)
	Builder.sign(model, string.upper(zone.Name), Vector3.new(0, 25.5, z - 0.5), -SOUTH, Vector2.new(30, 5), accent, C.White)

	if zone.Price > 0 then
		local barrier = Builder.part(model, {
			Name = "Barrier",
			Size = Vector3.new(opening * 2, 19, 1),
			CFrame = CFrame.new(0, 9.5, z),
			Color = accent,
			Material = Enum.Material.Neon,
			Transparency = 0.45,
		})
		barrier.CastShadow = false
		local requirement = Formulas.formatCash(zone.Price)
		if zone.RebirthsRequired > 0 then
			requirement ..= `  •  Rebirth {zone.RebirthsRequired}+`
		end
		Builder.sign(model, `LOCKED\n{requirement}`, Vector3.new(0, 9, z + 0.8), SOUTH, Vector2.new(18, 6), C.Dark, C.Yellow).Name = "PriceSign"
		local anchor = Builder.anchor(model, Vector3.new(0, 3, z + 6))
		Builder.prompt(anchor, "UnlockPrompt", `Unlock ({Formulas.formatCash(zone.Price)})`, zone.Name, 0.5, 14)
		CollectionService:AddTag(model, "ZoneGate")
	end
end

---------------------------------------------------------------- zone themes

type ThemeFn = (folder: Instance, zone: Zones.Zone, z0: number) -> ()

-- Positions measured from the zone's gate: (x, depth) -> world (x, z0 - depth).
local function at(z0: number, x: number, depth: number, dir: Vector3?): CFrame
	return facing(x, z0 - depth, dir or Vector3.new(0, 0, 1))
end

local function randomDir(): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

local BRIGHT = { rgb(230, 70, 60), rgb(60, 130, 230), rgb(250, 200, 50), rgb(80, 190, 90), rgb(240, 240, 240), rgb(255, 140, 200), rgb(150, 90, 230) }
local function bright(): Color3
	return BRIGHT[rng:NextInteger(1, #BRIGHT)]
end

local THEMES: { [string]: ThemeFn } = {}

THEMES.ScrapHeap = function(folder, _zone, z0)
	for _, side in { -1, 1 } do
		Builder.pyramid(folder, "ScrapMountain", Vector3.new(side * 84, 0, z0 - 110), 26, 16, rgb(190, 110, 60), rng:NextNumber(0, 90))
		Builder.pyramid(folder, "ScrapMountain", Vector3.new(side * 80, 0, z0 - 125), 16, 10, rgb(170, 170, 180), rng:NextNumber(0, 90))
		for _, depth in { 30, 75, 160 } do
			for i = 1, 3 do
				Props.barrel(folder, at(z0, side * 86 + rng:NextNumber(-3, 3), depth + i * 3.2, randomDir()), bright(), i == 3)
			end
		end
		for _, depth in { 70, 110, 150 } do
			Props.tires(folder, at(z0, side * 45, depth), rng:NextInteger(1, 4))
		end
	end
	Props.container(folder, at(z0, 86, 185), rgb(60, 130, 230))
	Props.crusher(folder, at(z0, -84, 185, EAST))
end

THEMES.CarGraveyard = function(folder, _zone, z0)
	for _, side in { -1, 1 } do
		for _, depth in { 25, 55, 85, 150, 180 } do
			Props.car(folder, at(z0, side * 87, depth, randomDir()), bright(), rng:NextNumber() < 0.5)
		end
		for _, depth in { 70, 110, 150 } do
			Props.cone(folder, at(z0, side * 14, depth))
		end
	end
	-- Car stacks and a crusher as landmarks.
	for level = 0, 2 do
		Props.car(folder, at(z0, -84, 118, Vector3.new(0.2 * level, 0, 1)) * CFrame.new(0, level * 3.2, 0), bright(), level == 0)
	end
	Props.crusher(folder, at(z0, 84, 118, WEST))
	Props.tires(folder, at(z0, 45, 70), 5)
	Props.tires(folder, at(z0, -45, 150), 4)
end

THEMES.ApplianceAlley = function(folder, _zone, z0)
	local pastel = { rgb(245, 245, 245), rgb(255, 180, 200), rgb(150, 225, 215), rgb(250, 225, 130), rgb(180, 200, 255) }
	for _, side in { -1, 1 } do
		for _, depth in { 25, 50, 150, 175 } do
			local kind = rng:NextInteger(1, 3)
			local cf = at(z0, side * 86, depth, -Vector3.new(side, 0, 0))
			local color = pastel[rng:NextInteger(1, #pastel)]
			if kind == 1 then
				Props.fridge(folder, cf, color)
			elseif kind == 2 then
				Props.washer(folder, cf, color)
			else
				Props.tv(folder, cf, color, 1)
			end
		end
		for _, depth in { 70, 150 } do
			Props.washer(folder, at(z0, side * 45, depth, randomDir()), pastel[rng:NextInteger(1, #pastel)])
		end
	end
	Props.toaster(folder, at(z0, 80, 110, WEST), 1.6)
	Props.tv(folder, at(z0, -80, 110, EAST), rgb(255, 140, 170), 2.6)
end

THEMES.ElectronicsDump = function(folder, _zone, z0)
	local glows = { rgb(70, 255, 150), rgb(70, 200, 255), rgb(255, 90, 200) }
	for _, side in { -1, 1 } do
		for _, depth in { 25, 45, 160, 180 } do
			Props.serverRack(folder, at(z0, side * 88, depth, -Vector3.new(side, 0, 0)), glows[rng:NextInteger(1, #glows)])
		end
		for _, depth in { 70, 150 } do
			Props.chip(folder, at(z0, side * 45, depth), 4)
		end
		-- Glowing circuit traces along the road.
		Builder.box(folder, "Trace", Vector3.new(0.6, 0.1, ZONE_LENGTH - 10), Vector3.new(side * 13, 0.12, z0 - ZONE_LENGTH / 2), rgb(70, 255, 150), nil, Enum.Material.Neon).CastShadow = false
	end
	Props.monitor(folder, at(z0, -82, 110, EAST), 1.1, rgb(70, 200, 255))
	Props.chip(folder, at(z0, 82, 110), 12)
	for i = 1, 4 do
		Builder.part(folder, {
			Name = "CableCoil",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 5, 5),
			CFrame = at(z0, 82 + rng:NextNumber(-6, 6), 135 + i * 5) * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = glows[(i - 1) % #glows + 1]:Lerp(Color3.new(0, 0, 0), 0.4),
		})
	end
end

THEMES.Shipyard = function(folder, _zone, z0)
	-- A strip of sea along the east fence with docks and wrecks.
	Builder.box(folder, "Water", Vector3.new(26, 0.4, ZONE_LENGTH - 4), Vector3.new(86, 0.1, z0 - ZONE_LENGTH / 2), rgb(70, 160, 230)).Transparency = 0.1
	for _, depth in { 40, 140 } do
		Props.dock(folder, at(z0, 78, depth, WEST) * CFrame.Angles(0, math.rad(90), 0), 22)
	end
	Props.boatHull(folder, at(z0, 88, 90, SOUTH), rgb(200, 70, 60))
	Props.boatHull(folder, at(z0, 88, 175, SOUTH) * CFrame.Angles(0, math.rad(10), 0), rgb(60, 110, 170))
	Props.lighthouse(folder, at(z0, -82, 110))
	for _, depth in { 30, 160 } do
		Props.anchor(folder, at(z0, -86, depth, EAST), 0.8)
		Props.container(folder, at(z0, -86, depth + 18), bright())
	end
	for _, depth in { 70, 150 } do
		Props.barrel(folder, at(z0, -45, depth, randomDir()), rgb(60, 110, 170), true)
		Props.barrel(folder, at(z0, 45, depth, randomDir()), rgb(200, 70, 60), false)
	end
end

THEMES.CrashSite = function(folder, _zone, z0)
	local glows = { rgb(190, 90, 255), rgb(60, 230, 210), rgb(255, 110, 200) }
	Props.ufo(folder, at(z0, 80, 110), 1)
	-- Crater ring around the UFO.
	for i = 0, 9 do
		local angle = i * math.pi / 5
		Builder.rock(folder, Vector3.new(80 + math.cos(angle) * 17, 0, z0 - 110 + math.sin(angle) * 17), rng:NextNumber(3, 5), rgb(110, 90, 140), rng)
	end
	Props.rocket(folder, at(z0, -82, 110, SOUTH))
	for _, side in { -1, 1 } do
		for _, depth in { 25, 55, 165, 185 } do
			Props.crystal(folder, at(z0, side * 88, depth), glows[rng:NextInteger(1, #glows)], rng:NextNumber(4, 8))
		end
		Props.satellite(folder, at(z0, side * 45, 70))
		Props.crystal(folder, at(z0, side * 45, 150), glows[rng:NextInteger(1, #glows)], 5)
	end
end

local function zoneLot(map: Instance, zone: Zones.Zone)
	local folder = Builder.folder(map, "Zone_" .. zone.Id)
	local z0 = gateZ(zone.Order)

	gate(folder, zone, z0)
	zoneSpawn(folder, zone.Id, Vector3.new(0, 0.5, z0 - 14))
	sellStation(folder, at(z0, -38, 28, EAST), zone.Theme.Accent)

	for _, depth in { 50, 90, 130, 170 } do
		for _, x in { -62, -28, 28, 62 } do
			local pos = Vector3.new(x + rng:NextNumber(-5, 5), 0, z0 - depth + rng:NextNumber(-5, 5))
			scrapPile(folder, zone, pos)
		end
	end

	local theme = THEMES[zone.Id]
	if theme then
		theme(folder, zone, z0)
	end
	for _, depth in { 60, 140 } do
		Props.lamp(folder, at(z0, -13, depth), zone.Theme.Accent)
		Props.lamp(folder, at(z0, 13, depth + 40), zone.Theme.Accent)
	end
end

---------------------------------------------------------------- outside

local function scenery(map: Instance)
	local folder = Builder.folder(map, "Scenery")
	for z = HUB_SOUTH + 40, END_Z - 40, -38 do
		for _, side in { -1, 1 } do
			local x = side * (HALF_WIDTH + rng:NextNumber(18, 60))
			Builder.tree(folder, Vector3.new(x, 0, z + rng:NextNumber(-10, 10)), rng:NextNumber(1, 1.6), if rng:NextNumber() < 0.5 then C.GrassDark else rgb(80, 160, 75), rng)
		end
	end
	for z = HUB_SOUTH + 60, END_Z - 60, -170 do
		for _, side in { -1, 1 } do
			local x = side * rng:NextNumber(230, 300)
			Builder.pyramid(folder, "Mountain", Vector3.new(x, 0, z), rng:NextNumber(90, 140), rng:NextNumber(60, 110), rgb(130, 140, 160), rng:NextNumber(0, 90))
		end
	end
end

---------------------------------------------------------------- lighting

function MapBuilder.setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 3
	Lighting.Ambient = rgb(110, 105, 120)
	Lighting.OutdoorAmbient = rgb(150, 150, 165)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.2
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
	sky.SunAngularSize = 16
	sky.MoonAngularSize = 9

	local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.1
	atmosphere.Color = rgb(210, 225, 245)
	atmosphere.Decay = rgb(140, 160, 200)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 0.6

	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.5
	bloom.Size = 20
	bloom.Threshold = 1.3

	local color = ensure("ColorCorrectionEffect", "ColorCorrection") :: ColorCorrectionEffect
	color.Saturation = 0.22
	color.Contrast = 0.06
	color.Brightness = 0.02
	color.TintColor = rgb(255, 252, 245)

	local rays = ensure("SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Intensity = 0.04
	rays.Spread = 0.5
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
