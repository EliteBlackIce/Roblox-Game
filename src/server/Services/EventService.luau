--!strict
-- Server-wide live events: Golden Piles and Scrap Frenzy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Zones = require(Shared.Zones)
local DataService = require(script.Parent.DataService)
local ScrapService = require(script.Parent.ScrapService)

local EventService = {}

local rng = Random.new()

local function refreshAll()
	for player in DataService.all() do
		DataService.changed(player)
	end
end

-- Picks a pile in a zone that someone in the server can actually reach.
local function pickPile(): Model?
	local players = {}
	for player in DataService.all() do
		table.insert(players, player)
	end
	if #players == 0 then
		return nil
	end
	local profile = DataService.get(players[rng:NextInteger(1, #players)])
	if not profile then
		return nil
	end
	local unlocked = {}
	for zoneId in profile.Zones do
		table.insert(unlocked, zoneId)
	end
	local zoneId = unlocked[rng:NextInteger(1, #unlocked)]
	local candidates = {}
	for _, pile in ScrapService.getPiles() do
		if pile:GetAttribute("ZoneId") == zoneId and not pile:GetAttribute("Golden") then
			table.insert(candidates, pile)
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

function EventService.spawnGoldenPile(): Model?
	local pile = pickPile()
	if not pile then
		return nil
	end
	ScrapService.makeGolden(pile, Config.Events.GoldenPileDuration)
	local zone = Zones.ById[pile:GetAttribute("ZoneId")]
	Remotes.event("Announce"):FireAllClients(`A GOLDEN PILE appeared in {zone.Name}!`, "Golden")
	return pile
end

function EventService.startFrenzy()
	DataService.frenzyUntil = os.time() + Config.Events.FrenzyDuration
	Workspace:SetAttribute("FrenzyUntil", DataService.frenzyUntil)
	Remotes.event("Announce"):FireAllClients("SCRAP FRENZY! x2 cash and faster grabs!", "Frenzy")
	refreshAll()
	task.delay(Config.Events.FrenzyDuration + 1, refreshAll)
end

function EventService.start()
	task.spawn(function()
		while true do
			local range = Config.Events.GoldenPileInterval
			task.wait(rng:NextNumber(range[1], range[2]))
			if #Players:GetPlayers() > 0 then
				EventService.spawnGoldenPile()
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Events.FrenzyInterval)
			if #Players:GetPlayers() > 0 then
				EventService.startFrenzy()
			end
		end
	end)
end

return EventService
