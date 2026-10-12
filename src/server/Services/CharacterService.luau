--!strict
-- Applies profile stats to characters: walk speed and the overhead name tag.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local DataService = require(script.Parent.DataService)

local CharacterService = {}

local function applyWalkSpeed(player: Player, profile: DataService.Profile)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Formulas.getWalkSpeed(profile)
	end
end

local function updateTag(player: Player, profile: DataService.Profile)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local tag = head:FindFirstChild("OverheadTag")
	if not tag then
		local gui = Instance.new("BillboardGui")
		gui.Name = "OverheadTag"
		gui.Size = UDim2.fromOffset(200, 50)
		gui.StudsOffset = Vector3.new(0, 2.6, 0)
		gui.MaxDistance = 80
		gui.LightInfluence = 0

		local name = Instance.new("TextLabel")
		name.Name = "PlayerName"
		name.Size = UDim2.fromScale(1, 0.55)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.TextColor3 = Color3.new(1, 1, 1)
		name.Text = player.DisplayName
		name.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = name

		local rank = Instance.new("TextLabel")
		rank.Name = "Rank"
		rank.Position = UDim2.fromScale(0, 0.55)
		rank.Size = UDim2.fromScale(1, 0.45)
		rank.BackgroundTransparency = 1
		rank.Font = Enum.Font.FredokaOne
		rank.TextScaled = true
		rank.Parent = gui
		local stroke2 = Instance.new("UIStroke")
		stroke2.Thickness = 2
		stroke2.Parent = rank

		gui.Parent = head
		tag = gui
	end
	local name = tag:FindFirstChild("PlayerName") :: TextLabel
	local rank = tag:FindFirstChild("Rank") :: TextLabel
	if player:GetAttribute("VIP") then
		name.TextColor3 = Color3.fromRGB(255, 210, 60)
	end
	if profile.Rebirths > 0 then
		rank.Text = `Rebirth {profile.Rebirths}`
		rank.TextColor3 = Color3.fromRGB(255, 120, 200)
	else
		rank.Text = Formulas.getTool(profile).Name
		rank.TextColor3 = Color3.fromRGB(220, 220, 220)
	end
end

function CharacterService.start()
	DataService.onLoaded(function(player, profile)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			local current = DataService.get(player)
			if current then
				applyWalkSpeed(player, current)
				updateTag(player, current)
			end
		end)
		if player.Character then
			applyWalkSpeed(player, profile)
			updateTag(player, profile)
		end
	end)
	DataService.onChanged(function(player, profile)
		applyWalkSpeed(player, profile)
		updateTag(player, profile)
	end)
end

return CharacterService
