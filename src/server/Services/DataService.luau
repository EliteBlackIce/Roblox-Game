--!strict
-- Owns every player's authoritative data. Persists to a DataStore when available
-- and keeps working (without saving) in Studio sessions where API access is off.
--
-- Other services mutate a profile, then call DataService.changed(player); state
-- pushes to the client are coalesced to once per frame.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Bots = require(Shared.Bots)
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Rebirth = require(Shared.Rebirth)
local Remotes = require(Shared.Remotes)
local Tools = require(Shared.Tools)
local Upgrades = require(Shared.Upgrades)
local Zones = require(Shared.Zones)

export type OwnedBot = { Uid: string, Id: string, Golden: boolean }

export type Profile = {
	Cash: number,
	Gems: number,
	TotalEarned: number,
	Rebirths: number,
	Tokens: number,
	Levels: { [string]: number },
	ToolTier: number,
	Zones: { [string]: boolean },
	Inventory: { [string]: number },
	Discovered: { [string]: boolean },
	Bots: { OwnedBot },
	Equipped: { string },
	NextUid: number,
	Perks: { [string]: number },
	Boosts: { [string]: number },
	Stats: { [string]: number },
	Quest: { Index: number, Base: number },
	Daily: { Day: number, Ids: { string }, Base: { number }, Claimed: { boolean }, Bonus: boolean },
	Login: { LastDay: number, Streak: number },
	Codes: { [string]: boolean },
	Receipts: { string },
	Settings: { [string]: boolean },
}

local DataService = {}

local STORE_NAME = "JunkyardSimulator_v1"
local profiles: { [Player]: Profile } = {}
local canSave: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}
local store: DataStore? = nil

-- Filled by other services: gamepass ownership and the server-wide frenzy timer.
DataService.passes = {} :: { [Player]: { [string]: boolean } }
DataService.frenzyUntil = 0

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable, progress will not save:", result)
	end
end

DataService.SETTINGS = { "Sfx", "HideBots", "LowFx" }

local STATS = {
	"Collected",
	"SoldCash",
	"SellCount",
	"Upgrades",
	"Hatched",
	"RareFinds",
	"EpicFinds",
	"MythicFinds",
	"GoldenGrabs",
}

function DataService.newProfile(): Profile
	local levels = {}
	for _, upgrade in Upgrades do
		levels[upgrade.Id] = 0
	end
	local stats = {}
	for _, stat in STATS do
		stats[stat] = 0
	end
	return {
		Cash = Config.Gameplay.StartingCash,
		Gems = 0,
		TotalEarned = 0,
		Rebirths = 0,
		Tokens = 0,
		Levels = levels,
		ToolTier = 1,
		Zones = { [Zones.List[1].Id] = true },
		Inventory = {},
		Discovered = {},
		Bots = {},
		Equipped = {},
		NextUid = 1,
		Perks = {},
		Boosts = {},
		Stats = stats,
		Quest = { Index = 1, Base = 0 },
		Daily = { Day = 0, Ids = {}, Base = {}, Claimed = {}, Bonus = false },
		Login = { LastDay = 0, Streak = 0 },
		Codes = {},
		Receipts = {},
		Settings = { Sfx = true, HideBots = false, LowFx = false },
	}
end

local function int(value: any, min: number, max: number, fallback: number): number
	if type(value) ~= "number" or value ~= value then
		return fallback
	end
	return math.clamp(math.floor(value), min, max)
end

