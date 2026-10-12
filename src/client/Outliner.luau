--!strict
-- Cel-shading ink lines: puts a black outline Highlight on the models nearest
-- to the player (your pets and tool first, then anything tagged "Outline").
-- Roblox renders at most ~31 Highlights at once, so we keep a budget and
-- re-pick the closest targets a few times per second.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Outliner = {}

local BUDGET = 28
local RANGE = 120
local INK = Color3.fromRGB(30, 24, 44)

local pool: { Highlight } = {}

local function highlight(index: number): Highlight
	local h = pool[index]
	if not h then
		h = Instance.new("Highlight")
		h.Name = "Ink"
		h.FillTransparency = 1
		h.OutlineTransparency = 0
		h.OutlineColor = INK
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Enabled = false
		h.Parent = Workspace
		pool[index] = h
	end
	return h
end

local function center(model: Instance): Vector3?
	if model:IsA("Model") then
		local primary = model.PrimaryPart
		if primary then
			return primary.Position
		end
		local part = model:FindFirstChildWhichIsA("BasePart", true)
		return part and part.Position
	elseif model:IsA("BasePart") then
		return model.Position
	end
	return nil
end

-- Returns the instances that should be outlined this tick, closest first.
function Outliner.pick(focus: Vector3): { Instance }
	local picks: { Instance } = {}
	local player = Players.LocalPlayer
	local character = player and player.Character
	-- Always: your equipped tool and your own pets.
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then
				table.insert(picks, child)
			end
		end
	end
	local followers = Workspace:FindFirstChild("BotFollowers")
	local candidates: { { Instance: Instance, Distance: number } } = {}
	if followers then
		for _, bot in followers:GetChildren() do
			local p = center(bot)
			if p then
				table.insert(candidates, { Instance = bot, Distance = (p - focus).Magnitude * 0.5 })
			end
		end
	end
	for _, model in CollectionService:GetTagged("Outline") do
		local p = center(model)
		if p then
			local distance = (p - focus).Magnitude
			if distance < RANGE then
				table.insert(candidates, { Instance = model, Distance = distance })
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.Distance < b.Distance
	end)
	for _, c in candidates do
		if #picks >= BUDGET then
			break
		end
		table.insert(picks, c.Instance)
	end
	return picks
end

function Outliner.apply(picks: { Instance })
	for i = 1, BUDGET do
		local h = highlight(i)
		local target = picks[i]
		if target then
			h.Adornee = target
			h.Enabled = true
		else
			h.Adornee = nil
			h.Enabled = false
		end
	end
end

function Outliner.init(getFocus: () -> Vector3?)
	task.spawn(function()
		while true do
			local focus = getFocus()
			if focus then
				Outliner.apply(Outliner.pick(focus))
			end
			task.wait(0.3)
		end
	end)
end

return Outliner
