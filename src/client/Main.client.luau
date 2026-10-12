--!strict
-- Client entry point: builds the UI, mirrors server state and plays effects.
-- The client never decides anything about money or items; it only renders state
-- and sends requests that the server validates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BotFollowers = require(script.Parent.BotFollowers)
local Effects = require(script.Parent.Effects)
local Gates = require(script.Parent.Gates)
local State = require(script.Parent.State)
local Hatch = require(script.Parent.UI.Hatch)
local Hud = require(script.Parent.UI.Hud)
local Menu = require(script.Parent.UI.Menu)
local Notifications = require(script.Parent.UI.Notifications)
local Windows = require(script.Parent.UI.Windows)
local AmbientLife = require(script.Parent.AmbientLife)
local Outliner = require(script.Parent.Outliner)
local WorldAnimator = require(script.Parent.WorldAnimator)
local Screens = script.Parent.UI.Screens

local player = Players.LocalPlayer

local screen = Instance.new("ScreenGui")
screen.Name = "JunkyardUI"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = player:WaitForChild("PlayerGui")

Notifications.init(screen)
Windows.init(screen)
Hud.init(screen, function()
	State.request("Sell")
end)
Hatch.init(screen)

for _, name in { "Upgrades", "Tools", "Bots", "Quests", "Index", "Rebirth", "Boosts", "Teleport", "Codes", "Settings" } do
	(require(Screens:FindFirstChild(name) :: ModuleScript) :: () -> ())()
end
local Store = require(Screens.Store)
if Store.hasItems() then
	Store.init()
end
Menu.init(screen, Store.hasItems())
Gates.init()
BotFollowers.init()
local function focus(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end
WorldAnimator.init(focus)
Outliner.init(focus)
AmbientLife.init(focus)

-- Collect prompts hold for as long as the player's cooldown, so the speed
-- upgrades are felt directly. The server enforces the real cooldown.
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

local greeted = false
State.listen(function(state)
	Hud.update(state)
	Effects.muted = state.Settings.Sfx == false
	Effects.lowFx = state.Settings.LowFx == true
	AmbientLife.setEnabled(not Effects.lowFx)
	if state.Cooldown ~= holdDuration then
		holdDuration = state.Cooldown
		applyHoldToAll()
	end
	-- Show the login reward the first time we see it's claimable.
	if not greeted then
		greeted = true
		if state.Login and state.Login.CanClaim then
			task.delay(1.5, function()
				Windows.open("Quests")
			end)
		end
	end
end)

Remotes.event("StateChanged").OnClientEvent:Connect(State.set)
Remotes.event("Notify").OnClientEvent:Connect(function(message: string, kind: string?)
	Notifications.toast(message, kind)
	if kind == "error" then
		Effects.playSound(Config.Sounds.Error)
	elseif kind == "success" then
		Effects.playSound(Config.Sounds.Purchase)
	end
end)
Remotes.event("Collected").OnClientEvent:Connect(function(items: { string }, position: Vector3, info: any)
	Effects.collected(items, position, info)
end)
Remotes.event("Sold").OnClientEvent:Connect(function(total: number, count: number, breakdown, multiplier: number)
	Notifications.sale(total, count, breakdown, multiplier)
	Effects.playSound(Config.Sounds.Sell)
end)
Remotes.event("OpenPanel").OnClientEvent:Connect(function(panel: string)
	Windows.open(panel)
	Effects.playSound(Config.Sounds.Click)
end)
Remotes.event("Hatched").OnClientEvent:Connect(function(crateId: string, results)
	Hatch.play(crateId, results)
end)
Remotes.event("Announce").OnClientEvent:Connect(function(text: string, kind: string?)
	Notifications.announce(text, kind)
end)

-- The profile may still be loading; StateChanged arrives once it is.
task.spawn(function()
	local ok, state = pcall(function()
		return Remotes.func("GetState"):InvokeServer()
	end)
	if ok and state and not State.current then
		State.set(state)
	end
end)
applyHoldToAll()