-- Copies only known keys with sane values, so a corrupted, outdated or
-- tampered save can never inject unexpected data. Also migrates v1 saves.
function DataService.sanitize(saved: any): Profile
	local profile = DataService.newProfile()
	if type(saved) ~= "table" then
		return profile
	end
	local BIG = 1e18

	profile.Cash = int(saved.Cash, 0, BIG, profile.Cash)
	profile.Gems = int(saved.Gems, 0, BIG, 0)
	profile.TotalEarned = int(saved.TotalEarned, 0, BIG, 0)
	profile.Rebirths = int(saved.Rebirths, 0, 10000, 0)
	profile.Tokens = int(saved.Tokens, 0, 1e6, 0)
	profile.ToolTier = int(saved.ToolTier, 1, #Tools, 1)
	profile.NextUid = int(saved.NextUid, 1, 1e9, 1)

	if type(saved.Levels) == "table" then
		-- v1 used "Capacity" and "BetterTools".
		if saved.Levels.Backpack == nil and saved.Levels.Capacity ~= nil then
			saved.Levels.Backpack = saved.Levels.Capacity
		end
		if saved.ToolTier == nil and type(saved.Levels.BetterTools) == "number" then
			profile.ToolTier = int(saved.Levels.BetterTools + 1, 1, #Tools, 1)
		end
		for _, upgrade in Upgrades do
			profile.Levels[upgrade.Id] = int(saved.Levels[upgrade.Id], 0, upgrade.MaxLevel, 0)
		end
	end

	if type(saved.Zones) == "table" then
		for _, zone in Zones.List do
			if saved.Zones[zone.Id] == true then
				profile.Zones[zone.Id] = true
			end
		end
	end

	if type(saved.Discovered) == "table" then
		for id in Zones.Items do
			if saved.Discovered[id] == true then
				profile.Discovered[id] = true
			end
		end
	end

	if type(saved.Inventory) == "table" then
		local capacity = Formulas.capacityFor(profile.Levels.Backpack, true)
		local used = 0
		for _, id in Zones.ItemOrder do
			local count = int(saved.Inventory[id], 0, capacity - used, 0)
			if count > 0 then
				profile.Inventory[id] = count
				used += count
			end
		end
	end

	if type(saved.Bots) == "table" then
		local seen = {}
		for _, owned in saved.Bots do
			if #profile.Bots >= Bots.MaxInventory then
				break
			end
			if type(owned) == "table" and type(owned.Uid) == "string" and not seen[owned.Uid] and Bots.ById[owned.Id] then
				seen[owned.Uid] = true
				table.insert(profile.Bots, { Uid = owned.Uid, Id = owned.Id, Golden = owned.Golden == true })
			end
		end
		if type(saved.Equipped) == "table" then
			local maxSlots = Bots.BaseSlots + 3 + 2
			for _, uid in saved.Equipped do
				if seen[uid] and #profile.Equipped < maxSlots and not table.find(profile.Equipped, uid) then
					table.insert(profile.Equipped, uid)
				end
			end
		end
	end

	if type(saved.Perks) == "table" then
		for _, perk in Rebirth.Perks do
			local lvl = int(saved.Perks[perk.Id], 0, #perk.Costs, 0)
			if lvl > 0 then
				profile.Perks[perk.Id] = lvl
			end
		end
	end

	if type(saved.Boosts) == "table" then
		for _, boost in Config.Boosts do
			local expires = saved.Boosts[boost.Id]
			if type(expires) == "number" and expires == expires then
				profile.Boosts[boost.Id] = math.floor(expires)
			end
		end
	end

	if type(saved.Stats) == "table" then
		for _, stat in STATS do
			profile.Stats[stat] = int(saved.Stats[stat], 0, BIG, 0)
		end
	end

	if type(saved.Quest) == "table" then
		profile.Quest.Index = int(saved.Quest.Index, 1, 1000, 1)
		profile.Quest.Base = int(saved.Quest.Base, 0, BIG, 0)
	end

	if type(saved.Daily) == "table" and type(saved.Daily.Ids) == "table" then
		local daily = profile.Daily
		daily.Day = int(saved.Daily.Day, 0, 1e7, 0)
		daily.Bonus = saved.Daily.Bonus == true
		for i, id in saved.Daily.Ids do
			if type(id) == "string" and i <= 5 then
				daily.Ids[i] = id
				daily.Base[i] = int(type(saved.Daily.Base) == "table" and saved.Daily.Base[i], 0, BIG, 0)
				daily.Claimed[i] = type(saved.Daily.Claimed) == "table" and saved.Daily.Claimed[i] == true
			end
		end
	end

	if type(saved.Login) == "table" then
		profile.Login.LastDay = int(saved.Login.LastDay, 0, 1e7, 0)
		profile.Login.Streak = int(saved.Login.Streak, 0, 1e6, 0)
	end

	if type(saved.Codes) == "table" then
		for code, used in saved.Codes do
			if type(code) == "string" and #code <= 30 and used == true then
				profile.Codes[code] = true
			end
		end
	end

	if type(saved.Receipts) == "table" then
		for _, receipt in saved.Receipts do
			if type(receipt) == "string" and #profile.Receipts < 50 then
				table.insert(profile.Receipts, receipt)
			end
		end
	end

	if type(saved.Settings) == "table" then
		for _, key in DataService.SETTINGS do
			if type(saved.Settings[key]) == "boolean" then
				profile.Settings[key] = saved.Settings[key]
			end
		end
	end

	return profile
end

local function retry<T>(attempts: number, fn: () -> T): (boolean, T | string)
	local ok, result
	for attempt = 1, attempts do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if attempt < attempts then
			task.wait(attempt)
		end
	end
	return false, result
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

function DataService.get(player: Player): Profile?
	return profiles[player]
end

function DataService.all(): { [Player]: Profile }
	return profiles
end

function DataService.context(player: Player): Formulas.Context
	return {
		Now = os.time(),
		Frenzy = os.time() < DataService.frenzyUntil,
		Passes = DataService.passes[player] or {},
	}
end

function DataService.getUsedSlots(profile: Profile): number
	local used = 0
	for _, count in profile.Inventory do
		used += count
	end
	return used
end

function DataService.addStat(profile: Profile, stat: string, amount: number)
	profile.Stats[stat] = (profile.Stats[stat] or 0) + amount
end

function DataService.addCash(profile: Profile, amount: number)
	profile.Cash += amount
	profile.TotalEarned += amount
end

-- Services add their own fields to the client snapshot through decorators.
local decorators: { (Player, Profile, { [string]: any }) -> () } = {}
function DataService.decorate(fn: (Player, Profile, { [string]: any }) -> ())
	table.insert(decorators, fn)
end

function DataService.buildState(player: Player): { [string]: any }?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local ctx = DataService.context(player)
	local upgrades = {}
	for _, upgrade in Upgrades do
		local lvl = profile.Levels[upgrade.Id]
		table.insert(upgrades, {
			Id = upgrade.Id,
			Level = lvl,
			Price = Formulas.upgradePrice(upgrade.Id, lvl),
		})
	end
	local state: { [string]: any } = {
		ServerTime = os.time(),
		Cash = profile.Cash,
		Gems = profile.Gems,
		Tokens = profile.Tokens,
		Rebirths = profile.Rebirths,
		TotalEarned = profile.TotalEarned,
		Inventory = table.clone(profile.Inventory),
		Used = DataService.getUsedSlots(profile),
		Capacity = Formulas.getCapacity(profile, ctx),
		Cooldown = Formulas.getCooldown(profile, ctx),
		Luck = Formulas.getLuck(profile, ctx),
		CashMultiplier = Formulas.getCashMultiplier(profile, ctx),
		ToolTier = profile.ToolTier,
		Levels = table.clone(profile.Levels),
		Upgrades = upgrades,
		Zones = table.clone(profile.Zones),
		Discovered = table.clone(profile.Discovered),
		Bots = table.clone(profile.Bots),
		Equipped = table.clone(profile.Equipped),
		BotSlots = Formulas.botSlots(profile, ctx),
		Perks = table.clone(profile.Perks),
		Boosts = table.clone(profile.Boosts),
		Frenzy = ctx.Frenzy,
		FrenzyUntil = DataService.frenzyUntil,
		Passes = table.clone(ctx.Passes),
		RebirthCost = Rebirth.cost(profile.Rebirths),
		Settings = table.clone(profile.Settings),
	}
	for _, decorate in decorators do
		decorate(player, profile, state)
	end
	return state
end

local function refreshLeaderstats(player: Player, profile: Profile)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local cash = leaderstats:FindFirstChild("Cash")
	if cash and cash:IsA("StringValue") then
		cash.Value = Formulas.formatCash(profile.Cash)
	end
	local rebirths = leaderstats:FindFirstChild("Rebirths")
	if rebirths and rebirths:IsA("IntValue") then
		rebirths.Value = profile.Rebirths
	end
end

local changedCallbacks: { (Player, Profile) -> () } = {}
function DataService.onChanged(fn: (Player, Profile) -> ())
	table.insert(changedCallbacks, fn)
end

-- Call after any mutation. Pushes are batched to one per frame per player.
function DataService.changed(player: Player)
	if not profiles[player] or dirty[player] then
		return
	end
	dirty[player] = true
	task.defer(function()
		dirty[player] = nil
		local profile = profiles[player]
		if not profile or player.Parent ~= Players then
			return
		end
		for _, fn in changedCallbacks do
			fn(player, profile)
		end
		refreshLeaderstats(player, profile)
		Remotes.event("StateChanged"):FireClient(player, DataService.buildState(player))
	end)
end

function DataService.notify(player: Player, message: string, kind: string?)
	Remotes.event("Notify"):FireClient(player, message, kind or "info")
end

local function save(player: Player)
	local profile = profiles[player]
	if not store or not profile or not canSave[player] then
		return
	end
	local ok, err = retry(3, function()
		(store :: DataStore):UpdateAsync(keyFor(player), function()
			return profile
		end)
		return true
	end)
	if not ok then
		warn(`[DataService] Failed to save {player.Name}:`, err)
	end
end
DataService.save = save

local loadedCallbacks: { (Player, Profile) -> () } = {}

function DataService.onLoaded(callback: (Player, Profile) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile)
	end
end

local removingCallbacks: { (Player, Profile) -> () } = {}
function DataService.onRemoving(callback: (Player, Profile) -> ())
	table.insert(removingCallbacks, callback)
end

local function onPlayerAdded(player: Player)
	local saved = nil
	local allowSave = store ~= nil
	if store then
		local ok, result = retry(3, function()
			return (store :: DataStore):GetAsync(keyFor(player))
		end)
		if ok then
			saved = result
		else
			-- Never overwrite a save we failed to read.
			allowSave = false
			warn(`[DataService] Failed to load {player.Name}, session will not save:`, result)
		end
	end
	if player.Parent ~= Players then
		return
	end

	local profile = DataService.sanitize(saved)
	profiles[player] = profile
	canSave[player] = allowSave
	DataService.passes[player] = DataService.passes[player] or {}

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats
	leaderstats.Parent = player
	refreshLeaderstats(player, profile)

	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile)
	end
	DataService.changed(player)
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			for _, callback in removingCallbacks do
				callback(player, profile)
			end
		end
		save(player)
		profiles[player] = nil
		canSave[player] = nil
		dirty[player] = nil
		DataService.passes[player] = nil
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Gameplay.AutosaveInterval)
			for player in profiles do
				task.spawn(save, player)
			end
		end
	end)

	Remotes.func("GetState").OnServerInvoke = function(player)
		return DataService.buildState(player)
	end
end

return DataService
