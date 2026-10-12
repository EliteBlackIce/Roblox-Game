--!strict
-- Builds each player's collection tool from their BetterTools level and keeps it
-- equipped-ready across respawns and upgrades.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local DataService = require(script.Parent.DataService)

local ToolService = {}

local TOOL_TAG = "JunkyardTool"

local function buildTool(tool: Config.ToolDef): Tool
	local instance = Instance.new("Tool")
	instance.Name = tool.Name
	instance.ToolTip = `Yield x{tool.Yield} • Luck {string.format("%.1f", tool.Luck)}`
	instance.CanBeDropped = false
	instance.RequiresHandle = true
	instance.Grip = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	instance:SetAttribute(TOOL_TAG, true)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 0.35, 3.2)
	handle.Color = Color3.fromRGB(60, 60, 64)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = instance

	local function attach(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = material
		part.CanCollide = false
		part.Massless = true
		part.CFrame = handle.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
		part.Parent = instance
	end

	-- Grip wrap and a two-pronged claw at the far end, colored by tier.
	attach("Grip", Vector3.new(0.5, 0.5, 0.9), CFrame.new(0, 0, 1.1), Color3.fromRGB(30, 30, 30), Enum.Material.Fabric)
	attach("ClawBase", Vector3.new(1, 0.4, 0.4), CFrame.new(0, 0, -1.7), tool.Color, tool.Material)
	attach("ClawLeft", Vector3.new(0.2, 0.3, 0.8), CFrame.new(-0.45, 0, -2.2) * CFrame.Angles(0, math.rad(12), 0), tool.Color, tool.Material)
	attach("ClawRight", Vector3.new(0.2, 0.3, 0.8), CFrame.new(0.45, 0, -2.2) * CFrame.Angles(0, math.rad(-12), 0), tool.Color, tool.Material)

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

-- Replaces whatever tool the player has with the one matching their level.
function ToolService.refresh(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local character = player.Character
	local wasEquipped = false
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute(TOOL_TAG) then
				wasEquipped = true
			end
		end
	end
	removeTools(player:FindFirstChildOfClass("Backpack"))
	removeTools(character)

	local def = Formulas.getTool(profile.Levels)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		local tool = buildTool(def)
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
