--!strict
-- Crate opening animation: the crate shakes, pops and reveals each bot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Bots = require(ReplicatedStorage.Shared.Bots)
local Config = require(ReplicatedStorage.Shared.Config)
local Effects = require(script.Parent.Parent.Effects)
local Notifications = require(script.Parent.Notifications)
local Theme = require(script.Parent.Theme)

local C = Theme.Colors

local Hatch = {}

local overlay: Frame
local crate: Frame
local cards: Frame
local busy = false

function Hatch.init(screen: ScreenGui)
	overlay = Theme.create("Frame", {
		Name = "HatchOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Visible = false,
		ZIndex = 30,
		Parent = screen,
	})
	crate = Theme.create("Frame", {
		Name = "Crate",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(150, 150),
		ZIndex = 31,
		Parent = overlay,
	}, { Theme.corner(18), Theme.stroke(5), Theme.create("UIScale", {}) })
	cards = Theme.create("Frame", {
		Name = "Cards",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(600, 220),
		BackgroundTransparency = 1,
		ZIndex = 31,
		Parent = overlay,
	}, { Theme.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 14) }) })
end

function Hatch.play(crateId: string, results: { { Uid: string, Id: string } })
	local crateDef = Bots.CrateById[crateId]
	if not crateDef or busy then
		return
	end
	busy = true
	Theme.clear(cards)
	overlay.Visible = true
	crate.Visible = true
	crate.BackgroundColor3 = crateDef.Color
	crate.Rotation = 0
	local scale = crate:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 1
	Effects.playSound(Config.Sounds.Hatch)

	-- Shake, then pop.
	for i = 1, 8 do
		crate.Rotation = if i % 2 == 0 then 10 else -10
		task.wait(0.07)
	end
	crate.Rotation = 0
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
	task.wait(0.2)
	crate.Visible = false

	local best = nil
	for i, result in results do
		local bot = Bots.ById[result.Id]
		local rarity = Config.RarityById[bot.Rarity]
		local card = Theme.create("Frame", { LayoutOrder = i, Size = UDim2.fromOffset(170, 210), BackgroundColor3 = C.Panel, ZIndex = 32, Parent = cards }, {
			Theme.corner(16),
			Theme.stroke(4, rarity.Color),
			Theme.create("UIScale", { Scale = 0 }),
		})
		Theme.create("Frame", { Size = UDim2.fromOffset(80, 80), Position = UDim2.new(0.5, -40, 0, 18), BackgroundColor3 = bot.Body, ZIndex = 33, Parent = card }, { Theme.corner(14), Theme.stroke(4, bot.Trim) })
		Theme.label({ Position = UDim2.fromOffset(6, 110), Size = UDim2.new(1, -12, 0, 30), Text = bot.Name, Font = Theme.TitleFont, ZIndex = 33, MaxTextSize = 22, Parent = card })
		Theme.label({ Position = UDim2.fromOffset(6, 142), Size = UDim2.new(1, -12, 0, 22), Text = rarity.Name, Font = Theme.TitleFont, TextColor3 = rarity.Color, ZIndex = 33, MaxTextSize = 20, Parent = card })
		local bonus = {}
		if bot.Cash > 0 then
			table.insert(bonus, `+{math.floor(bot.Cash * 100 + 0.5)}% cash`)
		end
		if bot.Luck > 0 then
			table.insert(bonus, `+{math.floor(bot.Luck * 100 + 0.5)}% luck`)
		end
		Theme.label({ Position = UDim2.fromOffset(6, 170), Size = UDim2.new(1, -12, 0, 30), Text = table.concat(bonus, "  "), TextColor3 = C.Cash, TextWrapped = true, ZIndex = 33, MaxTextSize = 15, Parent = card })
		TweenService:Create(card:FindFirstChildOfClass("UIScale") :: UIScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		if not best or rarity.Tier > Config.RarityById[best.Rarity].Tier then
			best = bot
		end
		task.wait(0.15)
	end
	if best and Config.RarityById[best.Rarity].Tier >= 3 then
		local rarity = Config.RarityById[best.Rarity]
		Notifications.bigFind(string.upper(rarity.Name) .. " BOT!", best.Name, rarity.Color)
		Effects.playSound(Config.Sounds.Rare, 1.2)
	end

	task.wait(2.2)
	overlay.Visible = false
	busy = false
end

return Hatch
