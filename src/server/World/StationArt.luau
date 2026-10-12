--!strict
-- Detailed, rounded models for every interactive station. Each builder keeps the
-- contract the services rely on: a tag, a "PromptAnchor" part with the named
-- ProximityPrompt, and any attributes (ZoneId, CrateId).
--
-- Models tagged "Hover" are animated on the client (spin and bob) using their
-- HoverSpin / HoverBob attributes.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Bots = require(Shared.Bots)
local Config = require(Shared.Config)
local CrateArt = require(Shared.Art.CrateArt)
local Formulas = require(Shared.Formulas)
local Items = require(Shared.Art.Items)
local Kit = require(Shared.Art.Kit)
local ToolArt = require(Shared.Art.ToolArt)
local Zones = require(Shared.Zones)
local Builder = require(script.Parent.Builder)

local StationArt = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local CN = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local SOLID = { Collide = true }
local DARK = rgb(60, 62, 75)
local WHITE = rgb(250, 250, 252)
local WOOD = rgb(175, 120, 75)
local STEEL = rgb(190, 196, 210)
local YELLOW = rgb(255, 205, 55)
local GREEN = rgb(80, 205, 110)

-- Interactive models stream in as a whole so prompts and parts arrive together.
local function atomic(model: Model)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
end

local function hover(target: Instance, spin: number, bob: number)
	target:SetAttribute("HoverSpin", spin)
	target:SetAttribute("HoverBob", bob)
	CollectionService:AddTag(target, "Hover")
end

-- Floating sign: a rounded board with big text, optionally bobbing.
local function floatingSign(parent: Instance, text: string, cf: CFrame, size: Vector2, color: Color3, textColor: Color3, bob: boolean?)
	local sign = Kit.model(parent, "FloatingSign")
	Kit.roundBox(sign, cf, Vector3.new(size.X + 0.8, size.Y + 0.8, 0.8), 0.4, Kit.shade(color, -0.35), nil, false)
	local board = Builder.sign(sign, text, (cf * CN(0, 0, -0.25)).Position, cf.LookVector, size, color, textColor)
	board.CanCollide = false
	if bob then
		hover(sign, 0, 0.6)
	end
	return sign
end

local function prompt(model: Instance, position: Vector3, name: string, action: string, object: string, hold: number, distance: number): BasePart
	local anchor = Builder.anchor(model, position)
	Builder.prompt(anchor, name, action, object, hold, distance)
	return anchor
end

---------------------------------------------------------------- sell machine

