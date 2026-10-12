--!strict
-- Builds each player's collection tool from their tool tier and keeps it in the
-- backpack across respawns and upgrades. Low-poly, solid-colour look.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local ToolArt = require(ReplicatedStorage.Shared.Art.ToolArt)
local Tools = require(ReplicatedStorage.Shared.Tools)
local DataService = require(script.Parent.DataService)

local ToolService = {}

local TOOL_TAG = "JunkyardTool"

local function buildTool(tool: Tools.Tool, tier: number): Tool
	local instance = Instance.new("Tool")
	instance.Name = tool.Name
	instance.ToolTip = `Grabs x{tool.Yield} • Luck x{string.format("%.1f", tool.Luck)}`
	instance.CanBeDropped = false
	instance.RequiresHandle = true
	instance.Grip = CFrame.Angles(math.rad(-90), 0, 0)
	instance:SetAttribute(TOOL_TAG, true)
	instance:SetAttribute("Tier", tier)

	-- Invisible grip point at the model's origin; every visible part welds to it.
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 0.4)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	handle.Parent = instance

	local art = ToolArt.build(tier)
	for _, part in art:GetDescendants() do
		if part:IsA("BasePart") then
			if part.Name == "Handle" then
				part.Name = "Grip"
			end
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = part
			part.Parent = instance
		end
	end
	art:Destroy()
	return instance
end

local function removeTools(container: Instance?)
	if not container then
		return
	end
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute(TOOL_TAG) then
			child:Destroy()
		end
	end
end

-- Replaces whatever tool the player has with the one matching their tier.
function ToolService.refresh(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local character = player.Character
	local wasEquipped = ToolService.isHoldingTool(player)
	removeTools(player:FindFirstChildOfClass("Backpack"))
	removeTools(character)

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local tool = buildTool(Formulas.getTool(profile), profile.ToolTier)
	tool.Parent = backpack
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		-- Start equipped so new players can immediately use it.
		if humanoid and (wasEquipped or not character:GetAttribute("ToolGiven")) then
			humanoid:EquipTool(tool)
			character:SetAttribute("ToolGiven", true)
		end
	end
end

function ToolService.isHoldingTool(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute(TOOL_TAG) then
			return true
		end
	end
	return false
end

function ToolService.start()
	DataService.onLoaded(function(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			player:WaitForChild("Backpack")
			ToolService.refresh(player)
		end)
		if player.Character then
			ToolService.refresh(player)
		end
	end)
end

return ToolService
