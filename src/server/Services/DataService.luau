--!strict
-- Owns every player's authoritative data: cash, upgrade levels and carried scrap.
-- Persists to a DataStore when available, and keeps working (without saving) in
-- Studio sessions where API access is turned off.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type Profile = {
	Cash: number,
	TotalEarned: number,
	Levels: { [string]: number },
	Inventory: { [string]: number },
}

local DataService = {}

local STORE_NAME = "JunkyardSimulator_v1"
local profiles: { [Player]: Profile } = {}
local loaded: { [Player]: boolean } = {}
local store: DataStore? = nil

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

local function newProfile(): Profile
	local levels = {}
	for _, upgrade in Config.Upgrades do
		levels[upgrade.Id] = 0
	end
	local inventory = {}
	for _, scrap in Config.ScrapTypes do
		inventory[scrap.Id] = 0
	end
	return {
		Cash = Config.Gameplay.StartingCash,
		TotalEarned = 0,
		Levels = levels,
		Inventory = inventory,
	}
end

-- Copies only known keys with sane numeric values, so a corrupted or outdated
-- save can never inject unexpected fields.
local function sanitize(saved: any): Profile
	local profile = newProfile()
	if type(saved) ~= "table" then
		return profile
	end
	local function int(value: any, min: number, max: number, fallback: number): number
		if type(value) ~= "number" or value ~= value then
			return fallback
		end
		return math.clamp(math.floor(value), min, max)
	end
	profile.Cash = int(saved.Cash, 0, 1e15, profile.Cash)
	profile.TotalEarned = int(saved.TotalEarned, 0, 1e15, 0)
	if type(saved.Levels) == "table" then
		for _, upgrade in Config.Upgrades do
			profile.Levels[upgrade.Id] = int(saved.Levels[upgrade.Id], 0, upgrade.MaxLevel, 0)
		end
	end
	if type(saved.Inventory) == "table" then
		local capacity = Formulas.getCapacity(profile.Levels)
		local used = 0
		for _, scrap in Config.ScrapTypes do
			local count = int(saved.Inventory[scrap.Id], 0, capacity - used, 0)
			profile.Inventory[scrap.Id] = count
			used += count
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
		task.wait(attempt)
	end
	return false, result
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

function DataService.get(player: Player): Profile?
	return profiles[player]
end

function DataService.getUsedSlots(profile: Profile): number
	local used = 0
	for _, count in profile.Inventory do
		used += count
	end
	return used
end

-- Snapshot the client renders. Built entirely from server data.
function DataService.buildState(player: Player)
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local tool = Formulas.getTool(profile.Levels)
	local upgrades = {}
	for _, upgrade in Config.Upgrades do
		local level = profile.Levels[upgrade.Id]
		table.insert(upgrades, {
			Id = upgrade.Id,
			Name = upgrade.Name,
			Description = upgrade.Description,
			Level = level,
			MaxLevel = upgrade.MaxLevel,
			Price = Formulas.getUpgradePrice(upgrade.Id, level),
			Effect = Formulas.describeEffect(upgrade.Id, level),
			NextEffect = if level < upgrade.MaxLevel then Formulas.describeEffect(upgrade.Id, level + 1) else nil,
		})
	end
	return {
		Cash = profile.Cash,
		Inventory = table.clone(profile.Inventory),
		Used = DataService.getUsedSlots(profile),
		Capacity = Formulas.getCapacity(profile.Levels),
		Cooldown = Formulas.getCooldown(profile.Levels),
		ToolName = tool.Name,
		Upgrades = upgrades,
	}
end

-- Call after any mutation so the HUD and leaderboard stay in sync.
function DataService.changed(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then
		cash.Value = profile.Cash
	end
	Remotes.event("StateChanged"):FireClient(player, DataService.buildState(player))
end

local function save(player: Player)
	local profile = profiles[player]
	if not store or not profile or not loaded[player] then
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

local loadedCallbacks: { (Player, Profile) -> () } = {}

function DataService.onLoaded(callback: (Player, Profile) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile)
	end
end

local function onPlayerAdded(player: Player)
	local saved = nil
	local canSave = store ~= nil
	if store then
		local ok, result = retry(3, function()
			return (store :: DataStore):GetAsync(keyFor(player))
		end)
		if ok then
			saved = result
		else
			-- Never overwrite a save we failed to read.
			canSave = false
			warn(`[DataService] Failed to load {player.Name}, session will not save:`, result)
		end
	end
	if player.Parent ~= Players then
		return
	end

	local profile = sanitize(saved)
	profiles[player] = profile
	loaded[player] = canSave

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = profile.Cash
	cash.Parent = leaderstats
	leaderstats.Parent = player

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
		save(player)
		profiles[player] = nil
		loaded[player] = nil
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
