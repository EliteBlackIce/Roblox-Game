--!strict
-- 3D crate opening, Pet Simulator style: the crate wobbles harder and harder,
-- the lid blasts off with a flash, then the bot(s) pop out spinning in front of
-- rarity-coloured light rays.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Art = ReplicatedStorage.Shared.Art
local BotArt = require(Art.BotArt)
local Bots = require(ReplicatedStorage.Shared.Bots)
local Config = require(ReplicatedStorage.Shared.Config)
local CrateArt = require(Art.CrateArt)
local Effects = require(script.Parent.Parent.Effects)
local Notifications = require(script.Parent.Notifications)
local Theme = require(script.Parent.Theme)
local Viewport = require(script.Parent.Viewport)

local Hatch = {}

local overlay: Frame
local stage: Frame
local flash: Frame
local busy = false

type Pose = { Parts: { BasePart }, Base: { CFrame } }

local function capture(root: Instance): Pose
	local parts, base = {}, {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(base, d.CFrame)
		end
	end
	return { Parts = parts, Base = base }
end

local function apply(pose: Pose, cf: CFrame)
	for i, part in pose.Parts do
		part.CFrame = cf * pose.Base[i]
	end
end

-- Spinning light rays behind a reveal.
local function rays(parent: Instance, color: Color3): Frame
	local holder = Theme.create("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.6, 1.6),
		BackgroundTransparency = 1,
		ZIndex = 31,
		Parent = parent,
	})
	for i = 0, 7 do
		Theme.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.09, 0, 1, 0),
			Rotation = i * 22.5,
			BackgroundColor3 = color,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			ZIndex = 31,
			Parent = holder,
		}, {
			Theme.create("UIGradient", {
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
				Rotation = 90,
			}),
		})
	end
	return holder
end

function Hatch.init(screen: ScreenGui)
	overlay = Theme.create("Frame", {
		Name = "HatchOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Visible = false,
		ZIndex = 30,
		Parent = screen,
	})
	stage = Theme.create("Frame", {
		Name = "Stage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromScale(0.8, 0.62),
		BackgroundTransparency = 1,
		ZIndex = 31,
		Parent = overlay,
	})
	flash = Theme.create("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = overlay,
	})
end

-- Runs `fn(t)` every frame for `duration` seconds (t from 0 to 1).
local function animate(duration: number, fn: (number) -> ())
	local start = os.clock()
	local done = false
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - start) / duration, 1)
		fn(t)
		if t >= 1 then
			connection:Disconnect()
			done = true
		end
	end)
	while not done do
		task.wait()
	end
end

local function revealCard(parent: Instance, result: { Uid: string, Id: string }, order: number, count: number): (Frame, Pose, ViewportFrame)
	local bot = Bots.ById[result.Id]
	local rarity = Config.RarityById[bot.Rarity]
	local width = 1 / count
	local card = Theme.create("Frame", {
		Name = "Reveal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(width * (order - 0.5), 0.5),
		Size = UDim2.fromScale(width * 0.95, 1),
		BackgroundTransparency = 1,
		ZIndex = 31,
		Parent = parent,
	}, { Theme.create("UIScale", { Scale = 0 }) })
	rays(card, rarity.Color)
	local model = BotArt.build(bot.Id)
	local view = Viewport.new(card, model, { Size = UDim2.fromScale(1, 0.78), ZIndex = 32 }, { Yaw = 0, Pitch = 8, Zoom = 1.15 })
	local label = Theme.label({
		Position = UDim2.fromScale(0, 0.78),
		Size = UDim2.fromScale(1, 0.12),
		Text = bot.Name,
		Font = Theme.TitleFont,
		ZIndex = 33,
		MaxTextSize = 34,
		Parent = card,
	})
	Theme.textStroke(3).Parent = label
	local rarityLabel = Theme.label({
		Position = UDim2.fromScale(0, 0.9),
		Size = UDim2.fromScale(1, 0.1),
		Text = rarity.Name,
		Font = Theme.TitleFont,
		TextColor3 = rarity.Color,
		ZIndex = 33,
		MaxTextSize = 28,
		Parent = card,
	})
	Theme.textStroke(3).Parent = rarityLabel
	return card, capture(model), view
end

function Hatch.play(crateId: string, results: { { Uid: string, Id: string } })
	if busy or not Bots.CrateById[crateId] then
		return
	end
	busy = true
	Theme.clear(stage)
	overlay.Visible = true
	overlay.BackgroundTransparency = 0.4

	-- 1. The crate wobbles harder and harder.
	local crateModel = CrateArt.build(crateId)
	local crateView = Viewport.new(stage, crateModel, { ZIndex = 32 }, { Yaw = 20, Pitch = 18, Zoom = 1.1 })
	local body = capture(crateModel)
	local lidModel = crateModel:FindFirstChild("Lid")
	local lid = if lidModel then capture(lidModel) else { Parts = {}, Base = {} }
	local pivot = CFrame.new(0, 3, 0)
	Effects.playSound(Config.Sounds.Hatch)
	animate(1.4, function(t)
		local shake = math.sin(t * 40) * math.rad(4 + t * 14)
		local squash = 1 + math.sin(t * 20) * 0.04 * t
		apply(body, pivot * CFrame.Angles(0, 0, shake) * CFrame.new(0, (squash - 1) * 3, 0) * pivot:Inverse())
	end)

	-- 2. Lid blasts off with a flash.
	flash.BackgroundTransparency = 0.1
	TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	Effects.playSound(Config.Sounds.Rare, 1.4)
	animate(0.35, function(t)
		apply(lid, CFrame.new(t * 3, t * 9, -t * 2) * CFrame.Angles(t * 2, t * 3, 0))
		for _, part in lid.Parts do
			part.Transparency = t
		end
	end)
	crateView:Destroy()

	-- 3. Bots pop out spinning.
	local best = nil
	local poses = {}
	for i, result in results do
		local card, pose = revealCard(stage, result, i, #results)
		local scale = card:FindFirstChildOfClass("UIScale") :: UIScale
		TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		table.insert(poses, { Pose = pose, Rays = card:FindFirstChild("Rays") :: Frame })
		local bot = Bots.ById[result.Id]
		if not best or Config.RarityById[bot.Rarity].Tier > Config.RarityById[best.Rarity].Tier then
			best = bot
		end
		task.wait(0.12)
	end
	if best and Config.RarityById[best.Rarity].Tier >= 3 then
		local rarity = Config.RarityById[best.Rarity]
		Notifications.bigFind(string.upper(rarity.Name) .. " BOT!", best.Name, rarity.Color)
		Effects.playSound(Config.Sounds.Rare, 1.2)
	end
	animate(2.4, function(t)
		for _, entry in poses do
			apply(entry.Pose, CFrame.Angles(0, t * math.pi * 2, 0) * CFrame.new(0, math.sin(t * math.pi * 3) * 0.2, 0))
			entry.Rays.Rotation = t * 90
		end
	end)

	TweenService:Create(overlay, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
	task.wait(0.25)
	overlay.Visible = false
	Theme.clear(stage)
	busy = false
end

return Hatch
