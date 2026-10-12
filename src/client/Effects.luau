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

local Formulas = require(ReplicatedStorage.Shared.Formulas)

local Effects = {}

local soundCache: { [string]: Sound } = {}

function Effects.playSound(id: string, pitch: number?)
	if id == "" then
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

local function burst(position: Vector3, color: Color3, amount: number)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = position
	part.Parent = effectsFolder()

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
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

-- A small chunk of scrap that hops from the pile into the player.
local function flyingChunk(from: Vector3, root: BasePart, color: Color3, delayTime: number)
	task.delay(delayTime, function()
		local chunk = Instance.new("Part")
		chunk.Anchored = true
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.Size = Vector3.new(0.8, 0.8, 0.8)
		chunk.Color = color
		chunk.Material = Enum.Material.Neon
		chunk.CFrame = CFrame.new(from)
		chunk.Parent = effectsFolder()

		local start = os.clock()
		local duration = 0.45
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local t = math.min((os.clock() - start) / duration, 1)
			local target = root.Position
			local arc = Vector3.new(0, math.sin(t * math.pi) * 4, 0)
			chunk.CFrame = CFrame.new(from:Lerp(target, t) + arc) * CFrame.Angles(t * 6, t * 4, 0)
			chunk.Size = Vector3.one * (0.8 * (1 - t * 0.6))
			if t >= 1 then
				connection:Disconnect()
				chunk:Destroy()
			end
		end)
	end)
end

local function floatingText(position: Vector3, text: string, color: Color3, big: boolean, delayTime: number)
	task.delay(delayTime, function()
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one
		anchor.Position = position
		anchor.Parent = effectsFolder()

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

		local info = TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(anchor, info, { Position = position + Vector3.new(0, 5, 0) }):Play()
		TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.8), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.8), { Transparency = 1 }):Play()
		Debris:AddItem(anchor, 1.4)
	end)
end

-- Called when the server confirms a collection.
function Effects.collected(itemIds: { string }, position: Vector3, collectSound: string)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	local bestTier = 0
	for i, id in itemIds do
		local scrap = Formulas.getScrapType(id)
		if scrap then
			local delayTime = (i - 1) * 0.12
			local isRare = scrap.Tier >= 3
			local text = if isRare then `RARE! +1 {scrap.Name}` else `+1 {scrap.Name}`
			floatingText(position + Vector3.new(0, 2 + (i - 1) * 1.5, 0), text, scrap.Color, scrap.Tier >= 2, delayTime)
			if root and root:IsA("BasePart") then
				flyingChunk(position, root, scrap.Color, delayTime)
			end
			burst(position, scrap.Color, 10 + scrap.Tier * 10)
			bestTier = math.max(bestTier, scrap.Tier)
		end
	end
	Effects.playSound(collectSound, 1 + bestTier * 0.15)
end

return Effects
