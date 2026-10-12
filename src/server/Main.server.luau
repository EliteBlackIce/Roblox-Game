--!strict
-- Server entry point: build the world (if it isn't baked into the place), then
-- start every service. Services register their hooks before profiles load.

local Players = game:GetService("Players")

local Services = script.Parent.Services
local MapBuilder = require(script.Parent.World.MapBuilder)
local DataService = require(Services.DataService)

-- Characters spawn only after data loads, so the tool and stats are ready.
Players.CharacterAutoLoads = false

MapBuilder.build()

for _, name in {
	"RequestRouter",
	"ToolService",
	"CharacterService",
	"ScrapService",
	"EconomyService",
	"BotService",
	"RebirthService",
	"QuestService",
	"EventService",
	"CodeService",
	"LeaderboardService",
	"MonetizationService",
} do
	require(Services:FindFirstChild(name) :: ModuleScript).start()
end
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

DataService.onLoaded(spawnPlayer)
