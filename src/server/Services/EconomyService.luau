--!strict
-- Selling, upgrades, tools, zone unlocks, teleports, boosts and settings.
-- The client only ever names *what* it wants; prices, balances, distances and
-- effects are all looked up and checked here.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)
local Tools = require(Shared.Tools)
local Zones = require(Shared.Zones)
local DataService = require(script.Parent.DataService)
local RequestRouter = require(script.Parent.RequestRouter)
local Stations = require(script.Parent.Stations)
local ToolService = require(script.Parent.ToolService)

local EconomyService = {}

---------------------------------------------------------------- selling

-- Sells the whole backpack. Returns the cash earned (0 if nothing sold).
function EconomyService.sellAll(player: Player): number
	local profile = DataService.get(player)
	if not profile then
		return 0
	end
	local raw = Formulas.inventoryValue(profile.Inventory)
	local count = DataService.getUsedSlots(profile)
	if count == 0 then
		DataService.notify(player, "Nothing to sell! Collect scrap from the piles first.", "error")
		return 0
	end

	local breakdown = {}
	for _, id in Zones.ItemOrder do
		local amount = profile.Inventory[id]
		if amount and amount > 0 then
			table.insert(breakdown, { Id = id, Count = amount })
		end
	end
	local multiplier = Formulas.getCashMultiplier(profile, DataService.context(player))
	local total = math.floor(raw * multiplier)

	table.clear(profile.Inventory)
	DataService.addCash(profile, total)
	DataService.addStat(profile, "SoldCash", total)
	DataService.addStat(profile, "SellCount", 1)
	Remotes.event("Sold"):FireClient(player, total, count, breakdown, multiplier)
	DataService.changed(player)
	return total
end

local function sellAtStation(player: Player)
	if Stations.near(player, "SellStation") then
		EconomyService.sellAll(player)
	end
end

local function remoteSell(player: Player): (boolean, string?)
	local profile = DataService.get(player) :: DataService.Profile
	if (profile.Perks.RemoteSell or 0) <= 0 then
		return false, "Unlock Remote Sell in the Rebirth shop first."
	end
	local earned = EconomyService.sellAll(player)
	return earned > 0, nil
end

---------------------------------------------------------------- upgrades & tools

local function buyUpgrade(player: Player, upgradeId: unknown): (boolean, string?)
	if type(upgradeId) ~= "string" then
		return false, "Invalid upgrade."
	end
	local upgrade = Formulas.getUpgrade(upgradeId)
	if not upgrade then
		return false, "Invalid upgrade."
	end
	if not Stations.near(player, "UpgradeShop") then
		return false, "Walk back to the Upgrade Shop to buy."
	end
	local profile = DataService.get(player) :: DataService.Profile
	local lvl = profile.Levels[upgrade.Id]
	local price = Formulas.upgradePrice(upgrade.Id, lvl)
	if not price then
		return false, `{upgrade.Name} is already maxed out!`
	end
	if profile.Cash < price then
		return false, `You need {Formulas.formatCash(price - profile.Cash)} more.`
	end
	profile.Cash -= price
	profile.Levels[upgrade.Id] = lvl + 1
	DataService.addStat(profile, "Upgrades", 1)
	DataService.changed(player)
	return true, `{upgrade.Name} upgraded to level {lvl + 1}!`
end

local function buyTool(player: Player): (boolean, string?)
	if not Stations.near(player, "ToolShop") then
		return false, "Walk back to the Tool Shop to buy."
	end
	local profile = DataService.get(player) :: DataService.Profile
	local nextTool = Tools[profile.ToolTier + 1]
	if not nextTool then
		return false, "You already own the best tool!"
	end
	if profile.Cash < nextTool.Price then
		return false, `You need {Formulas.formatCash(nextTool.Price - profile.Cash)} more.`
	end
	profile.Cash -= nextTool.Price
	profile.ToolTier += 1
	ToolService.refresh(player)
	DataService.changed(player)
	return true, `You got the {nextTool.Name}!`
end

---------------------------------------------------------------- zones

