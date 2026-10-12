--!strict
-- Client-side mirror of the server's state snapshot, plus a helper for sending
-- requests. Nothing here is trusted by the server; it only drives the UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Effects = require(script.Parent.Effects)
local Notifications = require(script.Parent.UI.Notifications)

local State = {}

State.current = nil :: any
-- Server os.time() minus client os.time(), so timers match the server.
State.timeOffset = 0

local listeners: { (any) -> () } = {}

function State.listen(fn: (any) -> ())
	table.insert(listeners, fn)
	if State.current then
		task.spawn(fn, State.current)
	end
end

function State.set(state: any)
	if not state then
		return
	end
	State.current = state
	State.timeOffset = state.ServerTime - os.time()
	for _, fn in listeners do
		task.spawn(fn, state)
	end
end

function State.now(): number
	return os.time() + State.timeOffset
end

-- Sends a request and shows the server's message. Returns (ok, data).
local pending: { [string]: boolean } = {}
function State.request(action: string, ...: any): (boolean, any)
	if pending[action] then
		return false, nil
	end
	pending[action] = true
	local ok, success, message, data = pcall(function(...)
		return Remotes.func("Request"):InvokeServer(action, ...)
	end, ...)
	pending[action] = nil
	if not ok then
		Notifications.toast("Request failed, try again.", "error")
		Effects.playSound(Config.Sounds.Error)
		return false, nil
	end
	if message then
		Notifications.toast(message, if success then "success" else "error")
	end
	if success then
		Effects.playSound(Config.Sounds.Purchase)
	elseif message then
		Effects.playSound(Config.Sounds.Error)
	end
	return success == true, data
end

return State
