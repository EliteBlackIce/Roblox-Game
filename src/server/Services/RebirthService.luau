--!strict
-- Rebirth (prestige) and the Rebirth Token perk shop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Rebirth = require(Shared.Rebirth)
local Remotes = require(Shared.Remotes)
local Upgrades = require(Shared.Upgrades)
local Zones = require(Shared.Zones)
local BotService = require(script.Parent.BotService)
local DataService = require(script.Parent.DataService)
local RequestRouter = require(script.Parent.RequestRouter)
local Stations = require(script.Parent.Stations)
local ToolService = require(script.Parent.ToolService)

local RebirthService = {}

local function rebirth(player: Player): (boolean, string?)
	local profile = DataService.get(player) :: DataService.Profile
	local cost = Rebirth.cost(profile.Rebirths)
	if profile.Cash < cost then
		return false, `You need {Formulas.formatCash(cost - profile.Cash)} more to rebirth.`
	end

	local tokens = Rebirth.tokensFor(profile.Rebirths)
	profile.Rebirths += 1
	profile.Tokens += tokens

	-- Reset the run. Bots, gems, index, perks, boosts and quests are kept.
	local headStart = profile.Perks.HeadStart or 0
	profile.Cash = if headStart > 0 then Rebirth.HeadStartCash[headStart] else 0
	for _, upgrade in Upgrades do
		profile.Levels[upgrade.Id] = 0
	end
	if (profile.Perks.KeepTools or 0) <= 0 then
		profile.ToolTier = 1
	end
	profile.Zones = { [Zones.List[1].Id] = true }
	table.clear(profile.Inventory)

	ToolService.refresh(player)
	BotService.tidyEquipped(player, profile)
	BotService.syncAttribute(player)
	Remotes.event("Announce"):FireAllClients(`{player.DisplayName} reached Rebirth {profile.Rebirths}!`, "Rebirth")
	DataService.changed(player)

	-- Back to the hub, since every zone past the first is locked again.
	local character = player.Character
	local spawnPart = workspace:FindFirstChild("SpawnLocation", true)
	if character and spawnPart and spawnPart:IsA("BasePart") then
		character:PivotTo(spawnPart.CFrame + Vector3.new(0, 4, 0))
	end
	return true, `Rebirth {profile.Rebirths}! +{tokens} Rebirth Token{if tokens == 1 then "" else "s"}`
end

local function buyPerk(player: Player, perkId: unknown): (boolean, string?)
	if type(perkId) ~= "string" then
		return false, "Invalid perk."
	end
	local perk = Rebirth.PerkById[perkId]
	if not perk then
		return false, "Invalid perk."
	end
	local profile = DataService.get(player) :: DataService.Profile
	local lvl = profile.Perks[perk.Id] or 0
	local cost = perk.Costs[lvl + 1]
	if not cost then
		return false, `{perk.Name} is maxed out!`
	end
	if profile.Tokens < cost then
		return false, `You need {cost - profile.Tokens} more Rebirth Token{if cost - profile.Tokens == 1 then "" else "s"}.`
	end
	profile.Tokens -= cost
	profile.Perks[perk.Id] = lvl + 1
	BotService.syncAttribute(player)
	DataService.changed(player)
	return true, `{perk.Name} upgraded!`
end

function RebirthService.start()
	RequestRouter.register("Rebirth", rebirth)
	RequestRouter.register("BuyPerk", buyPerk)
	Stations.connectPrompt("RebirthAltar", "OpenPrompt", function(player)
		Remotes.event("OpenPanel"):FireClient(player, "Rebirth")
	end)
end

return RebirthService
