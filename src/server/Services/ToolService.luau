--!strict
-- Builds each player's collection tool from their tool tier and keeps it in the
-- backpack across respawns and upgrades. Low-poly, solid-colour look.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Tools = require(ReplicatedStorage.Shared.Tools)
local DataService = require(script.Parent.DataService)

local ToolService = {}

local TOOL_TAG = "JunkyardTool"

local function buildTool(tool: Tools.Tool): Tool
	local instance = Instance.new("Tool")
	instance.Name = tool.Name
	instance.ToolTip = `Grabs x{tool.Yield} • Luck x{string.format("%.1f", tool.Luck)}`
	instance.CanBeDropped = false
	instance.RequiresHandle = true
	instance.Grip = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	instance:SetAttribute(TOOL_TAG, true)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 3.2)
	handle.Color = Color3.fromRGB(55, 55, 60)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = instance

	local material = if tool.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local function attach(name: string, size: Vector3, offset: CFrame, color: Color3, mat: Enum.Material)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = mat
		part.CanCollide = false
		part.Massless = true
		part.CFrame = handle.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
		part.Parent = instance
	end

	attach("Grip", Vector3.new(0.55, 0.55, 0.9), CFrame.new(0, 0, 1.1), Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic)
	attach("Body", Vector3.new(0.8, 0.8, 0.8), CFrame.new(0, 0, -1.4) * CFrame.Angles(0, 0, math.rad(45)), tool.Color, Enum.Material.SmoothPlastic)
	attach("ClawBase", Vector3.new(1.2, 0.35, 0.35), CFrame.new(0, 0, -1.9), tool.Color, Enum.Material.SmoothPlastic)
	attach("ClawLeft", Vector3.new(0.22, 0.3, 0.9), CFrame.new(-0.5, 0, -2.4) * CFrame.Angles(0, math.rad(14), 0), tool.Color, material)
	attach("ClawRight", Vector3.new(0.22, 0.3, 0.9), CFrame.new(0.5, 0, -2.4) * CFrame.Angles(0, math.rad(-14), 0), tool.Color, material)
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
	local tool = buildTool(Formulas.getTool(profile))
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
