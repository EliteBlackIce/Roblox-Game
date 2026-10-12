--!strict
-- Purely cosmetic, local-only feedback: sounds, particle bursts, flying scrap and
-- floating text. Nothing here affects game state.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Items = require(ReplicatedStorage.Shared.Art.Items)
local Kit = require(ReplicatedStorage.Shared.Art.Kit)
local Notifications = require(script.Parent.UI.Notifications)

local Effects = {}

-- Set from the player's settings.
Effects.muted = false
Effects.lowFx = false

local soundCache: { [string]: Sound } = {}

function Effects.playSound(id: string, pitch: number?)
	if id == "" or Effects.muted then
		return
	end
	local sound = soundCache[id]
	if not sound then
		sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = 0.6
		sound.Parent = SoundService
		soundCache[id] = sound
	end
	sound.PlaybackSpeed = pitch or 1
	SoundService:PlayLocalSound(sound)
end

local function effectsFolder(): Folder
	local folder = Workspace:FindFirstChild("LocalEffects")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "LocalEffects"
		folder.Parent = Workspace
	end
	return folder :: Folder
end

local function invisiblePart(position: Vector3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = position
	part.Parent = effectsFolder()
	return part
end

function Effects.burst(position: Vector3, color: Color3, amount: number)
	if Effects.lowFx then
		return
	end
	local part = invisiblePart(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = 0
	emitter.Parent = part
	emitter:Emit(amount)
	Debris:AddItem(part, 1.5)
end

-- A mini 3D copy of the item that hops from the pile into the player.
local function flyingItem(itemId: string, from: Vector3, root: BasePart, delayTime: number)
	task.delay(delayTime, function()
		local model = Items.build(itemId)
		Kit.scale(model, 0.45)
		local anchor = Instance.new("Part")
		anchor.Name = "Root"
		anchor.Size = Vector3.one * 0.2
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CFrame = CFrame.new()
		anchor.Parent = model
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part ~= anchor then
				part.Anchored = false
				part.CanCollide = false
				part.CanQuery = false
				part.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = anchor
				weld.Part1 = part
				weld.Parent = part
			elseif part:IsA("ParticleEmitter") then
				part.Enabled = false
			end
		end
		anchor.CFrame = CFrame.new(from)
		model.Parent = effectsFolder()

		local start = os.clock()
		local duration = 0.55
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local t = math.min((os.clock() - start) / duration, 1)
			local arc = Vector3.new(0, math.sin(t * math.pi) * 5, 0)
			anchor.CFrame = CFrame.new(from:Lerp(root.Position, t) + arc) * CFrame.Angles(t * 5, t * 8, 0)
			if t >= 1 then
				connection:Disconnect()
				model:Destroy()
			end
		end)
		Debris:AddItem(model, 2)
	end)
end

-- Quick downward swing of the equipped grabber (local only).
local swinging = false
function Effects.swingTool()
	local character = Players.LocalPlayer.Character
	if swinging or not character then
		return
	end
	local tool = nil
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("JunkyardTool") then
			tool = child
		end
	end
	if not tool then
		return
	end
	swinging = true
	local base = tool.Grip
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - start) / 0.3, 1)
		tool.Grip = base * CFrame.Angles(math.sin(t * math.pi) * math.rad(45), 0, 0)
		if t >= 1 then
			connection:Disconnect()
			tool.Grip = base
			swinging = false
		end
	end)
end

function Effects.floatingText(position: Vector3, text: string, color: Color3, big: boolean, delayTime: number)
	task.delay(delayTime, function()
		local anchor = invisiblePart(position)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(if big then 320 else 220, if big then 60 else 40)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.Parent = anchor

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = color
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2.5
		stroke.Parent = label

		local rise = TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local fade = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.8)
		TweenService:Create(anchor, rise, { Position = position + Vector3.new(0, 5, 0) }):Play()
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		Debris:AddItem(anchor, 1.4)
	end)
end

-- Called when the server confirms a collection.
function Effects.collected(itemIds: { string }, position: Vector3, info: any)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local isNew = {}
	for _, id in (info and info.New) or {} do
		isNew[id] = true
	end

	Effects.swingTool()
	local bestTier = 0
	local bestItem = nil
	for i, id in itemIds do
		local item = Zones.Items[id]
		if item then
			local rarity = Config.RarityById[item.Rarity]
			local delayTime = (i - 1) * 0.12
			local text = if isNew[id] then `NEW! +1 {item.Name}` else `+1 {item.Name}`
			Effects.floatingText(position + Vector3.new(0, 2 + (i - 1) * 1.5, 0), text, rarity.Color, rarity.Tier >= 2, delayTime)
			if root and root:IsA("BasePart") and not Effects.lowFx then
				flyingItem(id, position, root, delayTime)
			end
			Effects.burst(position, rarity.Color, 8 + rarity.Tier * 8)
			if rarity.Tier >= bestTier then
				bestTier = rarity.Tier
				bestItem = item
			end
		end
	end
	if info and info.Gems and info.Gems > 0 then
		Effects.floatingText(position + Vector3.new(0, 1, 0), `+{info.Gems} Gems`, Color3.fromRGB(90, 220, 255), false, 0.3)
	end
	if bestItem and bestTier >= 3 then
		local rarity = Config.RarityById[bestItem.Rarity]
		Notifications.bigFind(string.upper(rarity.Name) .. "!", bestItem.Name, rarity.Color, Items.build(bestItem.Id))
		Effects.playSound(Config.Sounds.Rare, 1.3)
	end
	Effects.playSound(Config.Sounds.Collect, 1 + bestTier * 0.12)
end

return Effects