function StationArt.sellMachine(parent: Instance, base: CFrame, accent: Color3)
	local m = Kit.model(parent, "SellStation")
	local function at(x: number, y: number, z: number): CFrame
		return base * CN(x, y, z)
	end
	Kit.roundSlab(m, at(0, 0.3, -1), Vector3.new(20, 0.6, 16), 2.5, Kit.shade(GREEN, -0.25), SOLID)
	Kit.roundSlab(m, at(0, 0.65, -1), Vector3.new(18.5, 0.15, 14.5), 2.0, GREEN)
	-- Machine body with a dark mouth.
	Kit.roundBox(m, at(0, 5, 4), Vector3.new(12, 9, 7), 1.4, GREEN, SOLID)
	Kit.roundBox(m, at(0, 5.5, 4), Vector3.new(12.4, 1.2, 7.4), 0.5, accent, nil, false)
	Kit.roundBox(m, at(0, 3.0, 0.5), Vector3.new(5.5, 3.2, 1), 0.5, rgb(30, 32, 40), nil, false)
	for i = 0, 4 do
		Kit.box(m, at(-2.2 + i * 1.1, 4.3, 0.3), Vector3.new(0.5, 0.6, 0.2), YELLOW)
	end
	-- Hopper funnel on top.
	for i = 0, 3 do
		Kit.cylY(m, at(0, 10 + i * 0.9, 4), 0.9, 4.5 + i * 1.6, if i % 2 == 0 then YELLOW else Kit.shade(YELLOW, -0.15))
	end
	Kit.cylY(m, at(0, 13.65, 4), 0.1, 9.0, rgb(40, 40, 48))
	-- Conveyor belt feeding the mouth.
	Kit.roundBox(m, at(0, 1.6, -3.5), Vector3.new(4.8, 0.6, 7), 0.25, rgb(45, 45, 55), nil, false)
	for z = -6.5, -0.5, 1.5 do
		Kit.cyl(m, at(0, 1.25, z), 5.2, 0.7, STEEL)
	end
	for _, x in { -2.7, 2.7 } do
		Kit.roundBox(m, at(x, 0.9, -3.5), Vector3.new(0.5, 1.4, 7.2), 0.2, DARK, nil, false)
	end
	-- Scrap riding the belt.
	local onBelt = { "TinCan", "Hubcap", "CircuitBoard" }
	for i, id in onBelt do
		local item = Items.build(id)
		Kit.scale(item, 0.6)
		Kit.placeOnGround(item, at(-1 + (i - 1), 1.95, -5.5 + i * 1.5) * ANG(0, i, 0))
		item.Parent = m
	end
	-- Screen and coin chute on the side.
	Kit.roundBox(m, at(-4.3, 7.3, 0.45), Vector3.new(2.8, 2.2, 0.4), 0.3, DARK, nil, false)
	Kit.box(m, at(-4.3, 7.3, 0.2), Vector3.new(2.3, 1.7, 0.1), rgb(120, 255, 150), { Neon = true })
	Kit.cylZ(m, at(6.4, 3.5, 2.5) * ANG(0, rad(90), 0), 2.2, 1.6, accent)
	for i = 0, 5 do
		Kit.coin(m, at(7.2 + (i % 3) * 0.7, 0.75 + (i // 3) * 0.3, 0.2 + (i % 2) * 0.6) * ANG(0, 0, rad(90)), 1.2, YELLOW)
	end
	-- Giant spinning coin.
	local coin = Kit.model(m, "SpinningCoin")
	Kit.coin(coin, at(0, 19, 4) * ANG(0, rad(90), 0), 5.5, YELLOW, { Neon = false })
	hover(coin, 90, 0.8)

	floatingSign(m, "$ SELL $", at(0, 15.5, 0.2), Vector2.new(10, 3), GREEN, WHITE, false)
	local anchor = prompt(m, at(0, 3, -5).Position, "SellPrompt", "Sell Backpack", "Scrap Buyer", 0.25, 14)
	Builder.billboard(anchor, "SELL", GREEN, 22)
	atomic(m)
	CollectionService:AddTag(m, "SellStation")
	return m
end

---------------------------------------------------------------- shops

local function cottage(m: Model, base: CFrame, wall: Color3, roof: Color3)
	local function at(x: number, y: number, z: number): CFrame
		return base * CN(x, y, z)
	end
	Kit.roundSlab(m, at(0, 0.35, 2), Vector3.new(26, 0.7, 20), 2, rgb(225, 215, 195), SOLID)
	Kit.roundBox(m, at(0, 7, 10.5), Vector3.new(24, 13, 2), 0.8, wall, SOLID, false)
	for _, x in { -11.5, 11.5 } do
		Kit.roundBox(m, at(x, 7, 2.5), Vector3.new(2, 13, 18), 0.8, wall, SOLID, false)
		Kit.cylY(m, at(x, 7, -6.5), 13.4, 2.6, Kit.shade(wall, -0.2))
		Kit.ball(m, at(x, 13.9, -6.5), 2.6, Kit.shade(wall, -0.2))
		-- Round window.
		Kit.cyl(m, at(x - math.sign(x) * 0.1, 8, 3), 2.2, 3.4, WHITE)
		Kit.cyl(m, at(x - math.sign(x) * 0.15, 8, 3), 2.3, 2.6, rgb(150, 215, 245))
	end
	-- Gable roof.
	for _, side in { -1, 1 } do
		Kit.wedge(m, at(side * 6.75, 16.25, 2) * ANG(0, rad(-side * 90), 0), Vector3.new(21, 5.5, 13.5), roof, SOLID)
	end
	Kit.roundBox(m, at(0, 13.8, 2), Vector3.new(28, 0.8, 22), 0.4, Kit.shade(roof, -0.25), nil, false)
	Kit.cylY(m, at(0, 19.1, 2) * ANG(rad(90), 0, 0), 21.5, 1.2, Kit.shade(roof, 0.2))
	-- Chimney with a puff of smoke.
	Kit.roundBox(m, at(7, 19, 7), Vector3.new(2.4, 5, 2.4), 0.4, rgb(200, 95, 80), nil, false)
	Kit.ball(m, at(7.4, 22.6, 7), 2.2, rgb(235, 235, 240), { Transparency = 0.2 })
	Kit.ball(m, at(8.4, 24.2, 7.4), 1.6, rgb(235, 235, 240), { Transparency = 0.35 })
	-- Striped scalloped awning.
	for i = 0, 7 do
		local x = -10.5 + i * 3
		local color = if i % 2 == 0 then WHITE else rgb(255, 120, 120)
		Kit.wedge(m, at(x, 11.6, -8.8) * ANG(0, rad(180), 0), Vector3.new(3, 2.2, 3.6), color)
		Kit.ball(m, at(x, 10.4, -10.4), 1.6, color)
	end
	-- Counter.
	Kit.roundBox(m, at(0, 1.9, -4), Vector3.new(15, 3.2, 2.6), 0.5, WOOD, SOLID, false)
	Kit.roundBox(m, at(0, 3.6, -4), Vector3.new(15.6, 0.4, 3.0), 0.2, Kit.shade(WOOD, 0.15), nil, false)
end

function StationArt.upgradeShop(parent: Instance, base: CFrame)
	local m = Kit.model(parent, "UpgradeShop")
	local blue = rgb(80, 150, 240)
	cottage(m, base, blue, rgb(255, 205, 70))
	local function at(x: number, y: number, z: number): CFrame
		return base * CN(x, y, z)
	end
	-- Upgrade goodies on the counter: a backpack, a sneaker and a glove.
	Kit.roundBox(m, at(-4.5, 5.0, -4), Vector3.new(2.2, 2.6, 1.6), 0.6, rgb(230, 90, 70))
	Kit.roundBox(m, at(-4.5, 4.7, -4.85), Vector3.new(1.5, 1.2, 0.4), 0.3, Kit.shade(rgb(230, 90, 70), -0.2), nil, false)
	Kit.roundBox(m, at(0, 4.3, -4), Vector3.new(1.4, 0.9, 2.6), 0.4, rgb(90, 200, 255))
	Kit.roundBox(m, at(0, 3.95, -4), Vector3.new(1.5, 0.25, 2.8), 0.12, WHITE, nil, false)
	Kit.ball(m, at(4.5, 4.6, -4), 1.6, rgb(255, 210, 70))
	for i = 0, 3 do
		Kit.pill(m, at(3.9 + i * 0.4, 5.6, -4) * ANG(0, 0, rad(90)), 1.2, 0.4, rgb(255, 210, 70))
	end
	-- Up-arrow emblem over the door.
	local arrow = Kit.model(m, "Arrow")
	Kit.roundBox(arrow, at(0, 25.5, 2), Vector3.new(1.6, 3, 0.8), 0.4, rgb(120, 255, 140), { Neon = true }, false)
	Kit.wedge(arrow, at(-1.2, 27.8, 2) * ANG(0, rad(90), 0), Vector3.new(0.8, 1.6, 2.4), rgb(120, 255, 140), { Neon = true })
	Kit.wedge(arrow, at(1.2, 27.8, 2) * ANG(0, rad(-90), 0), Vector3.new(0.8, 1.6, 2.4), rgb(120, 255, 140), { Neon = true })
	hover(arrow, 60, 0.8)

	floatingSign(m, "UPGRADES", at(0, 15.6, -10.5), Vector2.new(13, 3), blue, YELLOW, false)
	local anchor = prompt(m, at(0, 3, -7.5).Position, "ShopPrompt", "Open", "Upgrades", 0, 13)
	Builder.billboard(anchor, "UPGRADES", YELLOW, 26)
	atomic(m)
	CollectionService:AddTag(m, "UpgradeShop")
	return m
end

function StationArt.toolShop(parent: Instance, base: CFrame)
	local m = Kit.model(parent, "ToolShop")
	local orange = rgb(255, 150, 60)
	cottage(m, base, orange, rgb(120, 80, 60))
	local function at(x: number, y: number, z: number): CFrame
		return base * CN(x, y, z)
	end
	-- Every tool hanging on the back wall.
	for tier = 1, 8 do
		local tool = ToolArt.build(tier)
		Kit.transform(tool, at(-9.5 + (tier - 1) * 2.7, 8, 9.2) * ANG(rad(-90), 0, 0) * ANG(0, 0, rad(90)))
		tool.Parent = m
		Kit.cylZ(m, at(-9.5 + (tier - 1) * 2.7, 11.6, 9.4), 0.6, 0.25, DARK)
	end
	-- Giant crossed wrench and hammer on the roof.
	local emblem = Kit.model(m, "Emblem")
	local wrench = at(0, 26, 2) * ANG(0, 0, rad(40))
	Kit.pill(emblem, wrench, 7, 1.0, STEEL)
	Kit.ring(emblem, wrench * CN(3.8, 0, 0) * ANG(rad(90), 0, 0), 1.1, 0.7, STEEL, 10)
	local hammer = at(0, 26, 2) * ANG(0, 0, rad(-40))
	Kit.pill(emblem, hammer, 6.5, 0.8, WOOD)
	Kit.roundBox(emblem, hammer * CN(3.4, 0, 0) * ANG(0, 0, rad(90)), Vector3.new(3.2, 1.6, 1.6), 0.4, DARK, nil, false)
	hover(emblem, 40, 0.6)
	-- Anvil beside the counter.
	Kit.roundBox(m, at(-9, 1.6, -6), Vector3.new(2, 2.4, 2), 0.3, DARK, SOLID, false)
	Kit.roundBox(m, at(-9, 3.2, -6), Vector3.new(4, 1, 2), 0.3, rgb(80, 82, 95), nil, false)

	floatingSign(m, "TOOL SHOP", at(0, 15.6, -10.5), Vector2.new(13, 3), orange, WHITE, false)
	local anchor = prompt(m, at(0, 3, -7.5).Position, "ShopPrompt", "Open", "Tool Shop", 0, 13)
	Builder.billboard(anchor, "TOOLS", YELLOW, 26)
	atomic(m)
	CollectionService:AddTag(m, "ToolShop")
	return m
end

---------------------------------------------------------------- crates

local function oddsBoard(anchor: BasePart, crate: Bots.Crate)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Odds"
	gui.Size = UDim2.fromOffset(200, 150)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 13, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.Parent = anchor

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.22)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = crate.Name
	title.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = title

	local total = 0
	for _, drop in crate.Drops do
		total += drop.Weight
	end
	for i, drop in crate.Drops do
		local bot = Bots.ById[drop.Bot]
		local line = Instance.new("TextLabel")
		line.Position = UDim2.fromScale(0, 0.22 + (i - 1) * 0.155)
		line.Size = UDim2.fromScale(1, 0.15)
		line.BackgroundTransparency = 1
		line.Font = Enum.Font.FredokaOne
		line.TextScaled = true
		line.TextColor3 = Config.RarityById[bot.Rarity].Color
		local pct = drop.Weight / total * 100
		line.Text = `{bot.Name}  {if pct < 1 then string.format("%.1f", pct) else tostring(math.floor(pct + 0.5))}%`
		line.Parent = gui
		local lineStroke = Instance.new("UIStroke")
		lineStroke.Thickness = 2
		lineStroke.Parent = line
	end
end

function StationArt.crateStand(parent: Instance, crate: Bots.Crate, base: CFrame)
	local m = Kit.model(parent, "Crate_" .. crate.Id)
	m:SetAttribute("CrateId", crate.Id)
	local function at(x: number, y: number, z: number): CFrame
		return base * CN(x, y, z)
	end
	Kit.cylY(m, at(0, 0.6, 0), 1.2, 15, DARK, SOLID)
	Kit.cylY(m, at(0, 1.5, 0), 0.6, 13, Kit.shade(crate.Color, -0.2), SOLID)
	Kit.ring(m, at(0, 1.85, 0), 6.2, 0.4, crate.Color, 16, { Neon = true }, false)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		Kit.cylY(m, at(math.cos(a) * 6.6, 2.2, math.sin(a) * 6.6), 1.4, 0.8, DARK)
		Kit.ball(m, at(math.cos(a) * 6.6, 3.1, math.sin(a) * 6.6), 0.9, crate.Color, { Neon = true })
	end
	local box = CrateArt.build(crate.Id)
	Kit.transform(box, at(0, 3.4, 0))
	box.Parent = m
	hover(box, 25, 0.7)

	local price = if crate.Currency == "Gems" then `{crate.Price} Gems` else Formulas.formatCash(crate.Price)
	local anchor = prompt(m, at(0, 4, -7.5).Position, "OpenPrompt", `Open ({price})`, crate.Name, 0.4, 12)
	oddsBoard(anchor, crate)
	atomic(m)
	CollectionService:AddTag(m, "CrateStand")
	return m
end

---------------------------------------------------------------- rebirth, quests, board, codes

function StationArt.rebirthAltar(parent: Instance, base: CFrame)
	local m = Kit.model(parent, "RebirthAltar")
	local function at(x: number, y: number, z: number): CFrame
		return base * CN(x, y, z)
	end
	local purple = rgb(150, 90, 230)
	local pink = rgb(255, 120, 210)
	Kit.cylY(m, at(0, 0.5, 0), 1, 22, Kit.shade(purple, -0.35), SOLID)
	Kit.cylY(m, at(0, 1.4, 0), 0.8, 17, Kit.shade(purple, -0.15), SOLID)
	Kit.cylY(m, at(0, 2.1, 0), 0.6, 12, purple, SOLID)
	Kit.ring(m, at(0, 2.45, 0), 5.6, 0.35, pink, 16, { Neon = true }, false)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + math.pi / 6
		local p = at(math.cos(a) * 9, 0, math.sin(a) * 9)
		Kit.cylY(m, p * CN(0, 4.5, 0), 7, 1.4, rgb(220, 200, 245), SOLID)
		Kit.cylY(m, p * CN(0, 8.2, 0), 0.6, 2.2, Kit.shade(purple, -0.2))
		Kit.ball(m, p * CN(0, 9.3, 0), 1.6, pink, { Neon = true })
	end
	local crystal = Kit.model(m, "Crystal")
	Kit.box(crystal, at(0, 9, 0) * ANG(0, rad(45), 0), Vector3.new(3.2, 7, 3.2), pink, { Neon = true })
	Kit.wedge(crystal, at(0, 13.6, 0.8) * ANG(0, 0, 0), Vector3.new(3.2, 2.2, 1.6), Kit.shade(pink, 0.2), { Neon = true })
	Kit.wedge(crystal, at(0, 13.6, -0.8) * ANG(0, rad(180), 0), Vector3.new(3.2, 2.2, 1.6), Kit.shade(pink, 0.2), { Neon = true })
	Kit.box(crystal, at(2.3, 7.5, 0) * ANG(0, 0, rad(-25)), Vector3.new(1.4, 3.5, 1.4), Kit.shade(pink, -0.1), { Neon = true })
	Kit.box(crystal, at(-2.3, 7.8, 0.4) * ANG(0, 0, rad(25)), Vector3.new(1.2, 3, 1.2), Kit.shade(pink, -0.1), { Neon = true })
	Kit.ring(crystal, at(0, 9, 0) * ANG(rad(20), 0, 0), 4.2, 0.3, WHITE, 16, { Neon = true }, false)
	hover(crystal, 30, 1.0)
	Kit.sparkle(Kit.ball(m, at(0, 9, 0), 0.5, pink, { Neon = true }), pink, 6)

	floatingSign(m, "REBIRTH", at(0, 19, 3), Vector2.new(11, 3), purple, WHITE, true)
	local anchor = prompt(m, at(0, 4, -8).Position, "OpenPrompt", "Rebirth", "Rebirth Altar", 0, 14)
	Builder.billboard(anchor, "REBIRTH", pink, 24)
	atomic(m)
	CollectionService:AddTag(m, "RebirthAltar")
	return m
end

local function framedBoard(m: Model, base: CFrame, color: Color3, title: string, listText: string): BasePart
	local function at(x: number, y: number, z: number): CFrame
		return base * CN(x, y, z)
	end
	for _, x in { -9.5, 9.5 } do
		Kit.cylY(m, at(x, 8, 0.6), 16, 1.4, DARK, SOLID)
		Kit.ball(m, at(x, 16.3, 0.6), 1.8, YELLOW)
	end
	Kit.roundBox(m, at(0, 10, 0.3), Vector3.new(19.5, 14, 1.2), 0.5, Kit.shade(color, -0.3), SOLID, false)
	local panel = Kit.box(m, at(0, 10, -0.2), Vector3.new(18, 12.5, 0.4), color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = panel
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.fromScale(1, 0.18)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = YELLOW
	titleLabel.Text = title
	titleLabel.Parent = gui
	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromScale(0.05, 0.2)
	list.Size = UDim2.fromScale(0.9, 0.76)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.FredokaOne
	list.TextScaled = true
	list.TextColor3 = WHITE
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = listText
	list.Parent = gui
	return panel
end

function StationArt.questBoard(parent: Instance, base: CFrame)
	local m = Kit.model(parent, "QuestBoard")
	local function at(x: number, y: number, z: number): CFrame
		return base * CN(x, y, z)
	end
	framedBoard(m, base, rgb(150, 105, 65), "QUEST BOARD", "Daily quests, the quest chain\nand login rewards!")
	-- Pinned paper notes and a little roof.
	for i, note in { { -6, 4.5, 8 }, { 6.5, 5.2, -6 }, { -6.8, 13.5, -10 }, { 6.8, 13.2, 12 } } do
		Kit.box(m, at(note[1], note[2], -0.45) * ANG(0, 0, rad(note[3])), Vector3.new(3, 3.6, 0.1), rgb(255, 250, 225))
		Kit.ball(m, at(note[1], note[2] + 1.5, -0.55), 0.5, if i % 2 == 0 then rgb(230, 70, 70) else rgb(70, 140, 230))
	end
	-- Little ridge roof over the board.
	Kit.wedge(m, at(0, 18.3, -0.75), Vector3.new(21, 2.2, 2.2), rgb(200, 90, 70))
	Kit.wedge(m, at(0, 18.3, 1.35) * ANG(0, math.pi, 0), Vector3.new(21, 2.2, 2.2), rgb(200, 90, 70))
	local anchor = prompt(m, at(0, 3, -4).Position, "OpenPrompt", "View Quests", "Quest Board", 0, 13)
	Builder.billboard(anchor, "QUESTS", YELLOW, 22)
	atomic(m)
	CollectionService:AddTag(m, "QuestBoard")
	return m
end

function StationArt.leaderboard(parent: Instance, base: CFrame)
	local m = Kit.model(parent, "Leaderboard")
	local function at(x: number, y: number, z: number): CFrame
		return base * CN(x, y, z)
	end
	framedBoard(m, base, rgb(45, 48, 65), "TOP EARNERS", "Loading...")
	-- Trophy on top.
	local trophy = Kit.model(m, "Trophy")
	Kit.cylY(trophy, at(0, 17.6, 0.3), 0.8, 3.2, DARK)
	Kit.cylY(trophy, at(0, 18.8, 0.3), 1.6, 0.8, YELLOW)
	for i = 0, 3 do
		Kit.cylY(trophy, at(0, 20 + i * 0.6, 0.3), 0.6, 2.2 + i * 0.5, YELLOW)
	end
	for _, side in { -1, 1 } do
		Kit.ring(trophy, at(side * 1.9, 21, 0.3) * ANG(rad(90), 0, 0), 0.7, 0.3, YELLOW, 8, nil, false)
	end
	Kit.sparkle(Kit.ball(trophy, at(0, 21.5, 0.3), 0.4, YELLOW, { Neon = true }), YELLOW, 3)
	hover(trophy, 45, 0.3)
	atomic(m)
	CollectionService:AddTag(m, "Leaderboard")
	return m
end

function StationArt.codeTerminal(parent: Instance, base: CFrame)
	local m = Kit.model(parent, "CodeTerminal")
	local function at(x: number, y: number, z: number): CFrame
		return base * CN(x, y, z)
	end
	local blue = rgb(80, 140, 240)
	Kit.roundBox(m, at(0, 4.5, 0), Vector3.new(6, 9, 4.5), 0.8, blue, SOLID)
	Kit.roundBox(m, at(0, 6.5, -2.2), Vector3.new(4.6, 3.6, 0.4), 0.4, DARK, nil, false)
	Kit.box(m, at(0, 6.5, -2.42), Vector3.new(3.9, 2.9, 0.1), rgb(120, 255, 180), { Neon = true })
	Kit.wedge(m, at(0, 3.6, -2.9) * ANG(0, rad(180), 0), Vector3.new(5.6, 1.2, 1.6), Kit.shade(blue, -0.2))
	for i, color in { rgb(255, 90, 90), rgb(255, 220, 80), rgb(90, 230, 120) } do
		Kit.ball(m, at(-0.6 + (i - 1) * 0.9, 4.35, -3.2), 0.6, color)
	end
	Kit.cylY(m, at(-1.8, 4.6, -3.1), 0.9, 0.25, DARK)
	Kit.ball(m, at(-1.8, 5.1, -3.1), 0.6, rgb(255, 80, 80))
	floatingSign(m, "CODES", at(0, 11.5, 0), Vector2.new(6, 2), DARK, rgb(120, 255, 180), true)
	local anchor = prompt(m, at(0, 3, -4.5).Position, "OpenPrompt", "Enter Code", "Code Terminal", 0, 12)
	Builder.billboard(anchor, "CODES", rgb(120, 255, 180), 16)
	atomic(m)
	CollectionService:AddTag(m, "CodeTerminal")
	return m
end

---------------------------------------------------------------- zone gates

function StationArt.gate(parent: Instance, zone: Zones.Zone, z: number, halfWidth: number)
	local m = Kit.model(parent, "Gate_" .. zone.Id)
	m:SetAttribute("ZoneId", zone.Id)
	local accent = zone.Theme.Accent
	local stone = rgb(200, 195, 210)
	local opening = 15

	for _, side in { -1, 1 } do
		local inner, outer = side * (opening + 4), side * halfWidth
		Kit.roundBox(m, CN((inner + outer) / 2, 6, z), Vector3.new(math.abs(outer - inner), 12, 3), 0.8, stone, SOLID, false)
		Kit.roundBox(m, CN((inner + outer) / 2, 12.3, z), Vector3.new(math.abs(outer - inner) + 0.4, 1, 3.6), 0.4, accent, nil, false)
		-- Crenellations along the wall.
		for x = math.min(inner, outer) + 3, math.max(inner, outer) - 3, 6 do
			Kit.roundSlab(m, CN(x, 13.6, z), Vector3.new(2.6, 1.8, 2.6), 0.5, stone)
		end
		-- Round tower with a cone roof and flag.
		local tower = CN(side * (opening + 2.5), 0, z)
		Kit.cylY(m, tower * CN(0, 11, 0), 22, 7, stone, SOLID)
		for _, y in { 4, 12, 20 } do
			Kit.cylY(m, tower * CN(0, y, 0), 0.8, 7.4, accent)
		end
		Kit.cone(m, tower * CN(0, 22, 0), 7, 8.5, accent, 5)
		Kit.cylY(m, tower * CN(0, 31, 0), 4, 0.3, DARK)
		Kit.wedge(m, tower * CN(side * 1.3, 32.2, 0) * ANG(0, rad(side * -90), 0), Vector3.new(0.15, 1.6, 2.4), accent)
		Kit.cylZ(m, tower * CN(0, 15, -3.55), 0.3, 2.2, rgb(40, 40, 50))
	end
	-- Arch of rounded blocks over the road.
	for i = 0, 8 do
		local a = math.pi * i / 8
		Kit.roundSlab(m, CN(math.cos(a) * (opening + 1), 16 + math.sin(a) * 6, z) * ANG(0, 0, a - math.pi / 2), Vector3.new(4.2, 3, 3.2), 0.6, if i % 2 == 0 then stone else Kit.shade(stone, -0.12))
	end
	floatingSign(m, string.upper(zone.Name), CN(0, 26, z) * ANG(0, math.pi, 0), Vector2.new(22, 4), accent, WHITE, false)
	Builder.sign(m, string.upper(zone.Name), Vector3.new(0, 26, z - 0.5), -Vector3.new(0, 0, 1), Vector2.new(22, 4), accent, WHITE)

	-- The zone's Legendary item floats above the arch as its emblem.
	local legendary = nil
	for _, item in zone.Items do
		if item.Rarity == "Legendary" then
			legendary = item
		end
	end
	if legendary then
		local emblem = Items.build(legendary.Id)
		Kit.scale(emblem, 2.6)
		Kit.transform(emblem, CN(0, 33.5, z))
		emblem.Name = "Emblem"
		emblem.Parent = m
		hover(emblem, 35, 0.8)
	end

	if zone.Price > 0 then
		local barrier = Builder.part(m, {
			Name = "Barrier",
			Size = Vector3.new(opening * 2 + 2, 19, 1),
			CFrame = CN(0, 9.5, z),
			Color = accent,
			Material = Enum.Material.Neon,
			Transparency = 0.45,
		})
		barrier.CastShadow = false
		local requirement = Formulas.formatCash(zone.Price)
		if zone.RebirthsRequired > 0 then
			requirement ..= `  •  Rebirth {zone.RebirthsRequired}+`
		end
		Builder.sign(m, `LOCKED\n{requirement}`, Vector3.new(0, 9, z + 0.8), Vector3.new(0, 0, 1), Vector2.new(18, 6), DARK, YELLOW).Name = "PriceSign"
		prompt(m, Vector3.new(0, 3, z + 6), "UnlockPrompt", `Unlock ({Formulas.formatCash(zone.Price)})`, zone.Name, 0.5, 14)
		CollectionService:AddTag(m, "ZoneGate")
	end
	atomic(m)
	return m
end

---------------------------------------------------------------- scrap piles

-- Lightweight items (by part count) that dress a zone's piles; computed once.
local pileItemCache: { [string]: { string } } = {}
function StationArt.pileItems(zone: Zones.Zone): { string }
	local cached = pileItemCache[zone.Id]
	if cached then
		return cached
	end
	local picks = {}
	for _, item in zone.Items do
		if Config.RarityById[item.Rarity].Tier <= 2 then
			local model = Items.build(item.Id)
			local parts = 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					parts += 1
				end
			end
			model:Destroy()
			if parts <= 32 then
				table.insert(picks, item.Id)
			end
		end
	end
	if #picks == 0 then
		picks = { zone.Items[1].Id }
	end
	pileItemCache[zone.Id] = picks
	return picks
end

-- A mound of dirt topped with two of the zone's (common) items and some loose
-- junk. Mound parts are "Persistent"; everything else hides when depleted.
function StationArt.scrapPile(parent: Instance, zone: Zones.Zone, position: Vector3, rng: Random)
	local m = Kit.model(parent, "ScrapPile")
	m:SetAttribute("ZoneId", zone.Id)
	local dirt = zone.Theme.Ground:Lerp(Color3.new(0, 0, 0), 0.22)
	local mound = {
		Kit.cylY(m, CN(position + Vector3.new(0, 0.25, 0)), 0.5, 9.5, Kit.shade(dirt, -0.12), SOLID),
		Kit.cylY(m, CN(position + Vector3.new(0, 0.7, 0)), 0.6, 7.5, Kit.shade(dirt, -0.04), SOLID),
		Kit.cylY(m, CN(position + Vector3.new(0, 1.2, 0)), 0.5, 5, dirt, SOLID),
		Kit.ball(m, CN(position + Vector3.new(0, -2.6, 0)), 7, dirt, SOLID),
		Kit.ball(m, CN(position + Vector3.new(1.8, -1.8, 0.8)), 4.2, Kit.shade(dirt, 0.08)),
		Kit.ball(m, CN(position + Vector3.new(-1.6, -1.7, -1.0)), 4, Kit.shade(dirt, -0.06)),
	}
	for _, part in mound do
		part.Name = "Mound"
		part:SetAttribute("Persistent", true)
	end

	local commons = StationArt.pileItems(zone)
	for i = 1, 2 do
		local id = commons[rng:NextInteger(1, #commons)]
		local item = Items.build(id)
		Kit.scale(item, 1.25)
		local offset = if i == 1 then Vector3.new(-1.2, 2.3, 0.3) else Vector3.new(1.4, 2.0, -0.6)
		Kit.transform(item, CN(position + offset) * ANG(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.4, 0.4)))
		item.Name = "Junk"
		item.Parent = m
	end
	local palette = zone.Theme.Pile
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2 + rng:NextNumber(0, 1)
		Kit.box(
			m,
			CN(position + Vector3.new(math.cos(a) * 2.6, 0.8, math.sin(a) * 2.6)) * ANG(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6), rng:NextNumber(-0.5, 0.5)),
			Vector3.new(rng:NextNumber(1, 1.8), rng:NextNumber(0.6, 1.1), rng:NextNumber(1, 1.8)),
			palette[(i - 1) % #palette + 1]
		)
	end

	local anchor = Builder.anchor(m, position + Vector3.new(0, 3, 0), 1)
	m.PrimaryPart = anchor
	Builder.prompt(anchor, "CollectPrompt", "Collect", zone.Name, 0.5, 10)
	Kit.sparkle(anchor, rgb(255, 240, 170), 1.5)
	atomic(m)
	CollectionService:AddTag(m, "ScrapPile")
	return m
end

return StationArt
