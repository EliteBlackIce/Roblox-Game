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

-- A small low-poly chunk that hops from the pile into the player.
local function flyingChunk(from: Vector3, root: BasePart, color: Color3, delayTime: number)
	task.delay(delayTime, function()
		local chunk = Instance.new("Part")
		chunk.Anchored = true
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.Size = Vector3.new(0.9, 0.9, 0.9)
		chunk.Color = color
		chunk.Material = Enum.Material.SmoothPlastic
		chunk.CFrame = CFrame.new(from)
		chunk.Parent = effectsFolder()

		local start = os.clock()
		local duration = 0.45
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local t = math.min((os.clock() - start) / duration, 1)
			local arc = Vector3.new(0, math.sin(t * math.pi) * 4, 0)
			chunk.CFrame = CFrame.new(from:Lerp(root.Position, t) + arc) * CFrame.Angles(t * 6, t * 4, 0)
			chunk.Size = Vector3.one * (0.9 * (1 - t * 0.6))
			if t >= 1 then
				connection:Disconnect()
				chunk:Destroy()
			end
		end)
		Debris:AddItem(chunk, 2)
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
				flyingChunk(position, root, item.Color, delayTime)
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
		Notifications.bigFind(string.upper(rarity.Name) .. "!", bestItem.Name, rarity.Color)
		Effects.playSound(Config.Sounds.Rare, 1.3)
	end
	Effects.playSound(Config.Sounds.Collect, 1 + bestTier * 0.12)
end

return Effects
