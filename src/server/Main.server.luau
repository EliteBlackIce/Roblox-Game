--!strict
-- Server entry point: build the world, then start every service in dependency order.

local Players = game:GetService("Players")

local MapBuilder = require(script.Parent.World.MapBuilder)
local DataService = require(script.Parent.Services.DataService)
local ToolService = require(script.Parent.Services.ToolService)
local ScrapService = require(script.Parent.Services.ScrapService)
local EconomyService = require(script.Parent.Services.EconomyService)

-- Characters spawn only after the map exists, so nobody falls through the void.
Players.CharacterAutoLoads = false

MapBuilder.build()

ToolService.start() -- registers its onLoaded hook before any profile loads
ScrapService.start()
EconomyService.start()
DataService.start()

local function spawnPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			task.wait(Players.RespawnTime)
			if player.Parent == Players then
				player:LoadCharacter()
			end
		end)
	end)
	player:LoadCharacter()
end

DataService.onLoaded(function(player)
	spawnPlayer(player)
end)
