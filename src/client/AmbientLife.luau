--!strict
-- Purely local ambience that makes the world feel alive: puffy clouds drifting
-- overhead, butterflies fluttering around the player, and glowing motes in the
-- air. Turns itself down with the "Low Effects" setting.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Kit = require(game:GetService("ReplicatedStorage").Shared.Art.Kit)

local AmbientLife = {}

local CLOUDS = 16
local BUTTERFLIES = 12
local MAP_X = 420
local MAP_Z = { 260, -1560 }

local folder: Folder
local enabled = true

type Cloud = { Parts: { BasePart }, Offsets: { CFrame }, Position: Vector3, Speed: number }
type Butterfly = { Body: BasePart, Left: BasePart, Right: BasePart, Phase: number, Radius: number, Height: number, Speed: number }

local clouds: { Cloud } = {}
local butterflies: { Butterfly } = {}
local motes: BasePart

local function localPart(shape: Enum.PartType, size: Vector3, color: Color3, transparency: number?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Parent = folder
	return p
end

local function makeCloud(rng: Random): Cloud
	local parts, offsets = {}, {}
	local puffs = rng:NextInteger(4, 7)
	for i = 1, puffs do
		local size = rng:NextNumber(14, 26) * (if i == 1 then 1.3 else 1)
		local offset = CFrame.new(rng:NextNumber(-22, 22), rng:NextNumber(-3, 6), rng:NextNumber(-10, 10))
		local puff = localPart(Enum.PartType.Ball, Vector3.one * size, Color3.fromRGB(255, 255, 255), 0.05)
		table.insert(parts, puff)
		table.insert(offsets, offset)
	end
	return {
		Parts = parts,
		Offsets = offsets,
		Position = Vector3.new(rng:NextNumber(-MAP_X, MAP_X), rng:NextNumber(115, 165), rng:NextNumber(MAP_Z[2], MAP_Z[1])),
		Speed = rng:NextNumber(2, 5),
	}
end

local WING_COLORS = {
	Color3.fromRGB(255, 150, 200),
	Color3.fromRGB(140, 200, 255),
	Color3.fromRGB(255, 220, 100),
	Color3.fromRGB(190, 150, 255),
	Color3.fromRGB(140, 235, 170),
}

local function makeButterfly(rng: Random, i: number): Butterfly
	local color = WING_COLORS[(i - 1) % #WING_COLORS + 1]
	return {
		Body = localPart(Enum.PartType.Ball, Vector3.new(0.3, 0.3, 0.3), Color3.fromRGB(60, 50, 70)),
		Left = localPart(Enum.PartType.Cylinder, Vector3.new(0.06, 0.9, 0.9), color),
		Right = localPart(Enum.PartType.Cylinder, Vector3.new(0.06, 0.9, 0.9), color),
		Phase = rng:NextNumber(0, math.pi * 2),
		Radius = rng:NextNumber(8, 26),
		Height = rng:NextNumber(2, 7),
		Speed = rng:NextNumber(0.25, 0.6),
	}
end

-- One frame of ambience. `focus` is the player's position.
function AmbientLife.step(t: number, dt: number, focus: Vector3?)
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	for _, cloud in clouds do
		local x = cloud.Position.X + cloud.Speed * dt
		if x > MAP_X then
			x = -MAP_X
		end
		cloud.Position = Vector3.new(x, cloud.Position.Y, cloud.Position.Z)
		local base = CFrame.new(cloud.Position)
		for i, puff in cloud.Parts do
			table.insert(parts, puff)
			table.insert(cframes, base * cloud.Offsets[i])
		end
	end
	if focus then
		for _, b in butterflies do
			local a = t * b.Speed + b.Phase
			-- A lazy figure-eight around the player.
			local pos = focus + Vector3.new(math.sin(a) * b.Radius, b.Height + math.sin(a * 3.1) * 1.2, math.sin(a * 2) * b.Radius * 0.5)
			local heading = Vector3.new(math.cos(a), 0, math.cos(a * 2)).Unit
			local body = CFrame.lookAt(pos, pos + heading)
			local flap = math.sin(t * 22 + b.Phase) * math.rad(55)
			table.insert(parts, b.Body)
			table.insert(cframes, body)
			table.insert(parts, b.Left)
			table.insert(cframes, body * CFrame.Angles(0, 0, flap) * CFrame.new(-0.45, 0, 0) * CFrame.Angles(0, 0, math.rad(90)))
			table.insert(parts, b.Right)
			table.insert(cframes, body * CFrame.Angles(0, 0, -flap) * CFrame.new(0.45, 0, 0) * CFrame.Angles(0, 0, math.rad(90)))
		end
		motes.CFrame = CFrame.new(focus + Vector3.new(0, 6, 0))
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function AmbientLife.setEnabled(on: boolean)
	if on == enabled then
		return
	end
	enabled = on
	folder.Parent = if on then Workspace else nil
end

function AmbientLife.init(getFocus: () -> Vector3?)
	folder = Instance.new("Folder")
	folder.Name = "AmbientLife"
	folder.Parent = Workspace
	local rng = Random.new(77)
	for _ = 1, CLOUDS do
		table.insert(clouds, makeCloud(rng))
	end
	for i = 1, BUTTERFLIES do
		table.insert(butterflies, makeButterfly(rng, i))
	end
	motes = localPart(Enum.PartType.Block, Vector3.new(90, 14, 90), Color3.new(1, 1, 1), 1)
	Kit.sparkle(motes, Color3.fromRGB(255, 245, 200), 6)
	local emitter = motes:FindFirstChildOfClass("ParticleEmitter")
	if emitter then
		emitter.Lifetime = NumberRange.new(4, 7)
		emitter.Speed = NumberRange.new(0.2, 0.6)
	end

	local start = os.clock()
	local last = start
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if enabled then
			AmbientLife.step(now - start, now - last, getFocus())
		end
		last = now
	end)
end

function AmbientLife.count(): number
	return #clouds + #butterflies
end

return AmbientLife