function EconomyService.unlockZone(player: Player, zoneId: unknown): (boolean, string?)
	if type(zoneId) ~= "string" then
		return false, "Invalid zone."
	end
	local zone = Zones.ById[zoneId]
	local profile = DataService.get(player)
	if not zone or not profile then
		return false, "Invalid zone."
	end
	if profile.Zones[zone.Id] then
		return false, `{zone.Name} is already unlocked.`
	end
	if not Stations.near(player, "ZoneGate", nil, "ZoneId", zone.Id) then
		return false, "Walk up to the gate to unlock it."
	end
	local previous = Zones.previous(zone.Id)
	if previous and not profile.Zones[previous.Id] then
		return false, `Unlock {previous.Name} first.`
	end
	if profile.Rebirths < zone.RebirthsRequired then
		return false, `{zone.Name} needs Rebirth {zone.RebirthsRequired}.`
	end
	if profile.Cash < zone.Price then
		return false, `You need {Formulas.formatCash(zone.Price - profile.Cash)} more.`
	end
	profile.Cash -= zone.Price
	profile.Zones[zone.Id] = true
	DataService.changed(player)
	return true, `{zone.Name} unlocked!`
end

local function onGatePrompt(player: Player, gate: Instance)
	local zoneId = gate:GetAttribute("ZoneId")
	local ok, message = EconomyService.unlockZone(player, zoneId)
	if message then
		DataService.notify(player, message, if ok then "success" else "error")
	end
end

function EconomyService.zonesUnlocked(profile: DataService.Profile): number
	local count = 0
	for _ in profile.Zones do
		count += 1
	end
	return count
end

local function teleport(player: Player, target: unknown): (boolean, string?)
	if type(target) ~= "string" then
		return false, "Invalid destination."
	end
	local profile = DataService.get(player) :: DataService.Profile
	if target ~= "Hub" and not profile.Zones[target] then
		return false, "You haven't unlocked that zone yet."
	end
	local character = player.Character
	if not character then
		return false, "Respawning..."
	end
	for _, spawnPart in CollectionService:GetTagged("ZoneSpawn") do
		if spawnPart:GetAttribute("ZoneId") == target and spawnPart:IsA("BasePart") then
			character:PivotTo(spawnPart.CFrame + Vector3.new(0, 4, 0))
			return true, nil
		end
	end
	return false, "That spot is missing."
end

---------------------------------------------------------------- boosts & settings

local function buyBoost(player: Player, boostId: unknown): (boolean, string?)
	local boost = nil
	for _, candidate in Config.Boosts do
		if candidate.Id == boostId then
			boost = candidate
		end
	end
	if not boost then
		return false, "Invalid boost."
	end
	local profile = DataService.get(player) :: DataService.Profile
	if profile.Gems < boost.Gems then
		return false, `You need {boost.Gems - profile.Gems} more gems.`
	end
	profile.Gems -= boost.Gems
	-- Buying again while active stacks the time.
	local now = os.time()
	profile.Boosts[boost.Id] = math.max(profile.Boosts[boost.Id] or 0, now) + boost.Duration
	DataService.changed(player)
	return true, `{boost.Name} active!`
end

local function setSetting(player: Player, key: unknown, value: unknown): (boolean, string?)
	if type(key) ~= "string" or type(value) ~= "boolean" or not table.find(DataService.SETTINGS, key) then
		return false, "Invalid setting."
	end
	local profile = DataService.get(player) :: DataService.Profile
	profile.Settings[key] = value
	DataService.changed(player)
	return true, nil
end

---------------------------------------------------------------- wiring

local function openPanel(panel: string)
	return function(player: Player)
		Remotes.event("OpenPanel"):FireClient(player, panel)
	end
end

function EconomyService.start()
	Stations.connectPrompt("SellStation", "SellPrompt", sellAtStation)
	Stations.connectPrompt("UpgradeShop", "ShopPrompt", openPanel("Upgrades"))
	Stations.connectPrompt("ToolShop", "ShopPrompt", openPanel("Tools"))
	Stations.connectPrompt("ZoneGate", "UnlockPrompt", onGatePrompt)
	Stations.connectPrompt("CodeTerminal", "OpenPrompt", openPanel("Codes"))

	RequestRouter.register("Sell", remoteSell)
	RequestRouter.register("BuyUpgrade", buyUpgrade)
	RequestRouter.register("BuyTool", buyTool)
	RequestRouter.register("UnlockZone", EconomyService.unlockZone)
	RequestRouter.register("Teleport", teleport)
	RequestRouter.register("BuyBoost", buyBoost)
	RequestRouter.register("SetSetting", setSetting)
end

return EconomyService
