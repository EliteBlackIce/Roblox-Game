--!strict
-- Distance checks against tagged world stations (sell pads, shops, crates, gates).
-- Every station model has a "PromptAnchor" part.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Stations = {}

function Stations.root(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function Stations.anchor(station: Instance): BasePart?
	local anchor = station:FindFirstChild("PromptAnchor")
	if anchor and anchor:IsA("BasePart") then
		return anchor
	end
	return nil
end

-- Returns the nearest station with `tag` within range (optionally matching an
-- attribute), or nil.
function Stations.near(player: Player, tag: string, range: number?, attribute: string?, value: any?): Instance?
	local root = Stations.root(player)
	if not root then
		return nil
	end
	local limit = range or Config.Gameplay.StationRange
	for _, station in CollectionService:GetTagged(tag) do
		if attribute == nil or station:GetAttribute(attribute) == value then
			local anchor = Stations.anchor(station)
			if anchor and (anchor.Position - root.Position).Magnitude <= limit then
				return station
			end
		end
	end
	return nil
end

-- Hooks a ProximityPrompt inside every station with `tag`, now and in future.
function Stations.connectPrompt(tag: string, promptName: string, handler: (Player, Instance) -> ())
	local function register(station: Instance)
		local anchor = Stations.anchor(station)
		local prompt = anchor and anchor:FindFirstChild(promptName)
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player)
				handler(player, station)
			end)
		else
			warn(`[Stations] {tag} missing PromptAnchor/{promptName}:`, station:GetFullName())
		end
	end
	for _, station in CollectionService:GetTagged(tag) do
		register(station)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(register)
end

return Stations
