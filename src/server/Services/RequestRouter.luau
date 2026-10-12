--!strict
-- Single entry point for every client UI action. The client calls
-- Request:InvokeServer(action, ...). Unknown actions are rejected, each action is
-- rate limited per player, and handler errors never leak to the client.
--
-- Handlers return (success: boolean, message: string?, data: any?).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local RequestRouter = {}

type Handler = (Player, ...any) -> (boolean, string?, any?)

local handlers: { [string]: Handler } = {}
local lastCall: { [Player]: { [string]: number } } = {}

function RequestRouter.register(action: string, handler: Handler)
	assert(handlers[action] == nil, "duplicate request handler " .. action)
	handlers[action] = handler
end

local function route(player: Player, action: unknown, ...: any): (boolean, string?, any?)
	if type(action) ~= "string" then
		return false, "Invalid request."
	end
	local handler = handlers[action]
	if not handler then
		return false, "Invalid request."
	end
	if not DataService.get(player) then
		return false, "Still loading your data..."
	end

	local now = os.clock()
	local calls = lastCall[player]
	if not calls then
		calls = {}
		lastCall[player] = calls
	end
	if calls[action] and now - calls[action] < Config.Gameplay.RequestThrottle then
		return false, "Slow down!"
	end
	calls[action] = now

	local ok, success, message, data = pcall(handler, player, ...)
	if not ok then
		warn(`[RequestRouter] {action} failed for {player.Name}:`, success)
		return false, "Something went wrong."
	end
	return success == true, message, data
end

function RequestRouter.start()
	Remotes.func("Request").OnServerInvoke = route
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
	end)
end

-- Exposed for tests.
RequestRouter.route = route

return RequestRouter
