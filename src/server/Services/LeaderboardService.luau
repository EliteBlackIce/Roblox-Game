--!strict
-- Global "Top Earners" board using an OrderedDataStore. Falls back to the
-- players in this server when DataStores are unavailable (e.g. Studio).

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local REFRESH = 90
local TOP = 10
local nameCache: { [number]: string } = {}

local ordered: OrderedDataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore("TopEarners_v1")
	end)
	if ok then
		ordered = result
	end
end

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and type(name) == "string" then name else "Player"
	nameCache[userId] = result
	return result
end

local function localEntries(): { { Name: string, Value: number } }
	local entries = {}
	for player, profile in DataService.all() do
		table.insert(entries, { Name = player.Name, Value = profile.TotalEarned })
	end
	table.sort(entries, function(a, b)
		return a.Value > b.Value
	end)
	return entries
end

local function fetch(): ({ { Name: string, Value: number } }, boolean)
	if not ordered then
		return localEntries(), false
	end
	for player, profile in DataService.all() do
		pcall(function()
			(ordered :: OrderedDataStore):SetAsync("player_" .. player.UserId, math.floor(profile.TotalEarned))
		end)
	end
	local ok, pages = pcall(function()
		return (ordered :: OrderedDataStore):GetSortedAsync(false, TOP)
	end)
	if not ok then
		return localEntries(), false
	end
	local entries = {}
	for _, entry in (pages :: any):GetCurrentPage() do
		local userId = tonumber(string.match(entry.key, "%d+")) or 0
		table.insert(entries, { Name = nameFor(userId), Value = entry.value })
	end
	return entries, true
end

local function render(entries: { { Name: string, Value: number } }, global: boolean)
	for _, board in CollectionService:GetTagged("Leaderboard") do
		local list = board:FindFirstChild("List", true)
		local title = board:FindFirstChild("Title", true)
		if title and title:IsA("TextLabel") then
			title.Text = if global then "TOP EARNERS (GLOBAL)" else "TOP EARNERS (SERVER)"
		end
		if list and list:IsA("TextLabel") then
			local lines = {}
			for rank = 1, TOP do
				local entry = entries[rank]
				if entry then
					table.insert(lines, `{rank}. {entry.Name}  -  {Formulas.formatCash(entry.Value)}`)
				end
			end
			list.Text = if #lines > 0 then table.concat(lines, "\n") else "No one yet. Be the first!"
		end
	end
end

function LeaderboardService.refresh()
	render(fetch())
end

function LeaderboardService.start()
	task.spawn(function()
		while true do
			LeaderboardService.refresh()
			task.wait(REFRESH)
		end
	end)
end

return LeaderboardService
