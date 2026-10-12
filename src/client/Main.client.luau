--!strict
-- Client entry point: builds the UI, listens for server updates and plays effects.
-- The client never decides anything about money or items; it only renders state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Effects = require(script.Parent.Effects)
local Hud = require(script.Parent.UI.Hud)
local Notifications = require(script.Parent.UI.Notifications)
local Shop = require(script.Parent.UI.Shop)

local player = Players.LocalPlayer

local screen = Instance.new("ScreenGui")
screen.Name = "JunkyardUI"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = player:WaitForChild("PlayerGui")

local hud = Hud.new(screen)
Notifications.init(screen)
Shop.init(screen)

-- Collect prompts hold for as long as the player's cooldown, so the Collection
-- Speed upgrade is felt directly. The server enforces the real cooldown.
local holdDuration = Config.Gameplay.BaseCooldown

local function applyHold(prompt: Instance)
	if prompt:IsA("ProximityPrompt") and prompt.Name == "CollectPrompt" then
		prompt.HoldDuration = holdDuration
	end
end

local function applyHoldToAll()
	for _, descendant in Workspace:GetDescendants() do
		applyHold(descendant)
	end
end
Workspace.DescendantAdded:Connect(applyHold)

local lastState: any = nil

local function onState(state: any)
	if not state then
		return
	end
	lastState = state
	hud:update(state)
	Shop.setState(state)
	if state.Cooldown ~= holdDuration then
		holdDuration = state.Cooldown
		applyHoldToAll()
	end
end

Remotes.event("StateChanged").OnClientEvent:Connect(onState)
Remotes.event("Notify").OnClientEvent:Connect(function(message: string, kind: string?)
	Notifications.toast(message, kind)
	if kind == "error" then
		Effects.playSound(Config.Sounds.Error)
	end
end)
Remotes.event("Collected").OnClientEvent:Connect(function(items: { string }, position: Vector3)
	Effects.collected(items, position, Config.Sounds.Collect)
end)
Remotes.event("Sold").OnClientEvent:Connect(function(total: number, count: number, breakdown)
	Notifications.sale(total, count, breakdown)
	Effects.playSound(Config.Sounds.Sell)
end)
Remotes.event("OpenShop").OnClientEvent:Connect(function()
	Shop.open()
end)

-- The profile may still be loading; StateChanged will arrive once it is.
task.spawn(function()
	local ok, state = pcall(function()
		return Remotes.func("GetState"):InvokeServer()
	end)
	if ok and state and not lastState then
		onState(state)
	end
end)
applyHoldToAll()
